extends SceneTree

## 화면에 보이는 정보만으로 이 게임이 실제로 풀리는지 감사한다.
##   godot --headless --script res://tools/solver_audit.gd
##
## `tests/test_fairness.gd`는 필드가 **관찰 가능한지**를 본다. 이 도구는 그 정보로
## **추론이 성립하는지**를 본다. 둘은 다른 질문이다.
##
## 여기서 검증할 수 없는 것: H1(재미인가) · H2(압박인가). 그건 사람이 필요하다.

const SEPARATOR := "─────────────────────────────"

var _rules: Array[Rule] = []
var _customers: Array[Customer] = []
var _engine: RuleEngine = null
var _contexts: Array[JudgeContext] = []
var _strings: Dictionary = {}
var _plan: NightPlan = null
var _night: int = 1
## 어느 밤에서든 만점을 낸 고정 독법. 하나라도 있으면 그 밤은 그 독법으로 우회된다.
var _perfect: PackedStringArray = []
var _sample_times: PackedInt32Array = []
## 몸이 사람의 몸이 아니라고 말하는 특성 (data/observation.json).
var _anomaly_spec: Dictionary = {}


func _initialize() -> void:
	_rules = GameData.load_rules()
	_engine = RuleEngine.new(_rules)
	_strings = GameData.load_strings()
	_plan = NightPlan.load()
	_sample_times = RuleEngine.sample_times(_rules)
	_anomaly_spec = GameData.read_json("res://data/observation.json").get("anomaly_traits", {})
	print("시각 표본: %s (수칙의 시간 문턱에서 유도)" % str(_sample_times))
	for night in _plan.nights():
		_audit_night(night)
	quit(_report_perfect())


## **어떤 고정 독법도 한 밤을 통째로 맞히면 안 된다.**
##
## 불변식 2f가 「몸만 보는 독법」에 대해 이걸 검사하는데, 다른 독법에는 감시가 없었다.
## 실제로 뚫려 있었다 — 「나중 수칙이 앞을 덮는다」는 오독이 밤 3에서 9/9였다.
## 그 독법은 밤 2에서 처벌받는 함정인데 밤 3에서는 상을 받고 있었다.
## 참 수칙이 목록 끝에 몰려 있으면 마지막 일치만 따라도 맞기 때문이고, 그건 설계가 아니라
## 수칙을 추가한 순서의 부작용이다.
func _report_perfect() -> int:
	print("\n%s\n고정 독법 만점 검사\n%s" % [SEPARATOR, SEPARATOR])
	if _perfect.is_empty():
		print("  없음 — 어느 밤도 한 가지 독법으로 통과되지 않는다")
		return 0
	for line in _perfect:
		print("  ✗ %s" % line)
	return 1


## 밤마다 따로 감사한다. 수칙과 손님이 밤마다 다르므로 한 번에 보면 의미가 없다.
func _audit_night(night: int) -> void:
	_night = night
	_customers = _plan.customers_for(night)
	_contexts = []
	_build_contexts()
	print("\n\n╔═══ %d일째 밤 (수칙 %d개 · 손님 %d명) ═══"
		% [night, _engine.visible_rules(night).size(), _customers.size()])
	_report_conflicts()
	_report_lie_detectability()
	_report_hand_correlation()
	_report_solver("클립보드를 전부 믿는 플레이어", _naive_verdict)
	_report_solver("모순된 수칙을 전부 버리는 플레이어", _skeptical_verdict)
	_report_solver("나중 수칙이 앞 수칙을 덮는다고 보는 플레이어", _override_verdict)
	_report_solver("이유를 대는 줄은 거짓이라고 보는 플레이어", _voice_verdict)
	_report_solver("클립보드를 안 읽고 손님만 보는 플레이어", _body_verdict)
	_report_exhaustive()


func _build_contexts() -> void:
	for customer in _customers:
		for minutes in _sample_times:
			_contexts.append(JudgeContext.new(_night, minutes, customer))


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


## 이 밤에 클립보드에 붙어 있는 수칙 전부 (밤 전체 관점). 보고서용이다.
func _visible() -> Array[Rule]:
	return _engine.visible_rules(_night)


## **솔버가 실제로 읽을 수 있는 것.** 근무 중에 붙는 줄은 그 전에는 안 보인다 (밤 5).
## 여기서 밤 전체 목록을 쓰면 솔버가 아직 없는 줄을 따르게 되고, 감사 결과가
## 실제 플레이보다 나쁘게 나온다 — 없는 함정에 걸린 것으로 세게 된다.
func _readable(ctx: JudgeContext) -> Array[Rule]:
	return _engine.visible_rules(_night, ctx.shift_minutes)


## 두 수칙이 같은 상황에서 서로 다른 판정을 요구하는가.
func _conflicts(a: Rule, b: Rule) -> bool:
	for ctx in _contexts:
		if a.matches(ctx) and b.matches(ctx) and not a.verdict().equals(b.verdict()):
			return true
	return false


