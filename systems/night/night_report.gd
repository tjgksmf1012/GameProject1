class_name NightReport
extends RefCounted

## 밤이 끝났을 때 화면에 뭐라고 쓸지 정한다.
##
## `main/night_screen.gd`에서 떼어냈다 — 흐름이 아니라 **판단**이고(끝난 밤인가,
## 마지막 밤인가, 몇 줄을 그어놨나), 노드가 필요 없으므로 헤드리스로 검증할 수 있다.
## 오케스트레이터가 300줄 상한에 닿은 것도 이유다 (CLAUDE.md 1.4).

const KEY_FAILED := "night.failed"
const KEY_CLEARED := "night.cleared"
const KEY_SUMMARY := "night.summary"
const KEY_LOG_SAVED := "ui.log_saved"
const KEY_NEXT := "ui.night_cleared_next"
const KEY_RESTART := "ui.restart"

const KEY_ENDING_HEADLINE := "ending.headline"
const KEY_ENDING_HANDOVER := "ending.handover"
const KEY_ENDING_MARKS := "ending.marks"
const KEY_ENDING_NO_MARKS := "ending.no_marks"
const KEY_ENDING_CLOSE := "ui.ending_close"

var _strings: Dictionary = {}


func _init(strings: Dictionary) -> void:
	_strings = strings


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


## 마지막 밤을 넘겼는가. 실패했으면 아무리 마지막 밤이어도 끝난 게 아니다.
static func is_ending(cleared: bool, has_next_night: bool) -> bool:
	return cleared and not has_next_night


func headline(cleared: bool, has_next_night: bool, misjudges: int) -> String:
	if not cleared:
		return _t(KEY_FAILED) % misjudges
	if is_ending(cleared, has_next_night):
		return _t(KEY_ENDING_HEADLINE)
	return _t(KEY_CLEARED)


func continue_label(cleared: bool, has_next_night: bool) -> String:
	if is_ending(cleared, has_next_night):
		return _t(KEY_ENDING_CLOSE)
	if cleared and has_next_night:
		return _t(KEY_NEXT)
	return _t(KEY_RESTART)


func night_detail(correct: int, misjudges: int, traps: int, log_path: String) -> String:
	var lines := PackedStringArray([_t(KEY_SUMMARY) % [correct, misjudges, traps]])
	if log_path != "":
		lines.append(_t(KEY_LOG_SAVED) % log_path)
	return "\n".join(lines)


## **플레이어가 그어둔 줄이 그대로 다음 사람에게 넘어간다.**
##
## 취소선은 판정에 아무 영향이 없다 — 순전히 플레이어의 믿음이다. 그 믿음이 유일하게
## 무언가를 남기는 지점이 여기다. 일곱 밤 동안 무엇을 거짓이라 결론 냈는지가,
## 다음 사람이 처음 읽게 될 클립보드가 된다.
func ending_detail(struck_count: int) -> String:
	return "\n".join(PackedStringArray([
		_t(KEY_ENDING_HANDOVER),
		_t(KEY_ENDING_MARKS) % struck_count if struck_count > 0 else _t(KEY_ENDING_NO_MARKS),
	]))


## 밤 종료 화면에 들어갈 세 조각을 한 번에 만든다.
##
## 오케스트레이터에 흩어져 있었다. **이건 흐름이 아니라 판단이다** — 끝난 밤인가,
## 마지막 밤인가, 몇 줄을 그어놨나. 노드가 필요 없으므로 여기서 헤드리스로 검증된다.
## (`main/night_screen.gd`가 300줄 상한에 닿은 것도 이유다. CLAUDE.md 1.4)
func summary(session: NightSession, has_next: bool, struck: int, log_path: String) -> Dictionary:
	var cleared := not session.is_failed()
	var ending := is_ending(cleared, has_next)
	return {
		"ending": ending,
		"headline": headline(cleared, has_next, session.misjudge_count),
		"detail": ending_detail(struck) if ending else night_detail(
			session.correct_count, session.misjudge_count, session.trap_count, log_path),
		"button": continue_label(cleared, has_next),
	}
