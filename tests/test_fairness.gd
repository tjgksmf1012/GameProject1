extends RefCounted

## 04-functional-spec.md F-01의 **공정성 불변식**을 자동 검증한다.
##
## 현지화 검사는 `test_strings.gd`로 뗐다 — 공정성이 아니고, 한 파일이 300줄에 닿았다.
##
## 이 게임의 생사는 "속았다"와 "알아챌 수 있었는데 놓쳤다"의 차이에 달려 있다.
## 그 차이를 지키는 게 이 파일이다. 05-prioritization.md §4에서 **절대 자르지 않는 항목**으로 지정돼 있다.

const CctvMonitor := preload("res://ui/cctv/cctv_monitor.gd")

const DETERMINISM_REPEATS := 20

var _rules: Array[Rule] = []
var _customers: Array[Customer] = []
var _engine: RuleEngine = null


func run(r: RefCounted) -> void:
	r.suite("fairness")
	_rules = GameData.load_rules()
	_customers = GameData.load_customers()
	_engine = RuleEngine.new(_rules)
	_invariant_1_all_clues_observable(r)
	_invariant_1b_every_trait_is_drawn_somewhere(r)
	_invariant_1c_late_rules_do_not_judge_the_past(r)
	_invariant_2_lies_leave_a_tell(r)
	_invariant_2b_a_lie_is_detectable_before_failing(r)
	_invariant_2c_hand_must_not_solve_it(r)
	_invariant_2d_manager_hand_must_not_be_free(r)
	_invariant_3_failure_always_explains(r)
	_invariant_4_judgement_is_deterministic(r)


## 불변식 1 — 판정에 필요한 모든 단서는 판정 시점에 화면에 존재한다. 숨겨진 스탯 금지.
func _invariant_1_all_clues_observable(r: RefCounted) -> void:
	for customer in _customers:
		var ctx := JudgeContext.new(1, 0, customer)
		var observable := ctx.observable_field_names()
		for rule in _rules:
			for field in rule.referenced_fields():
				r.check(observable.has(field),
					"불변식1: 수칙 %s가 참조하는 '%s'를 손님 %s에게서 관찰할 수 없다"
						% [rule.id, field, customer.id])


## 불변식 1을 화면까지 밀어붙인 것 — **모든 특성은 어느 한 화면에는 반드시 그려진다.**
##
## 데이터가 관찰 가능하다고 말하는 것과, 화면이 실제로 그리는 것은 다른 이야기다.
## `observation.json`이 CCTV로 넘긴 특성을 CCTV가 그리지 못하면 그 단서는 어디에도 없다.
## 손님 패널은 CCTV 담당분을 빼고 그리므로, 양쪽 다 놓치면 단서가 조용히 사라진다.
func _invariant_1b_every_trait_is_drawn_somewhere(r: RefCounted) -> void:
	var observation := GameData.read_json("res://data/observation.json")
	var on_cctv := Customer._to_string_array(observation.get("cctv_traits", []))
	for name in on_cctv:
		r.check(CctvMonitor.RENDERABLE_TRAITS.has(name),
			"불변식1b: '%s'를 CCTV로 넘겼는데 CCTV가 그리지 못한다 — 단서가 화면에서 사라진다"
				% name)
	# 손님이 가진 모든 특성이 두 화면 중 하나에는 실제로 그려지는가.
	# 손님 패널은 CCTV 담당분을 빼고 그리고, CCTV는 자기가 그릴 수 있는 것만 그린다.
	# 둘 사이로 빠지는 특성이 생기면 그 단서는 화면 어디에도 없다.
	for customer in _customers:
		for name in customer.trait_names():
			var drawn_on_counter := not on_cctv.has(name)
			var drawn_on_monitor := on_cctv.has(name) and CctvMonitor.RENDERABLE_TRAITS.has(name)
			r.check(drawn_on_counter or drawn_on_monitor,
				"불변식1b: 손님 %s의 '%s'가 카운터에도 CCTV에도 그려지지 않는다"
					% [customer.id, name])


