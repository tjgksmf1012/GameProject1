extends RefCounted

## 하룻밤 진행. 특히 **첫 함정 유예**가 의도대로 동작하는지 본다.
## 유예는 H1(거짓 수칙이 짜증이 아니라 재미인가) 검증 시 껐다 켜며 두 조건을 비교할 스위치다.

func run(r: RefCounted) -> void:
	r.suite("night_session")
	_test_perfect_night(r)
	_test_failure_limit(r)
	_test_grace_absorbs_first_trap(r)
	_test_second_trap_is_not_graced(r)
	_test_grace_disabled(r)


func _make(balance_overrides: Dictionary = {}) -> NightSession:
	var balance := GameData.load_balance()
	for key in balance_overrides:
		balance[key] = balance_overrides[key]
	var engine := RuleEngine.new(GameData.load_rules())
	return NightSession.new(engine, GameData.load_customers(), balance)


## 매 손님마다 정답을 조회해 그대로 낸다 — 밤이 실제로 완주 가능한지 확인한다.
func _play_perfectly(session: NightSession) -> void:
	while not session.is_finished():
		var expected := session.engine.required_verdicts(session.current_context())
		session.judge(expected[0])
		session.advance()


func _test_perfect_night(r: RefCounted) -> void:
	var session := _make()
	_play_perfectly(session)
	r.check(session.is_finished(), "밤이 끝난다")
	r.check(not session.is_failed(), "정답만 내면 실패하지 않는다")
	r.equals(session.correct_count, session.total_customers(), "모든 손님을 정상 응대했다")
	r.equals(session.misjudge_count, 0, "오판이 없다")


func _test_failure_limit(r: RefCounted) -> void:
	var session := _make({"grace_on_first_trap": false})
	# 그림자 없는 손님에게 계속 판매하면 확실히 틀린다.
	var wrong := Verdict.serve()
	var guard := 0
	while not session.is_finished() and guard < 100:
		var expected := session.engine.required_verdicts(session.current_context())
		session.judge(wrong if not expected[0].equals(wrong) else Verdict.refuse())
		session.advance()
		guard += 1
	r.check(session.is_failed(), "오판이 한도에 도달하면 밤이 실패한다")
	r.equals(session.misjudge_count, session.misjudge_limit(), "오판 횟수가 한도에서 멈춘다")


func _test_grace_absorbs_first_trap(r: RefCounted) -> void:
	var session := _make({"grace_on_first_trap": true})
	# 첫 손님(정상)은 정답, 두 번째(가방)는 거짓 수칙을 따라 거부 → 함정.
	session.judge(Verdict.serve())
	session.advance()
	var trapped := session.judge(Verdict.refuse())
	r.check(trapped.is_trap_death(), "가방 손님을 거부하면 함정에 걸린다")
	r.equals(session.trap_count, 1, "함정 횟수는 센다")
	r.equals(session.misjudge_count, 0, "첫 함정은 오판으로 세지 않는다")
	r.check(session.grace_used, "유예가 소진됐다")
	r.check(trapped.graced, "이 판정이 유예됐다는 사실이 결과에 기록된다")


## `grace_used`는 한 번 켜지면 계속 켜져 있으므로, 두 번째 함정에 유예 문구가 뜨면 안 된다.
func _test_second_trap_is_not_graced(r: RefCounted) -> void:
	var session := _make({"grace_on_first_trap": true})
	session.judge(Verdict.serve())          # 0. 정상 손님 — 정답
	session.advance()
	var first := session.judge(Verdict.refuse())   # 1. 가방 학생 — 함정 1
	session.advance()
	for i in 2:                              # 2, 3 건너뛴다
		session.judge(session.engine.required_verdicts(session.current_context())[0])
		session.advance()
	var second := session.judge(Verdict.serve())   # 4. 젖고 그림자 없음 — 함정 2
	r.check(first.graced, "첫 함정은 유예된다")
	r.check(second.is_trap_death(), "두 번째도 함정이 맞다")
	r.check(not second.graced, "두 번째 함정은 유예되지 않는다")
	r.equals(session.trap_count, 2, "함정 횟수는 둘 다 센다")
	r.equals(session.misjudge_count, 1, "두 번째 함정만 오판으로 잡힌다")


func _test_grace_disabled(r: RefCounted) -> void:
	var session := _make({"grace_on_first_trap": false})
	session.judge(Verdict.serve())
	session.advance()
	session.judge(Verdict.refuse())
	r.equals(session.misjudge_count, 1, "유예를 끄면 첫 함정도 오판이다")
