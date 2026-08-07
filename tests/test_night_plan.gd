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
	_test_strikes_are_belief_not_truth(r)
	_test_true_conflict_actually_happens(r)
	_test_torn_rule_changes_an_answer(r)
	_test_new_rule_matters_on_its_debut_night(r)


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
	fresh.toggle_strike("rule_refuse_bag")
	r.check(fresh.store(SAVE_TEST_PATH), "저장된다")
	var loaded := SaveGame.load_or_new(SAVE_TEST_PATH)
	r.equals(loaded.night, 3, "밤이 보존된다")
	r.equals(loaded.cleared_nights, 1, "넘긴 밤 수가 보존된다")
	r.check(loaded.struck_rule_ids.has("rule_refuse_bag"), "그어둔 수칙이 밤을 넘어 남는다")
	SaveGame.erase(SAVE_TEST_PATH)


## 그은 표시는 **플레이어의 믿음이지 사실이 아니다.**
## 이게 판정에 새어들면 플레이어가 정답을 직접 쓰는 셈이 되고 게임이 끝난다.
func _test_strikes_are_belief_not_truth(r: RefCounted) -> void:
	var save := SaveGame.new()
	r.check(save.toggle_strike("rule_no_shadow"), "처음 누르면 그어진다")
	r.check(not save.toggle_strike("rule_no_shadow"), "다시 누르면 지워진다")
	r.equals(save.struck_rule_ids.size(), 0, "지우면 목록에서 빠진다")

	# 값을 비교해서는 이걸 증명할 수 없다 — 판정 경로에 표시를 넘기는 인자가 아예 없기 때문이다.
	# **증명해야 할 것은 구조다**: 수칙 엔진이 세이브를 아예 모른다는 것.
	# 누군가 "그은 줄은 평가에서 빼자"는 최적화를 넣는 순간 여기서 걸린다.
	for path in ["res://systems/rules/rule_engine.gd", "res://systems/rules/rule.gd"]:
		var source := FileAccess.get_file_as_string(path)
		r.check(source != "", "%s를 읽을 수 있다" % path)
		for forbidden in ["SaveGame", "struck"]:
			r.check(not source.contains(forbidden),
				"%s가 '%s'를 참조한다 — 플레이어의 믿음이 정답에 새어들었다" % [path, forbidden])


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


## 밤 6의 중심 사건 — **참 수칙 둘이 서로 반대를 요구하는 손님이 실제로 있는가.**
##
## 이 밤의 유일한 사건이고, 조용히 안 일어나도 화면상으로는 구분이 안 된다.
## 도착 시각이 1분만 어긋나도(`after 05:00` 경계) 그냥 평범한 손님이 되어버린다.
## 설계한 순간이 실제로 발동하는지는 검사로만 확인할 수 있다.
func _test_true_conflict_actually_happens(r: RefCounted) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	var found := PackedStringArray()
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var ctx := JudgeContext.new(
				night, NightSession.arrival_minutes(i, customers.size()), customers[i])
			if engine.required_verdicts(ctx).size() < 2:
				continue
			found.append("%d/%s" % [night, customers[i].id])
			# 충돌이면 **어느 쪽도 오답이 아니다.** 한쪽만 통과하면 충돌이 아니라 그냥 함정이다.
			for kind in [Verdict.SERVE, Verdict.REFUSE]:
				r.check(engine.evaluate(ctx, Verdict.from_id(kind)).correct,
					"%s: 참끼리 충돌하면 '%s'도 정답이어야 한다" % [customers[i].id, kind])
	r.check(found.size() > 0,
		"참 수칙끼리 충돌하는 손님이 하나도 없다 — 밤 6의 사건이 발동하지 않는다")


## 밤 7의 중심 사건 — **찢겨 나간 수칙이 실제로 정답을 바꾸는가.**
##
## 찢기는 것 자체는 연출이고, 의미는 "그 뒤로 답이 달라진다"에 있다.
## 찢긴 뒤에도 아무 손님의 답이 안 바뀌면 이 밤의 사건은 일어나지 않은 것과 같다.
func _test_torn_rule_changes_an_answer(r: RefCounted) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var torn: Rule = null
	for rule in GameData.load_rules():
		if rule.removed_night != Rule.NO_REMOVAL:
			torn = rule
			break
	r.check(torn != null, "찢겨 나가는 수칙이 있어야 이 검사가 의미를 가진다")
	if torn == null:
		return

	var plan := NightPlan.load()
	var customers := plan.customers_for(torn.removed_night)
	var flipped := 0
	for i in customers.size():
		var minutes := NightSession.arrival_minutes(i, customers.size())
		var ctx := JudgeContext.new(torn.removed_night, minutes, customers[i])
		if not torn.matches(ctx):
			continue
		# 찢기 전이라면 그 수칙이 답을 정했을 손님이다.
		var still_bound := engine.required_verdicts(ctx).has(torn.verdict())
		if minutes >= torn.removed_at_minute and not still_bound:
			flipped += 1
	r.check(flipped > 0,
		"%s가 찢긴 뒤 답이 바뀌는 손님이 하나도 없다 — 찢는 연출만 있고 사건이 없다" % torn.id)


