extends SceneTree

## **한 밤의 자리 하나에 누굴 놓을 수 있는가.** 후보를 빠짐없이 편다.
##   godot --headless --script res://tools/slot_probe.gd -- --night=3
##
## 밤을 손보다가 한 번 크게 틀린 적이 있다. 후보 17명 중 6명만 보고 안을 냈고,
## 그 안은 밤 3에서 **첫째 수칙이 한 번도 발동하지 않게** 만들었다. 자리 하나를 바꾸면
## 그 자리에서 무엇이 발동하는지가 통째로 달라지는데, 머리로 세면 반드시 빠뜨린다.
##
## 그래서 센다. 손님 전원 × 자리 전원. 각 칸마다 세 가지를 적는다:
##   정답      — 그 시각 그 손님의 참 판정
##   무는 거짓 — 정답과 **다른 말을 하는** 거짓 수칙 (없으면 함정이 아니다)
##   발동한 참 — 이 자리가 어느 참 수칙을 살려두는가 (밤에서 사라지면 안 되는 것들)

const SEPARATOR := "──────────────────────────────────────────────────────────────────────"


func _initialize() -> void:
	var night := _int_arg("--night", 3)
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	var here := plan.customers_for(night)
	var total := here.size()
	print("밤 %d — 자리 %d개. 현재 배치를 기준으로 각 자리의 후보 전원을 편다.\n" % [night, total])
	_print_current(engine, plan, night)
	for slot in total:
		_print_slot(engine, night, slot, total, here)
	quit(0)


func _int_arg(name: String, fallback: int) -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return int(arg.split("=")[1])
	return fallback


## 지금 이 밤이 어느 참 수칙을 살려두고 있는가. 자리를 바꾸다 죽이면 안 되는 목록이다.
func _print_current(engine: RuleEngine, plan: NightPlan, night: int) -> void:
	var fired := {}
	var customers := plan.customers_for(night)
	for i in customers.size():
		var ctx := JudgeContext.new(night, NightSession.arrival_minutes(i, customers.size()),
			customers[i])
		for rule in _fired_truths(engine, ctx):
			fired[rule] = int(fired.get(rule, 0)) + 1
	print("이 밤이 살려두는 참 수칙 (자리를 바꿔도 0이 되면 안 된다):")
	for rule in engine.rules():
		if rule.is_lie_at(night) or not rule.is_active_at(night):
			continue
		print("   %-28s %d번 발동" % [rule.id, int(fired.get(rule.id, 0))])
	print(SEPARATOR)


func _fired_truths(engine: RuleEngine, ctx: JudgeContext) -> PackedStringArray:
	var out := PackedStringArray()
	for rule in engine.rules():
		if not rule.is_active_at(ctx.night, ctx.shift_minutes) or rule.is_lie_at(ctx.night):
			continue
		if rule.matches(ctx):
			out.append(rule.id)
	return out


func _biting_lies(engine: RuleEngine, ctx: JudgeContext, truth: Array[Verdict]) -> PackedStringArray:
	var out := PackedStringArray()
	for lie in engine.lies_in_play(ctx):
		if not Verdict.contains(truth, lie.verdict()):
			out.append(lie.id)
	return out


func _print_slot(
	engine: RuleEngine, night: int, slot: int, total: int, here: Array[Customer]
) -> void:
	var minutes := NightSession.arrival_minutes(slot, total)
	print("\n[%d] %s   지금: %s" % [slot, ShiftClock.to_display(minutes), here[slot].id])
	print(SEPARATOR)
	for customer in GameData.load_customers():
		var ctx := JudgeContext.new(night, minutes, customer)
		var truth := engine.required_verdicts(ctx)
		var bites := _biting_lies(engine, ctx, truth)
		var kind := "함정" if bites.size() > 0 else ("모순" if truth.size() > 1 else "조회")
		print("  %s %-26s %s  정답 %-4s  무는거짓 %-46s  참 %s"
			% ["→" if customer.id == here[slot].id else " ", customer.id, kind,
				_verdicts(truth), ",".join(bites), ",".join(_fired_truths(engine, ctx))])


func _verdicts(list: Array[Verdict]) -> String:
	var out := PackedStringArray()
	for v in list:
		out.append(v.id())
	return "/".join(out)
