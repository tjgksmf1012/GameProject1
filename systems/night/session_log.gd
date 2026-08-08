class_name SessionLog
extends RefCounted

## M0 플레이테스트용 기록기. **출시 빌드의 텔레메트리(F-11)와는 다른 물건이다.**
## 이건 로컬 개발 도구다. 서버로 아무것도 보내지 않고 `user://`에만 쓴다.
##
## 관찰 4항목(01-user-research C-2)은 사람이 봐야 하지만, 아래는 자동으로 잡힌다:
##   · 손님별 판정 소요 시간 → 함정 손님에서 망설임이 늘어나는가 (H1의 방증)
##   · 재시작 횟수 → "첫 실패 후 다시 하고 싶어했는가"의 대리 지표
##   · 총 세션 시간 → H4(8~12분이 적절한가)

const LOG_DIR := "user://playtest"
const TESTER_ARG := "--tester="

var tester_id: String = ""
var grace_enabled: bool = true
var attempt: int = 1

var _entries: Array[Dictionary] = []


func _init(p_tester_id: String, p_grace_enabled: bool) -> void:
	tester_id = p_tester_id
	grace_enabled = p_grace_enabled


func record_judgment(ctx: JudgeContext, result: JudgeResult, decision_seconds: float) -> void:
	_entries.append({
		"type": "judgment",
		"attempt": attempt,
		"customer": ctx.customer.id if ctx.customer != null else "",
		"time": ctx.time_display(),
		"verdict": result.player_verdict.id(),
		"correct": result.correct,
		"trap": result.is_trap_death(),
		"graced": result.graced,
		"decision_seconds": snappedf(decision_seconds, 0.1),
	})


func record_night_end(session: NightSession, elapsed_seconds: float) -> void:
	_entries.append({
		"type": "night_end",
		"attempt": attempt,
		"correct": session.correct_count,
		"misjudge": session.misjudge_count,
		"traps": session.trap_count,
		"failed": session.is_failed(),
		"elapsed_seconds": snappedf(elapsed_seconds, 0.1),
	})


func begin_next_attempt() -> void:
	attempt += 1


func entry_count() -> int:
	return _entries.size()


func to_dictionary() -> Dictionary:
	return {
		"tester_id": tester_id,
		"grace_on_first_trap": grace_enabled,
		"recorded_at": Time.get_datetime_string_from_system(),
		"entries": _entries,
	}


## 저장하고 사람이 열어볼 수 있는 절대 경로를 돌려준다.
## **`--tester=` 를 준 사람만 기록을 남긴다.**
##
## 예전에는 인자가 없으면 타임스탬프로 아이디를 지어냈다. 그래서 **모든 플레이어**의
## 기록이 남고, 밤 종료 화면이 그 파일의 **절대 경로**를 찍었다 — 사용자 이름이 들어간
## 홈 디렉터리 경로가 매일 밤 화면에 떴다. 방송이나 스크린샷에 그대로 나간다.
##
## 화면이 아니라 기록기가 알 일이라 여기 있다. `main/night_screen.gd`에 있을 때는
## 「누가 기록되는가」가 오케스트레이터에 흩어져 있었다.
static func tester_id_from_cmdline() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(TESTER_ARG):
			return arg.substr(TESTER_ARG.length())
	return ""


## 계측기를 켠 사람만 기록한다. 아이디가 없으면 파일도 안 쓰고 경로도 안 돌려준다 —
## `night_report.night_detail` 이 빈 경로면 그 줄을 통째로 뺀다.
func save() -> String:
	if tester_id.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var path := "%s/%s.json" % [LOG_DIR, tester_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("플레이테스트 로그를 쓸 수 없다: %s" % path)
		return ""
	file.store_string(JSON.stringify(to_dictionary(), "  "))
	file.close()
	return ProjectSettings.globalize_path(path)
