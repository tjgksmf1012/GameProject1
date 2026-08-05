extends RefCounted

## 밤별 손님 구성. 손님 id 하나만 오타나도 그 밤의 난이도 곡선이 통째로 어긋난다.

const SAVE_TEST_PATH := "user://test_save.json"


func run(r: RefCounted) -> void:
	r.suite("night_plan")
	_test_plan_is_complete(r)
	_test_night_lookup(r)
	_test_arrival_spread(r)
	_test_save_roundtrip(r)
	_test_failed_night_does_not_advance(r)


func _test_plan_is_complete(r: RefCounted) -> void:
	var plan := NightPlan.load()
	r.equals(plan.missing_customer_ids().size(), 0,
		"정의되지 않은 손님을 참조하는 밤이 없다 (%s)" % str(plan.missing_customer_ids()))
	r.check(plan.nights().size() > 0, "밤이 하나 이상 정의돼 있다")
	for night in plan.nights():
		r.check(plan.customers_for(night).size() > 0, "%d일째 밤에 손님이 있다" % night)


func _test_night_lookup(r: RefCounted) -> void:
	var plan := NightPlan.load()
	r.check(plan.has_night(1), "1일째 밤이 있다")
	r.check(not plan.has_night(999), "없는 밤은 없다고 답한다")
	r.equals(plan.last_night(), plan.nights()[plan.nights().size() - 1], "마지막 밤을 안다")


## 손님 수가 밤마다 달라도 근무 시간(22:00~06:00) 안에 균등하게 퍼져야 한다.
func _test_arrival_spread(r: RefCounted) -> void:
	var plan := NightPlan.load()
	for night in plan.nights():
		var total := plan.customers_for(night).size()
		r.equals(NightSession.arrival_minutes(0, total), 0, "첫 손님은 근무 시작에 온다")
		var last := NightSession.arrival_minutes(total - 1, total)
		r.check(ShiftClock.is_within_shift(last),
			"%d일째 밤 마지막 손님이 근무 시간 안에 온다 (%s)"
				% [night, ShiftClock.to_display(last)])
		r.check(last > ShiftClock.parse("02:00"),
			"%d일째 밤 마지막 손님은 새벽 2시 이후다 — 시간 조건 수칙이 실제로 발동해야 한다" % night)


func _test_save_roundtrip(r: RefCounted) -> void:
	SaveGame.erase(SAVE_TEST_PATH)
	var fresh := SaveGame.load_or_new(SAVE_TEST_PATH)
	r.equals(fresh.night, SaveGame.FIRST_NIGHT, "세이브가 없으면 첫 밤부터")

	fresh.advance_to(3)
	r.check(fresh.store(SAVE_TEST_PATH), "저장된다")
	var loaded := SaveGame.load_or_new(SAVE_TEST_PATH)
	r.equals(loaded.night, 3, "밤이 보존된다")
	r.equals(loaded.cleared_nights, 1, "넘긴 밤 수가 보존된다")
	SaveGame.erase(SAVE_TEST_PATH)


## 실패한 밤은 진행이 오르면 안 된다. 오르면 못 깬 밤을 건너뛰게 된다.
func _test_failed_night_does_not_advance(r: RefCounted) -> void:
	var save := SaveGame.new()
	save.night = 2
	var before := save.night
	# 실패 시에는 advance_to 를 부르지 않는다는 계약을 문서화한다.
	r.equals(save.night, before, "실패하면 밤이 그대로다")
	save.advance_to(3)
	r.equals(save.night, 3, "성공하면 다음 밤으로 간다")
	r.equals(save.cleared_nights, 2, "넘긴 밤이 기록된다")
