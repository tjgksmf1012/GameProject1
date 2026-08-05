extends RefCounted

## 클립보드가 **엔진과 같은 것을 보여주는가.**
##
## 다른 테스트는 전부 노드 없이 돈다 (CLAUDE.md 2절). 이건 예외다 — 여기서 잡으려는
## 버그가 정확히 "화면이 엔진과 다른 것을 들고 있다"이기 때문이다. 순수 로직으로는
## 재현할 수 없고, 스크린샷으로는 스크롤 아래에 숨어서 안 보인다.
##
## 실제로 있던 버그: 클립보드가 한 번 붙은 줄을 영영 들고 있었다. 밤 5의 열째 수칙은
## 02:00에 붙는데, 그 밤을 실패하고 다시 시작하면 22:00 화면에 이미 붙어 있었다.
## **아직 쓰이지도 않은 줄을 보고 판정하게 된다.**

const ClipboardPanel := preload("res://ui/clipboard/clipboard_panel.gd")


func run(r: RefCounted) -> void:
	r.suite("clipboard")
	var panel := _mount()
	_test_shows_exactly_what_the_engine_applies(r, panel)
	_test_late_rule_disappears_on_restart(r, panel)
	panel.queue_free()


func _mount() -> Control:
	var panel := ClipboardPanel.new()
	panel.set_strings(GameData.load_strings())
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	return panel


func _shown(panel: Control) -> PackedStringArray:
	return panel._shown_ids.duplicate()


## 밤·시각마다 화면에 붙은 줄과 엔진이 적용 대상으로 보는 줄이 같아야 한다.
func _test_shows_exactly_what_the_engine_applies(r: RefCounted, panel: Control) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var minutes := NightSession.arrival_minutes(i, customers.size())
			var visible := engine.visible_rules(night, minutes)
			panel.show_rules(visible)
			var expected := PackedStringArray()
			for rule in visible:
				expected.append(rule.id)
			var actual := _shown(panel)
			actual.sort()
			expected.sort()
			r.equals(actual, expected,
				"%d일째 밤 %s에 화면과 엔진이 같은 수칙을 본다"
					% [night, ShiftClock.to_display(minutes)])


## 밤을 실패하고 다시 시작하면 근무 중에 붙었던 줄이 **사라져 있어야** 한다.
func _test_late_rule_disappears_on_restart(r: RefCounted, panel: Control) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var late := _first_late_rule()
	r.check(late != null, "근무 중에 붙는 수칙이 있어야 이 검사가 의미를 가진다")
	if late == null:
		return
	var night := late.introduced_night

	panel.show_rules(engine.visible_rules(night, late.arrives_at_minute))
	r.check(_shown(panel).has(late.id), "붙는 시각이 지나면 화면에 있다")

	# 밤을 다시 시작한다 — 근무 시작 시점으로 되돌린다.
	panel.show_rules(engine.visible_rules(night, 0))
	r.check(not _shown(panel).has(late.id),
		"다시 시작하면 아직 안 붙은 줄(%s)이 화면에서 사라진다" % late.id)


func _first_late_rule() -> Rule:
	for rule in GameData.load_rules():
		if rule.arrives_mid_shift():
			return rule
	return null