## 불변식 1c — **근무 중에 붙은 수칙은 붙기 전의 손님을 판정하지 않는다** (밤 5).
##
## 불변식 1의 시간축 버전이다. 02:00에 붙은 줄로 23:00의 손님을 판정하면,
## 판정 시점에 화면에 없던 것으로 죽이는 셈이다. 그건 퍼즐이 아니라 사기다.
##
## 클립보드에 보이는 것과 평가에 들어가는 것이 **같아야** 한다는 검사이기도 하다.
## 둘이 어긋나면 플레이어는 자기가 못 본 줄 때문에 죽는다.
func _invariant_1c_late_rules_do_not_judge_the_past(r: RefCounted) -> void:
	var plan := NightPlan.load()
	var checked := 0
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var minutes := NightSession.arrival_minutes(i, customers.size())
			var ctx := JudgeContext.new(night, minutes, customers[i])
			var on_clipboard := _engine.visible_rules(night, minutes)
			for rule in _engine.applicable_rules(ctx):
				r.check(on_clipboard.has(rule),
					"불변식1c: %d일째 밤 %s를 판정하는 데 클립보드에 없는 수칙 %s가 쓰였다"
						% [night, customers[i].id, rule.id])
			for rule in _rules:
				if not rule.arrives_mid_shift() or minutes >= rule.arrives_at_minute:
					continue
				checked += 1
				r.check(not _engine.applicable_rules(ctx).has(rule),
					"불변식1c: %s는 %s에 아직 붙지도 않았는데 %s 판정에 끼어들었다"
						% [rule.id, ShiftClock.to_display(rule.arrives_at_minute), customers[i].id])
	r.check(checked > 0,
		"불변식1c: 근무 중에 붙는 수칙이 하나도 없다 — 이 검사가 아무것도 검사하지 않았다")


## 불변식 2 — 거짓 수칙은 반드시 사전에 반증 가능한 단서를 남긴다.
func _invariant_2_lies_leave_a_tell(r: RefCounted) -> void:
	for rule in _rules:
		if rule.veracity == Rule.VERACITY_TRUE:
			continue
		r.check(rule.tell_key != "",
			"불변식2: 거짓 수칙 %s에 반증 단서(tell_key)가 없다" % rule.id)


## 불변식 2를 강화한 것 — **모든 거짓 수칙은 실패하기 전에 알아낼 수 있어야 한다.**
##
## `tell_key` 문자열이 존재한다는 것과 실패 전에 알아낼 수 있다는 것은 다른 이야기다.
## 사전 탐지 경로는 두 개뿐이다:
##   (a) 다른 수칙과의 논리적 모순 — 클립보드만 보고 감지된다
##   (b) 남의 필체 — 종이 색조와 잉크가 다르다 (F-05, paper.gdshader)
## 둘 다 없는 거짓 수칙은 "속았다"가 되고, 그 순간 이 게임은 불공정해진다.
## **밤마다 따로 본다.** 전환형 수칙은 밤 1에는 참이고 밤 3부터 거짓이다.
## 밤 1만 검사하면 전환된 거짓이 통째로 검사망을 빠져나간다.
func _invariant_2b_a_lie_is_detectable_before_failing(r: RefCounted) -> void:
	var by_contradiction := 0
	for night in NightPlan.load().nights():
		for lie in _rules:
			if not lie.is_active_at(night) or not lie.is_lie_at(night):
				continue
			var conflicts := _conflicting_rule_ids(lie)
			if conflicts.size() > 0:
				by_contradiction += 1
			# 전환된 수칙은 그 밤부터 남의 필체로 읽힌다 (Rule.hand_at).
			r.check(conflicts.size() > 0 or lie.hand_at(night) != Rule.HAND_MANAGER,
				"불변식2b: %d일째 밤의 거짓 수칙 %s는 실패하기 전에 알아낼 방법이 없다"
					% [night, lie.id])
	# 모순이 하나도 없으면 시각 단서에만 의존하게 된다. 그건 너무 얇다.
	r.check(by_contradiction > 0,
		"불변식2b: 모순으로 감지되는 거짓 수칙이 하나는 있어야 한다 — 시각 단서 하나에만 걸면 위험하다")


## 불변식 2c — **필체가 진위를 1:1로 결정하면 안 된다.**
##
## 남의 필체가 곧 거짓이면, 플레이어는 한 번 학습한 뒤 종이 색만 보고 전부 푼다.
## 코어 훅이 추론에서 색깔 맞추기로 전락한다 (F-05가 경고한 "너무 명확하면 퍼즐이 죽는다").
##
## 역할 분담을 강제한다: 필체는 **용의자를 좁히고**, 진위는 다른 단서가 정한다.
## 밤마다 본다. 어떤 밤에서든 "남의 필체 = 거짓"이 성립하면 그 밤은 색깔 맞추기가 된다.
func _invariant_2c_hand_must_not_solve_it(r: RefCounted) -> void:
	for night in NightPlan.load().nights():
		var foreign_truths := 0
		var foreign_lies := 0
		for rule in _rules:
			if not rule.is_active_at(night) or rule.hand_at(night) == Rule.HAND_MANAGER:
				continue
			if rule.is_lie_at(night):
				foreign_lies += 1
			else:
				foreign_truths += 1
		if foreign_lies == 0:
			continue  # 남의 필체로 쓴 거짓이 없으면 이 위험 자체가 없다
		r.check(foreign_truths > 0,
			"불변식2c: %d일째 밤은 남의 필체가 전부 거짓이다 — 종이 색만 보면 다 풀린다" % night)


