extends RefCounted

## 04-functional-spec.md F-01의 **공정성 불변식 4개**를 자동 검증한다.
##
## 이 게임의 생사는 "속았다"와 "알아챌 수 있었는데 놓쳤다"의 차이에 달려 있다.
## 그 차이를 지키는 게 이 파일이다. 05-prioritization.md §4에서 **절대 자르지 않는 항목**으로 지정돼 있다.

const DETERMINISM_REPEATS := 20

var _rules: Array[Rule] = []
var _customers: Array[Customer] = []
var _engine: RuleEngine = null
var _strings: Dictionary = {}


func run(r: RefCounted) -> void:
	r.suite("fairness")
	_rules = GameData.load_rules()
	_customers = GameData.load_customers()
	_engine = RuleEngine.new(_rules)
	_strings = GameData.load_strings()
	_invariant_1_all_clues_observable(r)
	_invariant_2_lies_leave_a_tell(r)
	_invariant_3_failure_always_explains(r)
	_invariant_4_judgement_is_deterministic(r)
	_strings_are_externalized(r)


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


## 불변식 2 — 거짓 수칙은 반드시 사전에 반증 가능한 단서를 남긴다.
func _invariant_2_lies_leave_a_tell(r: RefCounted) -> void:
	for rule in _rules:
		if rule.veracity == Rule.VERACITY_TRUE:
			continue
		r.check(rule.tell_key != "",
			"불변식2: 거짓 수칙 %s에 반증 단서(tell_key)가 없다" % rule.id)


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


## F-10 — 하드코딩된 표시 문자열 0개. 모든 키가 실제로 존재하는지 본다.
func _strings_are_externalized(r: RefCounted) -> void:
	r.check(_strings.has(RuleEngine.CLUE_NO_RULE_APPLIED),
		"문자열 키 없음: %s" % RuleEngine.CLUE_NO_RULE_APPLIED)
	for rule in _rules:
		r.check(_strings.has(rule.text_key), "문자열 키 없음: %s" % rule.text_key)
		if rule.tell_key != "":
			r.check(_strings.has(rule.tell_key), "문자열 키 없음: %s" % rule.tell_key)
	for customer in _customers:
		r.check(_strings.has(customer.name_key), "문자열 키 없음: %s" % customer.name_key)
		for key in customer.item_keys:
			r.check(_strings.has(key), "문자열 키 없음: %s" % key)
		for key in customer.dialogue_keys:
			r.check(_strings.has(key), "문자열 키 없음: %s" % key)
		for name in customer.trait_names():
			r.check(_strings.has("trait." + name), "문자열 키 없음: trait.%s" % name)
