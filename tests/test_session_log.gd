extends RefCounted

## 플레이테스트 기록기. 테스터 앞에서 기록이 깨지면 그 세션은 통째로 날아간다.

const TESTER := "test_dummy"


func run(r: RefCounted) -> void:
	r.suite("session_log")
	_test_judgment_entry(r)
	_test_attempts(r)
	_test_save_roundtrip(r)
	_test_no_tester_writes_nothing(r)


func _make_session() -> NightSession:
	var engine := RuleEngine.new(GameData.load_rules())
	return NightSession.new(engine, GameData.load_customers(), GameData.load_balance())


func _test_judgment_entry(r: RefCounted) -> void:
	var session := _make_session()
	var log := SessionLog.new(TESTER, true)
	var ctx := session.current_context()
	var result := session.judge(Verdict.refuse())
	log.record_judgment(ctx, result, 12.34)
	r.equals(log.entry_count(), 1, "판정 하나가 기록된다")
	var entry: Dictionary = log.to_dictionary()["entries"][0]
	r.equals(entry["customer"], ctx.customer.id, "손님 id가 남는다")
	r.equals(entry["verdict"], Verdict.REFUSE, "판정이 남는다")
	r.equals(entry["correct"], result.correct, "정오답이 남는다")
	r.equals(entry["decision_seconds"], 12.3, "판정 소요 시간이 0.1초 단위로 남는다")
	r.equals(entry["time"], ctx.time_display(), "게임 내 시각이 남는다")


func _test_attempts(r: RefCounted) -> void:
	var log := SessionLog.new(TESTER, false)
	r.equals(log.attempt, 1, "첫 시도는 1이다")
	log.begin_next_attempt()
	r.equals(log.attempt, 2, "재시작하면 시도 번호가 오른다")
	r.equals(log.to_dictionary()["grace_on_first_trap"], false, "유예 조건이 기록에 남는다")


## 두 조건(유예 켬/끔)을 나중에 비교하려면 파일이 실제로 읽혀야 한다.
func _test_save_roundtrip(r: RefCounted) -> void:
	var session := _make_session()
	var log := SessionLog.new(TESTER, true)
	log.record_judgment(session.current_context(), session.judge(Verdict.serve()), 1.0)
	log.record_night_end(session, 480.0)
	var path := log.save()
	r.check(path != "", "저장 경로를 돌려준다")

	var stored := "%s/%s.json" % [SessionLog.LOG_DIR, TESTER]
	r.check(FileAccess.file_exists(stored), "파일이 실제로 생성된다")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(stored))
	r.check(typeof(parsed) == TYPE_DICTIONARY, "저장된 내용이 다시 파싱된다")
	if typeof(parsed) == TYPE_DICTIONARY:
		r.equals((parsed as Dictionary)["tester_id"], TESTER, "테스터 id가 보존된다")
		r.equals(((parsed as Dictionary)["entries"] as Array).size(), 2, "기록 두 건이 보존된다")
	DirAccess.remove_absolute(stored)


## **계측기를 안 켰으면 아무것도 안 남긴다.**
##
## 예전에는 `--tester=` 가 없으면 타임스탬프로 아이디를 지어냈다. 그래서 모든 플레이어의
## 기록이 남았고, 더 나쁘게는 밤 종료 화면이 그 파일의 **절대 경로**를 찍었다 —
## 사용자 이름이 들어간 홈 디렉터리 경로가 매일 밤 화면에 떴다. 방송에 그대로 나간다.
func _test_no_tester_writes_nothing(r: RefCounted) -> void:
	var log := SessionLog.new("", true)
	r.equals(log.save(), "", "테스터 아이디가 없으면 기록을 쓰지 않고 빈 경로를 돌려준다")
	# 그리고 빈 경로면 밤 종료 화면에서 그 줄이 통째로 빠진다.
	var report := NightReport.new(GameData.load_strings())
	var quiet := report.night_detail(5, 1, 2, "")
	var loud := report.night_detail(5, 1, 2, "/home/somebody/playtest/x.json")
	r.check(not quiet.contains("\n"), "경로가 없으면 요약이 한 줄이다")
	r.check(loud.contains("/home/somebody"), "경로를 주면 그때만 찍힌다")

	# **두 층을 다 막아야 한다.** SessionLog 만 막으면 화면 쪽에서 아이디를 지어내는 순간
	# 다시 새어나온다. 값으로는 증명할 수 없어 구조를 본다 (test_night_plan 의 취소선 검사와 같은 수법).
	var source := FileAccess.get_file_as_string("res://main/night_screen.gd")
	r.check(source != "", "night_screen.gd 를 읽을 수 있다")
	r.check(not source.contains("tester_%d"),
		"night_screen 이 테스터 아이디를 스스로 지어낸다 — 모든 플레이어의 기록이 남는다")
