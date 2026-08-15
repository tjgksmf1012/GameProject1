extends SceneTree

## 실행: godot --headless --script res://tests/run_tests.gd
##
## systems/ 가 노드에 의존하지 않기 때문에 화면 없이 전부 검증할 수 있다.
## AI는 화면을 볼 수 없으므로 (CLAUDE.md 3절) 이 경로가 유일한 신뢰 가능한 피드백 루프다.

const TestSupport := preload("res://tests/test_support.gd")
const TestRuleEngine := preload("res://tests/test_rule_engine.gd")
const TestFairness := preload("res://tests/test_fairness.gd")
const TestFairnessChannels := preload("res://tests/test_fairness_channels.gd")
const TestNightSession := preload("res://tests/test_night_session.gd")
const TestSessionLog := preload("res://tests/test_session_log.gd")
const TestSfxBank := preload("res://tests/test_sfx_bank.gd")
const TestPosGate := preload("res://tests/test_pos_gate.gd")
const TestNightPlan := preload("res://tests/test_night_plan.gd")
const TestPatience := preload("res://tests/test_patience.gd")
const TestRuleVoice := preload("res://tests/test_rule_voice.gd")
const TestStrings := preload("res://tests/test_strings.gd")
const TestClipboard := preload("res://tests/test_clipboard.gd")
const TestNightReport := preload("res://tests/test_night_report.gd")
const TestSnapshot := preload("res://tests/test_snapshot.gd")
const TestPlaythrough := preload("res://tests/test_playthrough.gd")
const TestNotes := preload("res://tests/test_notes.gd")
const TestArtPalette := preload("res://tests/test_art_palette.gd")
const TestFigureOutline := preload("res://tests/test_figure_outline.gd")


func _initialize() -> void:
	var reporter := TestSupport.new()
	print("NIGHTSHIFT 테스트")
	print("─────────────────────────────")
	var suites := [
		TestRuleEngine.new(), TestFairness.new(), TestFairnessChannels.new(),
		TestNightSession.new(),
		TestSessionLog.new(), TestSfxBank.new(), TestPosGate.new(),
		TestNightPlan.new(), TestPatience.new(), TestRuleVoice.new(),
		TestStrings.new(), TestClipboard.new(), TestNightReport.new(),
		TestSnapshot.new(),
		TestPlaythrough.new(), TestNotes.new(), TestArtPalette.new(), TestFigureOutline.new(),
	]
	# `await`를 붙여둔다. 대부분의 스위트는 코루틴이 아니라 즉시 돌아오고, 프레임을
	# 기다려야 하는 스위트(트윈이 실제로 도는지 보는 것들)만 여기서 멈춘다.
	# 안 붙이면 그런 스위트는 첫 await에서 멈춘 채 아래 quit()에 죽는다 — 조용히.
	for suite in suites:
		await suite.run(reporter)
	var code := reporter.print_report()
	quit(code)
