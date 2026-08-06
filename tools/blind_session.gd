extends SceneTree

## **블라인드 플레이 진행기.** 지금까지의 판정을 받아 그 다음 화면을 내놓는다.
##
##   godot --headless --script res://tools/blind_session.gd -- --night=1
##   godot --headless --script res://tools/blind_session.gd -- --night=1 --decisions=serve,refuse
##
## `tools/observe.gd`는 한 손님의 화면만 찍는다. 이건 **밤을 진행시킨다** — 판정하면
## 결과가 뜨고 오판이 쌓이고 다음 손님이 온다. 학습이 일어나려면 이 되먹임이 있어야 한다.
## 「거짓 수칙이 있다」는 것은 틀려 봐야 알 수 있고, 틀려 볼 수 없으면 H1은 검증 자체가 불가능하다.
##
## 상태를 파일에 두지 않는다. 판정 목록을 매번 처음부터 재생한다 — 결정론적이므로 결과가 같고,
## 프로세스가 상태를 들고 있지 않으므로 **읽는 쪽이 화면 말고 다른 것을 볼 통로가 없다.**
##
## 출력에 정답이 섞이지 않는다는 보장은 `tests/test_snapshot.gd`가 한다.
## 그 검사가 깨진 채로 여기서 나온 결론은 전부 버려야 한다.

const SEPARATOR := "─────────────────────────────"


func _initialize() -> void:
	var night := int(_arg("--night=", "1"))
	var plan := NightPlan.load()
	if not plan.has_night(night):
		push_error("그런 밤이 없다: %d" % night)
		quit(1)
		return
	var strings := GameData.load_strings(GameData.resolve_locale())
	var session := NightSession.new(RuleEngine.new(GameData.load_rules()),
		plan.customers_for(night), GameData.load_balance(), night)
	var out := _replay(session, strings)
	print(JSON.stringify(out, "  "))
	quit(0)


## 판정 목록을 처음부터 재생하고, 그 결과들과 **다음에 볼 화면**을 함께 돌려준다.
func _replay(session: NightSession, strings: Dictionary) -> Dictionary:
	var perception := _arg("--perception=", ScreenSnapshot.PERCEPTION_NAMED)
	var struck := _arg("--struck=", "").split(",", false)
	var history := []
	for id in _arg("--decisions=", "").split(",", false):
		if session.is_finished():
			break
		var asked := ScreenSnapshot.of(session.engine, session.current_context(),
			strings, struck, _progress(session), perception)
		var result := session.judge(Verdict.from_id(str(id).strip_edges()))
		history.append({
			"customer": asked["counter"]["name"],
			"time": asked["time"],
			"i_chose": str(id).strip_edges(),
			"screen_after": ScreenSnapshot.of_result(result, strings),
		})
		session.advance()
	return {
		"history": history,
		"now": null if session.is_finished() else ScreenSnapshot.of(
			session.engine, session.current_context(), strings, struck,
			_progress(session), perception),
		"finished": session.is_finished(),
		"night_over": _night_over(session, strings),
	}


## 화면 오른쪽 위에 늘 떠 있는 것. 오판 수를 빼면 사람보다 불리해진다.
func _progress(session: NightSession) -> Dictionary:
	return {
		"customer": session.index + 1,
		"total": session.total_customers(),
		"misjudge": session.misjudge_count,
		"misjudge_limit": session.misjudge_limit(),
	}


func _night_over(session: NightSession, strings: Dictionary) -> Variant:
	if not session.is_finished():
		return null
	var key := "night.failed" if session.is_failed() else "night.cleared"
	return {
		"failed": session.is_failed(),
		"headline": str(strings.get(key, key)) % session.misjudge_count \
			if session.is_failed() else str(strings.get(key, key)),
		"correct": session.correct_count,
		"misjudge": session.misjudge_count,
	}


static func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
