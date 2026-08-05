extends SceneTree

## 화면에 보이는 정보만으로 이 게임이 실제로 풀리는지 감사한다.
##   godot --headless --script res://tools/solver_audit.gd
##
## `tests/test_fairness.gd`는 필드가 **관찰 가능한지**를 본다. 이 도구는 그 정보로
## **추론이 성립하는지**를 본다. 둘은 다른 질문이다.
##
## 여기서 검증할 수 없는 것: H1(재미인가) · H2(압박인가). 그건 사람이 필요하다.

const SEPARATOR := "─────────────────────────────"
const SAMPLE_TIMES := [0, 240, 400]

var _rules: Array[Rule] = []
var _customers: Array[Customer] = []
var _engine: RuleEngine = null
var _contexts: Array[JudgeContext] = []
var _strings: Dictionary = {}


func _initialize() -> void:
	_rules = GameData.load_rules()
	_customers = GameData.load_customers()
	_engine = RuleEngine.new(_rules)
	_strings = GameData.load_strings()
	_build_contexts()
	_report_conflicts()
	_report_lie_detectability()
	_report_hand_correlation()
	_report_solver("클립보드를 전부 믿는 플레이어", _naive_verdict)
	_report_solver("모순된 수칙을 전부 버리는 플레이어", _skeptical_verdict)
	_report_exhaustive()
	quit(0)


func _build_contexts() -> void:
	for customer in _customers:
		for minutes in SAMPLE_TIMES:
			_contexts.append(JudgeContext.new(1, minutes, customer))


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


## 두 수칙이 같은 상황에서 서로 다른 판정을 요구하는가.
func _conflicts(a: Rule, b: Rule) -> bool:
	for ctx in _contexts:
		if a.matches(ctx) and b.matches(ctx) and not a.verdict().equals(b.verdict()):
			return true
	return false


func _conflicting_partners(target: Rule) -> Array[Rule]:
	var out: Array[Rule] = []
	for other in _rules:
		if other.id != target.id and _conflicts(target, other):
			out.append(other)
	return out


func _report_conflicts() -> void:
	print("\n%s\n수칙 간 모순 (클립보드만 보고 알아낼 수 있는 것)\n%s" % [SEPARATOR, SEPARATOR])
	var found := false
	for i in _rules.size():
		for j in range(i + 1, _rules.size()):
			if _conflicts(_rules[i], _rules[j]):
				found = true
				print("  %s  ↔  %s" % [_rules[i].id, _rules[j].id])
	if not found:
		print("  없음")


## 실패하기 **전에** 거짓임을 알아낼 수 있는가. 이게 공정성 불변식 2의 실질이다.
func _report_lie_detectability() -> void:
	print("\n%s\n거짓 수칙의 사전 탐지 가능성\n%s" % [SEPARATOR, SEPARATOR])
	for rule in _rules:
		if not rule.is_lie_at(1):
			continue
		var partners := _conflicting_partners(rule)
		if partners.is_empty():
			if rule.is_foreign_hand():
				print("  ✓ %s — 모순은 없지만 필체가 다르다 (%s) → 종이와 잉크로 탐지 가능"
					% [rule.id, rule.hand])
			else:
				print("  ✗ %s — 모순도 없고 필체도 점장이다. **실패하기 전에 알아낼 방법이 없다**"
					% rule.id)
		else:
			var ids := PackedStringArray()
			for p in partners:
				ids.append(p.id)
			var hand_note := " · 필체도 다르다(%s)" % rule.hand if rule.is_foreign_hand() else ""
			print("  ✓ %s — %s 와(과) 모순 → 클립보드만 보고 이상을 감지할 수 있다%s"
				% [rule.id, ", ".join(ids), hand_note])


## 필체만 보고 진위를 맞출 수 있는가. 맞출 수 있으면 퍼즐이 죽은 것이다.
func _report_hand_correlation() -> void:
	print("\n%s\n필체와 진위의 상관\n%s" % [SEPARATOR, SEPARATOR])
	var foreign_true := 0
	var foreign_false := 0
	var own_true := 0
	var own_false := 0
	for rule in _rules:
		var lying := rule.is_lie_at(1)
		if rule.is_foreign_hand():
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
	for rule in _rules:
		if rule.is_active_at(ctx.night) and rule.matches(ctx):
			return rule.verdict()
	return Verdict.serve()


## 모순에 연루된 수칙은 믿을 수 없다고 보고 전부 버린다.
func _skeptical_verdict(ctx: JudgeContext) -> Verdict:
	for rule in _rules:
		if not rule.is_active_at(ctx.night) or not rule.matches(ctx):
			continue
		if _conflicting_partners(rule).is_empty():
			return rule.verdict()
	return Verdict.serve()


func _report_solver(label: String, strategy: Callable) -> void:
	print("\n%s\n%s\n%s" % [SEPARATOR, label, SEPARATOR])
	var correct := 0
	var total := 0
	for customer in _customers:
		var ctx := JudgeContext.new(1, _arrival_minutes(customer), customer)
		var chosen: Verdict = strategy.call(ctx)
		var result := _engine.evaluate(ctx, chosen)
		total += 1
		if result.correct:
			correct += 1
		else:
			print("  ✗ %-22s %s → 정답 %s" % [
				customer.id, chosen.id(), result.expected_ids()[0]])
	print("  %d / %d 정답" % [correct, total])


## 손님이 실제로 도착하는 시각. NightSession과 같은 규칙을 쓴다.
func _arrival_minutes(customer: Customer) -> int:
	var per := int(GameData.load_balance().get("minutes_per_customer", 80))
	return _customers.find(customer) * per


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