## 2c의 뒷면. **점장 필체가 곧 참이면 그 줄들은 공짜가 된다.**
##
## 2c는 "남의 필체 = 거짓"만 막는다. 반대쪽이 뚫려 있으면 플레이어는
## "점장이 쓴 줄은 그냥 믿는다"는 완벽한 지름길을 얻는다. 클립보드의 절반이 퍼즐에서 빠진다.
##
## 밤 3에서 둘째 수칙이 전환돼 남의 필체로 넘어가면서 점장 필체가 1줄만 남았을 때 이게 드러났다.
## 1~2줄은 패턴으로 학습되지 않으므로 그 아래는 통과시킨다 — 임계는 이 판단이지 밸런싱 값이 아니다.
## 본편에서 이 구멍을 막는 방법은 정해져 있다: **점장 필체로 쓰인 거짓 수칙** (03-PRD.md 3.4).
const HAND_PATTERN_THRESHOLD := 3


func _invariant_2d_manager_hand_must_not_be_free(r: RefCounted) -> void:
	var widest := 0
	for night in NightPlan.load().nights():
		var truths := 0
		var lies := 0
		for rule in _rules:
			if not rule.is_active_at(night) or rule.hand_at(night) != Rule.HAND_MANAGER:
				continue
			if rule.is_lie_at(night):
				lies += 1
			else:
				truths += 1
		widest = maxi(widest, truths + lies)
		if truths + lies < HAND_PATTERN_THRESHOLD:
			continue  # 점장 필체가 1~2줄뿐이면 "전부 참"이 학습 가능한 규칙이 되지 않는다
		r.check(lies > 0,
			"불변식2d: %d일째 밤은 점장 필체 %d줄이 전부 참이다 — 그 줄들은 읽지 않고 믿어도 된다"
				% [night, truths])
	if widest < HAND_PATTERN_THRESHOLD:
		r.note("불변식2d: 점장 필체가 가장 많은 밤도 %d줄뿐이라 아직 한 번도 발동하지 않았다 (임계 %d)"
			% [widest, HAND_PATTERN_THRESHOLD])


## 같은 상황에서 서로 다른 판정을 요구하는 수칙들.
func _conflicting_rule_ids(target: Rule) -> PackedStringArray:
	var out := PackedStringArray()
	for other in _rules:
		if other.id == target.id:
			continue
		for customer in _customers:
			for minutes in [0, 240, 400]:
				var ctx := JudgeContext.new(1, minutes, customer)
				if not (target.matches(ctx) and other.matches(ctx)):
					continue
				if not target.verdict().equals(other.verdict()) and not out.has(other.id):
					out.append(other.id)
	return out


## 불변식 3 — 실패하면 무엇을 놓쳤는지 항상 보여줄 수 있어야 한다 (3초 리플레이).
## 모든 손님 × 모든 판정 조합을 전수로 돌린다.
func _invariant_3_failure_always_explains(r: RefCounted) -> void:
	var verdicts: Array[Verdict] = [Verdict.serve(), Verdict.refuse()]
	var failures_seen := 0
	for customer in _customers:
		for minutes in [0, 240, 400]:
			var ctx := JudgeContext.new(1, minutes, customer)
			for v in verdicts:
				var result := _engine.evaluate(ctx, v)
				if result.correct:
					continue
				failures_seen += 1
				r.check(result.missed_clue_keys.size() > 0,
					"불변식3: %s에게 %s 판정이 틀렸는데 놓친 단서가 비어 있다"
						% [customer.id, v.id()])
	r.check(failures_seen > 0, "불변식3: 검사할 실패 사례가 하나도 없다면 테스트가 무의미하다")


## 불변식 4 — 무작위화는 조합·순서에만. 개별 판정의 정답은 결정론적이다.
func _invariant_4_judgement_is_deterministic(r: RefCounted) -> void:
	for customer in _customers:
		var ctx := JudgeContext.new(1, 240, customer)
		var baseline := _engine.evaluate(ctx, Verdict.serve())
		for i in DETERMINISM_REPEATS:
			var again := _engine.evaluate(ctx, Verdict.serve())
			r.equals(again.correct, baseline.correct,
				"불변식4: %s 판정이 반복 실행에서 흔들린다" % customer.id)
			r.equals(again.expected_ids(), baseline.expected_ids(),
				"불변식4: %s의 기대 판정이 반복 실행에서 흔들린다" % customer.id)