func _conflicting_partners(target: Rule) -> Array[Rule]:
	var out: Array[Rule] = []
	for other in _visible():
		if other.id != target.id and _conflicts(target, other):
			out.append(other)
	return out


func _report_conflicts() -> void:
	print("\n%s\n수칙 간 모순 (클립보드만 보고 알아낼 수 있는 것)\n%s" % [SEPARATOR, SEPARATOR])
	var found := false
	var visible := _visible()
	for i in visible.size():
		for j in range(i + 1, visible.size()):
			if _conflicts(visible[i], visible[j]):
				found = true
				print("  %s  ↔  %s" % [visible[i].id, visible[j].id])
	if not found:
		print("  없음")


## 실패하기 **전에** 거짓임을 알아낼 수 있는가. 이게 공정성 불변식 2의 실질이다.
func _report_lie_detectability() -> void:
	print("\n%s\n거짓 수칙의 사전 탐지 가능성\n%s" % [SEPARATOR, SEPARATOR])
	for rule in _visible():
		if not rule.is_lie_at(_night):
			continue
		var partners := _conflicting_partners(rule)
		var hand := rule.hand_at(_night)
		var foreign := hand != Rule.HAND_MANAGER
		if partners.is_empty():
			var weak := PackedStringArray()
			if rule.has_decayed_by(_night):
				weak.append("이 밤에 전환됐다 — 종이·잉크가 바뀌고 ✎ 표식이 붙는다")
			elif foreign:
				weak.append("필체가 다르다(%s)" % hand)
			if rule.gives_reason:
				weak.append("이유를 댄다")
			var body := _body_evidence(rule)
			if body != "":
				weak.append(body)
			if weak.is_empty():
				print("  ✗ %s — 모순도 없고 필체도 점장이다. **실패하기 전에 알아낼 방법이 없다**"
					% rule.id)
			else:
				# 모순이 없으면 어느 채널도 단독으로 결정적이지 않다 (불변식 2c·2e·2f).
				# 겹쳐야 잡히는 줄이고, 겹칠 것이 몇 개인지가 그 줄의 난이도다.
				print("  △ %s — 모순 없음. 약한 단서 %d개를 겹쳐야 잡힌다: %s"
					% [rule.id, weak.size(), " · ".join(weak)])
		else:
			var ids := PackedStringArray()
			for p in partners:
				ids.append(p.id)
			var hand_note := " · 필체도 다르다(%s)" % hand if foreign else ""
			print("  ✓ %s — %s 와(과) 모순 → 클립보드만 보고 이상을 감지할 수 있다%s"
				% [rule.id, ", ".join(ids), hand_note])


## 손님의 몸이 이 수칙과 어긋나는가. 어긋나면 그 자체가 단서다.
##
## 「돌려보내라」인데 걸리는 사람이 전부 멀쩡하거나, 「응대하라」인데 걸리는 사람 중에
## 몸이 이상한 자가 있으면 그 줄은 세계관과 싸우고 있는 것이다.
func _body_evidence(rule: Rule) -> String:
	var ordinary := 0
	var strange := 0
	for ctx in _contexts:
		if not rule.matches(ctx):
			continue
		if ctx.customer.looks_anomalous(_anomaly_spec):
			strange += 1
		else:
			ordinary += 1
	if rule.verdict().id() == Verdict.REFUSE and strange == 0 and ordinary > 0:
		return "몸에 아무 이상이 없는 사람만 걸린다"
	if rule.verdict().id() == Verdict.SERVE and strange > 0:
		return "몸이 이상한 사람도 응대하라고 한다"
	return ""


## 필체만 보고 진위를 맞출 수 있는가. 맞출 수 있으면 퍼즐이 죽은 것이다.
func _report_hand_correlation() -> void:
	print("\n%s\n필체와 진위의 상관\n%s" % [SEPARATOR, SEPARATOR])
	var foreign_true := 0
	var foreign_false := 0
	var own_true := 0
	var own_false := 0
	for rule in _visible():
		var lying := rule.is_lie_at(_night)
		if rule.hand_at(_night) != Rule.HAND_MANAGER:
			if lying: foreign_false += 1
			else: foreign_true += 1
		else:
			if lying: own_false += 1
			else: own_true += 1
	print("  점장 필체 — 참 %d / 거짓 %d" % [own_true, own_false])
	print("  남의 필체 — 참 %d / 거짓 %d" % [foreign_true, foreign_false])
	if foreign_false > 0 and foreign_true == 0:
		print("  ✗ 남의 필체가 전부 거짓이다. 종이 색만 보면 다 풀린다")
	else:
		print("  ✓ 필체만으로는 진위를 결정할 수 없다 — 용의자를 좁힐 뿐이다")