## **클립보드에 한 줄 늘었으면 그 밤에 뭔가는 달라져야 한다.**
##
## 밤마다 수칙이 하나둘 붙는데, 붙기만 하고 그 밤에 아무 판정도 안 바꾸는 줄이 생길 수 있다.
## 플레이어에게는 "읽을 것이 늘었는데 읽을 이유는 없는" 밤이 되고, 다음 밤에 갑자기 문다.
##
## 참과 거짓에 요구하는 것이 다르다. 참 수칙은 **결정**해야 한다 — 그 줄을 빼면 정답이
## 달라지는 손님이 하나는 있어야 한다. 거짓 수칙은 **물어야** 한다 — 따랐을 때 틀리는
## 손님이 하나는 있어야 한다. 발동만 하는 것으로는 둘 다 부족하다.
##
## 전환 수칙은 두 번 걸린다. 도입한 밤에는 참으로서 결정해야 하고, 전환된 밤에는
## 거짓으로서 물어야 한다. 같은 줄인데 의무가 두 개다.
func _test_new_rule_matters_on_its_debut_night(r: RefCounted) -> void:
	var all_rules := GameData.load_rules()
	var plan := NightPlan.load()
	for rule in all_rules:
		if plan.has_night(rule.introduced_night) and rule.veracity != Rule.VERACITY_FALSE:
			r.check(_decides_something(all_rules, plan, rule, rule.introduced_night),
				"%s는 도입된 %d일째 밤에 아무 판정도 결정하지 않는다 — 읽을 이유가 없는 줄이다"
					% [rule.id, rule.introduced_night])
		var lie_night := _night_it_becomes_a_lie(rule)
		if lie_night > 0 and plan.has_night(lie_night):
			r.check(_bites_someone(all_rules, plan, rule, lie_night),
				"%s는 거짓이 되는 %d일째 밤에 아무도 물지 않는다 — 따라도 안 틀리는 거짓이다"
					% [rule.id, lie_night])


func _night_it_becomes_a_lie(rule: Rule) -> int:
	if rule.veracity == Rule.VERACITY_FALSE:
		return rule.introduced_night
	if rule.veracity == Rule.VERACITY_DECAYING:
		return rule.decays_at_night
	return 0


## 그 줄을 빼면 정답이 달라지는 손님이 있는가.
func _decides_something(
	all_rules: Array[Rule], plan: NightPlan, rule: Rule, night: int
) -> bool:
	var without: Array[Rule] = []
	for other in all_rules:
		if other.id != rule.id:
			without.append(other)
	var full := RuleEngine.new(all_rules)
	var thinner := RuleEngine.new(without)
	for ctx in _contexts(plan, night):
		if not _same_verdicts(full.required_verdicts(ctx), thinner.required_verdicts(ctx)):
			return true
	return false


## 그 줄을 따르면 틀리는 손님이 있는가.
func _bites_someone(all_rules: Array[Rule], plan: NightPlan, rule: Rule, night: int) -> bool:
	var engine := RuleEngine.new(all_rules)
	for ctx in _contexts(plan, night):
		if not rule.is_active_at(night, ctx.shift_minutes) or not rule.matches(ctx):
			continue
		if not Verdict.contains(engine.required_verdicts(ctx), rule.verdict()):
			return true
	return false


func _contexts(plan: NightPlan, night: int) -> Array[JudgeContext]:
	var out: Array[JudgeContext] = []
	var customers := plan.customers_for(night)
	for i in customers.size():
		out.append(JudgeContext.new(
			night, NightSession.arrival_minutes(i, customers.size()), customers[i]))
	return out


static func _same_verdicts(a: Array[Verdict], b: Array[Verdict]) -> bool:
	if a.size() != b.size():
		return false
	for v in a:
		if not Verdict.contains(b, v):
			return false
	return true
