extends RefCounted

## 04-functional-spec.md F-01의 **공정성 불변식 4개**를 자동 검증한다.
##
## 이 게임의 생사는 "속았다"와 "알아챌 수 있었는데 놓쳤다"의 차이에 달려 있다.
## 그 차이를 지키는 게 이 파일이다. 05-prioritization.md §4에서 **절대 자르지 않는 항목**으로 지정돼 있다.

const CctvMonitor := preload("res://ui/cctv/cctv_monitor.gd")

const DETERMINISM_REPEATS := 20

## prototype.gd 가 `_t()`로 찾는 키 전부. 없으면 화면에 `<key>`가 그대로 뜬다.
const UI_KEYS := [
	"ui.clipboard_header", "ui.customer_header", "ui.observation_header",
	"ui.serve", "ui.refuse", "ui.next", "ui.restart",
	"ui.night", "ui.time", "ui.progress", "ui.yes", "ui.no", "ui.log_saved",
	"result.correct", "result.wrong", "result.trap", "result.trap_grace",
	"result.expected", "result.missed_header",
	"night.cleared", "night.failed", "night.summary",
	"ui.cctv_header", "cctv.counter", "cctv.aisle", "cctv.storage", "cctv.entrance",
	"ui.scan_header", "ui.receipt_header", "ui.receipt_empty", "ui.total", "ui.id_check",
]

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
	_invariant_1b_every_trait_is_drawn_somewhere(r)
	_invariant_2_lies_leave_a_tell(r)
	_invariant_2b_a_lie_is_detectable_before_failing(r)
	_invariant_2c_hand_must_not_solve_it(r)
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
func _invariant_2b_a_lie_is_detectable_before_failing(r: RefCounted) -> void:
	var by_contradiction := 0
	for lie in _rules:
		if not lie.is_lie_at(1):
			continue
		var conflicts := _conflicting_rule_ids(lie)
		if conflicts.size() > 0:
			by_contradiction += 1
		r.check(conflicts.size() > 0 or lie.is_foreign_hand(),
			"불변식2b: 거짓 수칙 %s는 실패하기 전에 알아낼 방법이 없다 (모순도 필체 차이도 없음)"
				% lie.id)
	# 모순이 하나도 없으면 시각 단서에만 의존하게 된다. 그건 너무 얇다.
	r.check(by_contradiction > 0,
		"불변식2b: 모순으로 감지되는 거짓 수칙이 하나는 있어야 한다 — 시각 단서 하나에만 걸면 위험하다")


## 불변식 2c — **필체가 진위를 1:1로 결정하면 안 된다.**
##
## 남의 필체가 곧 거짓이면, 플레이어는 한 번 학습한 뒤 종이 색만 보고 전부 푼다.
## 코어 훅이 추론에서 색깔 맞추기로 전락한다 (F-05가 경고한 "너무 명확하면 퍼즐이 죽는다").
##
## 역할 분담을 강제한다: 필체는 **용의자를 좁히고**, 진위는 다른 단서가 정한다.
func _invariant_2c_hand_must_not_solve_it(r: RefCounted) -> void:
	var foreign_truths := 0
	var foreign_lies := 0
	for rule in _rules:
		if not rule.is_foreign_hand():
			continue
		if rule.is_lie_at(1):
			foreign_lies += 1
		else:
			foreign_truths += 1
	if foreign_lies == 0:
		return  # 남의 필체로 쓴 거짓이 없으면 이 위험 자체가 없다
	r.check(foreign_truths > 0,
		"불변식2c: 남의 필체가 전부 거짓이다 — 종이 색만 보면 다 풀린다. "
			+ "참인데 나중에 덧쓴 수칙이 최소 하나는 있어야 한다")


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


## F-10 — 하드코딩된 표시 문자열 0개. 모든 키가 실제로 존재하는지 본다.
func _strings_are_externalized(r: RefCounted) -> void:
	r.check(_strings.has(RuleEngine.CLUE_NO_RULE_APPLIED),
		"문자열 키 없음: %s" % RuleEngine.CLUE_NO_RULE_APPLIED)
	for key in UI_KEYS:
		r.check(_strings.has(key), "문자열 키 없음: %s" % key)
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