## 클립보드를 전부 참으로 믿고, 모순이 나면 위에 적힌 수칙을 따른다.
func _naive_verdict(ctx: JudgeContext) -> Verdict:
	for rule in _readable(ctx):
		if rule.matches(ctx):
			return rule.verdict()
	return Verdict.serve()


## 모순에 연루된 수칙은 믿을 수 없다고 보고 전부 버린다.
func _skeptical_verdict(ctx: JudgeContext) -> Verdict:
	for rule in _readable(ctx):
		if not rule.matches(ctx):
			continue
		if _conflicting_partners(rule).is_empty():
			return rule.verdict()
	return Verdict.serve()


## 가장 자연스러운 오독. "단골에게는 다른 수칙을 적용하지 마시오" 같은 예외 조항은
## 법조문처럼 **뒤에 온 것이 앞을 덮는다**고 읽힌다. 그게 이 게임의 진짜 함정이다.
## 첫 매칭만 따르는 플레이어는 참 수칙이 앞에 나열돼 있어서 우연히 잘 맞는다 —
## 이 솔버가 그 착시를 걷어낸다.
func _override_verdict(ctx: JudgeContext) -> Verdict:
	var chosen: Verdict = Verdict.serve()
	for rule in _readable(ctx):
		if rule.matches(ctx):
			chosen = rule.verdict()
	return chosen


## **문체만 보고 푸는 플레이어.** 「이유를 대면 거짓」이라 믿고 그 줄들을 버린다.
##
## 이 솔버가 만점을 내면 게임이 정규식 한 줄로 풀린다는 뜻이다. 실제로 그런 적이 있다 —
## 문체를 veracity에서 파생시켰더니 수칙 11개를 11/11 분류하는 완전 분류기가 됐다.
## 불변식 2e가 상관을 감시하고, 이 솔버가 그 결과를 **점수로** 보여준다.
func _voice_verdict(ctx: JudgeContext) -> Verdict:
	for rule in _readable(ctx):
		if rule.gives_reason:
			continue  # 변명하는 줄은 거짓이라고 보고 버린다
		if rule.matches(ctx):
			return rule.verdict()
	return Verdict.serve()


## **클립보드를 아예 안 읽는 플레이어.** 손님의 몸만 보고, 이상이 있으면 돌려보낸다.
##
## 이 게임의 세계관을 그대로 정책으로 만든 것이다 — 사람이 아닌 것은 몸에서 드러난다.
## 넷째 수칙(가방)처럼 **모순이 없는 거짓**을 잡는 유일한 경로이므로 강할 수밖에 없다.
## 그래서 감시가 필요하다: 이 솔버가 만점을 내면 수칙을 읽을 이유가 사라진다.
## 지금 이 점수를 끌어내리는 것은 시간 수칙 둘뿐이다 — 평범한 사람을 돌려보내라는
## 참 수칙이고, 불변식 2f가 그 줄들이 사라지지 않는지 지킨다.
func _body_verdict(ctx: JudgeContext) -> Verdict:
	if ctx.customer.looks_anomalous(_anomaly_spec):
		return Verdict.refuse()
	return Verdict.serve()


func _report_solver(label: String, strategy: Callable) -> void:
	print("\n%s\n%s\n%s" % [SEPARATOR, label, SEPARATOR])
	var correct := 0
	var total := 0
	for customer in _customers:
		var ctx := JudgeContext.new(_night, _arrival_minutes(customer), customer)
		var chosen: Verdict = strategy.call(ctx)
		var result := _engine.evaluate(ctx, chosen)
		total += 1
		if result.correct:
			correct += 1
		else:
			print("  ✗ %-22s %s → 정답 %s" % [
				customer.id, chosen.id(), result.expected_ids()[0]])
	print("  %d / %d 정답" % [correct, total])
	if correct == total and total > 0:
		_perfect.append("%d일째 밤은 「%s」 하나로 %d명 전원 정답" % [_night, label, total])


## 손님이 실제로 도착하는 시각. NightSession과 같은 규칙을 쓴다.
func _arrival_minutes(customer: Customer) -> int:
	return NightSession.arrival_minutes(_customers.find(customer), _customers.size())


## 모든 손님 × 모든 판정 × 유예 켬/끔 전수. 불변식이 어디서도 깨지지 않는지 본다.
func _report_exhaustive() -> void:
	print("\n%s\n전수 탐색\n%s" % [SEPARATOR, SEPARATOR])
	var checked := 0
	var empty_clues := 0
	for ctx in _contexts:
		for kind in [Verdict.SERVE, Verdict.REFUSE]:
			var result := _engine.evaluate(ctx, Verdict.from_id(kind))
			checked += 1
			if not result.correct and result.missed_clue_keys.is_empty():
				empty_clues += 1
				print("  ✗ %s / %s — 놓친 단서가 비어 있다" % [ctx.customer.id, kind])
	print("  %d개 조합 검사, 설명 없는 실패 %d건" % [checked, empty_clues])
	print(SEPARATOR)
