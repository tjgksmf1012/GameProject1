extends SceneTree

## 실행: godot --headless --script res://tests/run_tests.gd
##
## systems/ 가 노드에 의존하지 않기 때문에 화면 없이 전부 검증할 수 있다.
## AI는 화면을 볼 수 없으므로 (CLAUDE.md 3절) 이 경로가 유일한 신뢰 가능한 피드백 루프다.

const TestSupport := preload("res://tests/test_support.gd")
const TestRuleEngine := preload("res://tests/test_rule_engine.gd")
const TestFairness := preload("res://tests/test_fairness.gd")
const TestNightSession := preload("res://tests/test_night_session.gd")
const TestSessionLog := preload("res://tests/test_session_log.gd")
const TestSfxBank := preload("res://tests/test_sfx_bank.gd")
const TestPosGate := preload("res://tests/test_pos_gate.gd")
const TestNightPlan := preload("res://tests/test_night_plan.gd")
const TestPatience := preload("res://tests/test_patience.gd")
const TestRuleVoice := preload("res://tests/test_rule_voice.gd")


func _initialize() -> void:
	var reporter := TestSupport.new()
	print("NIGHTSHIFT 테스트")
	print("─────────────────────────────")
	var suites := [
		TestRuleEngine.new(), TestFairness.new(), TestNightSession.new(),
		TestSessionLog.new(), TestSfxBank.new(), TestPosGate.new(),
		TestNightPlan.new(), TestPatience.new(), TestRuleVoice.new(),
	]
	for suite in suites:
		suite.run(reporter)
	var code := reporter.print_report()
	quit(code)
