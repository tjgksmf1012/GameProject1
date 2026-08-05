extends RefCounted

## 수칙 엔진의 판정 동작. 특히 **거짓 수칙이 정답에 표를 행사하지 못하는지**를 본다.

const CUST_NORMAL := "cust_office_worker"
const CUST_BAG := "cust_student_bag"
const CUST_WET_OK := "cust_wet_normal"
const CUST_NO_SHADOW := "cust_no_shadow"
const CUST_WET_NO_SHADOW := "cust_wet_no_shadow"
const CUST_DRINKER := "cust_late_drinker"

var _engine: RuleEngine = null
var _by_id: Dictionary = {}


func run(r: RefCounted) -> void:
	r.suite("rule_engine")
	_engine = RuleEngine.new(GameData.load_rules())
	for c in GameData.load_customers():
		_by_id[c.id] = c
	_test_clock(r)
	_test_defaults(r)
	_test_true_rules(r)
	_test_lies_do_not_decide(r)
	_test_trap_detection(r)
	_test_lie_can_be_accidentally_right(r)
	_test_decaying(r)


func _ctx(customer_id: String, hhmm: String, night: int = 1) -> JudgeContext:
	return JudgeContext.new(night, ShiftClock.parse(hhmm), _by_id[customer_id])


func _verdict_of(customer_id: String, hhmm: String) -> String:
	var expected := _engine.required_verdicts(_ctx(customer_id, hhmm))
	return expected[0].id() if expected.size() == 1 else "AMBIGUOUS"


func _test_clock(r: RefCounted) -> void:
	r.equals(ShiftClock.parse("22:00"), 0, "22:00은 근무 시작")
	r.equals(ShiftClock.parse("00:00"), 120, "자정은 근무 120분째")
	r.equals(ShiftClock.parse("02:00"), 240, "02:00은 근무 240분째")
	r.equals(ShiftClock.parse("06:00"), 480, "06:00은 근무 종료")
	r.equals(ShiftClock.to_display(300), "03:00", "표시 문자열 역변환")
	r.check(ShiftClock.parse("23:00") < ShiftClock.parse("01:00"), "자정을 넘겨도 순서가 유지된다")


func _test_defaults(r: RefCounted) -> void:
	r.equals(_verdict_of(CUST_NORMAL, "23:00"), Verdict.SERVE, "평범한 손님은 그냥 응대한다")


func _test_true_rules(r: RefCounted) -> void:
	r.equals(_verdict_of(CUST_NO_SHADOW, "23:00"), Verdict.REFUSE, "그림자가 없으면 거부")
	r.equals(_verdict_of(CUST_DRINKER, "04:40"), Verdict.REFUSE, "새벽 2시 이후 주류는 거부")
	r.equals(_verdict_of(CUST_DRINKER, "23:00"), Verdict.SERVE, "2시 이전이면 주류를 팔아도 된다")


## 코어 훅. 거짓 수칙이 판매를 요구해도 정답은 거부여야 한다.
func _test_lies_do_not_decide(r: RefCounted) -> void:
	var ctx := _ctx(CUST_WET_NO_SHADOW, "23:00")
	r.equals(_verdict_of(CUST_WET_NO_SHADOW, "23:00"), Verdict.REFUSE,
		"젖었고 그림자가 없으면, 거짓 수칙이 팔라고 해도 정답은 거부")
	r.check(_engine.lies_in_play(ctx).size() > 0, "이 상황에서 거짓 수칙이 실제로 발동해야 함정이 성립한다")

	var bag_ctx := _ctx(CUST_BAG, "23:00")
	r.equals(_verdict_of(CUST_BAG, "23:00"), Verdict.SERVE,
		"가방을 들었을 뿐인 손님은 판매가 정답")
	r.check(_engine.lies_in_play(bag_ctx).size() > 0, "가방 수칙(거짓)이 발동해야 한다")


func _test_trap_detection(r: RefCounted) -> void:
	var ctx := _ctx(CUST_WET_NO_SHADOW, "23:00")
	var followed := _engine.evaluate(ctx, Verdict.serve())
	r.check(not followed.correct, "거짓 수칙을 따르면 틀린다")
	r.check(followed.is_trap_death(), "거짓 수칙을 따라 틀린 경우는 함정으로 분류된다")
	r.check(followed.missed_clue_keys.size() > 0, "함정에 걸리면 놓친 단서를 반드시 제시한다")

	var resisted := _engine.evaluate(ctx, Verdict.refuse())
	r.check(resisted.correct, "거짓 수칙을 무시하면 맞다")
	r.check(not resisted.trap_triggered, "정답일 때는 함정 플래그가 서지 않는다")

	var bag_wrong := _engine.evaluate(_ctx(CUST_BAG, "23:00"), Verdict.refuse())
	r.check(bag_wrong.is_trap_death(), "거짓 수칙을 따라 정상 손님을 거부해도 함정이다")

	# 아무 수칙도 발동하지 않은 손님을 거부한 경우. 함정이 아니라 그냥 오판이다.
	# 이때도 이유를 댈 수 있어야 한다 — 이 경로가 없어서 불변식 3이 깨졌었다.
	var innocent := _engine.evaluate(_ctx(CUST_NORMAL, "23:00"), Verdict.refuse())
	r.check(not innocent.correct, "멀쩡한 손님을 거부하면 틀린다")
	r.check(not innocent.trap_triggered, "발동한 거짓 수칙이 없으므로 함정은 아니다")
	r.check(innocent.missed_clue_keys.has(RuleEngine.CLUE_NO_RULE_APPLIED),
		"수칙이 하나도 발동하지 않았다는 사실 자체를 단서로 제시한다")


## 거짓 수칙이 항상 틀리면 "거짓이면 무조건 반대로"가 최적 전략이 되어 긴장이 죽는다.
func _test_lie_can_be_accidentally_right(r: RefCounted) -> void:
	var ctx := _ctx(CUST_WET_OK, "23:00")
	r.check(_engine.lies_in_play(ctx).size() > 0, "젖은 정상 손님에게도 거짓 수칙은 발동한다")
	var result := _engine.evaluate(ctx, Verdict.serve())
	r.check(result.correct, "거짓 수칙이 우연히 맞는 경우가 존재해야 한다")


func _test_decaying(r: RefCounted) -> void:
	var decaying := Rule.from_dict({
		"id": "tmp_decaying",
		"veracity": Rule.VERACITY_DECAYING,
		"decays_at_night": 5,
		"tell_key": "tell.tmp",
	})
	r.check(not decaying.is_lie_at(4), "전환 전에는 참이다")
	r.check(decaying.is_lie_at(5), "지정된 밤부터 거짓으로 바뀐다")
	r.check(decaying.is_lie_at(6), "전환 이후로는 계속 거짓이다")
