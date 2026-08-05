extends RefCounted

## 플레이테스트 기록기. 테스터 앞에서 기록이 깨지면 그 세션은 통째로 날아간다.

const TESTER := "test_dummy"


func run(r: RefCounted) -> void:
	r.suite("session_log")
	_test_judgment_entry(r)
	_test_attempts(r)
	_test_save_roundtrip(r)


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
