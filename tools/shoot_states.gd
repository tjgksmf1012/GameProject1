extends SceneTree

## 실제 게임 화면을 몰아서 특정 상태를 찍는다.
##   xvfb-run -a godot --script res://tools/shoot_states.gd -- --out=/tmp/state.png --verdict=refuse
##
## `screenshot.gd`는 시작 화면만 찍는다. 이건 시그널을 직접 쏘아 판정 이후 화면까지 간다.
## 통합 경로(POS → NightScreen → ResultPanel)를 그대로 태우므로 연결이 끊기면 여기서 드러난다.

const POS_SCRIPT := "res://ui/pos/pos_terminal.gd"
const RESULT_SCRIPT := "res://ui/result_panel.gd"
const SCENE := "res://main/night_screen.tscn"

const SETTLE_FRAMES := 30
const AFTER_FRAMES := 45
## 판정 → 리플레이 → 결과가 한 사이클이다. 한 프레임에 몰아 쏘면 흐름이 겹친다.
const STEP_FRAMES := 250

var _after_frames: int = AFTER_FRAMES

var _frames: int = 0
var _fired: bool = false
var _done: bool = false
var _out_path: String = "user://state.png"
var _verdict: String = Verdict.REFUSE
var _target_index: int = 0
var _advanced: int = 0
var _next_step_frame: int = SETTLE_FRAMES
var _play_wrong: bool = false
var _awaiting_continue: bool = false
var _fire_frame: int = 0
var _night: int = 1
var _final_continue: int = -1
var _final_done: bool = false


func _initialize() -> void:
	_out_path = _arg("--out=", _out_path)
	_verdict = _arg("--verdict=", _verdict)
	_after_frames = int(_arg("--after=", str(AFTER_FRAMES)))
	_target_index = int(_arg("--index=", "0"))
	# 특정 밤 화면을 찍으려면 세이브를 먼저 써둔다. 게임은 세이브가 가리키는 밤부터 시작한다.
	_night = int(_arg("--night=", "1"))
	var save := SaveGame.new()
	save.night = _night
	save.store()
	_play_wrong = _arg("--wrong=", "0") == "1"
	_final_continue = int(_arg("--final-continue=", "-1"))
	var packed: PackedScene = load(SCENE)
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if not _fired and _frames >= _next_step_frame:
		_fire()
		return false
	# 밤이 실패로 끝나는 연출은 "다음 손님"을 한 번 더 눌러야 시작된다.
	if _fired and not _final_done and _final_continue >= 0 \
			and _frames >= _fire_frame + _final_continue:
		var panel := _find_by_script(root, RESULT_SCRIPT)
		if panel != null:
			panel.continued.emit()
		_final_done = true
	if _fired and _frames >= _fire_frame + _after_frames:
		_capture()
		_done = true
	return false


## 목표 손님까지 정답으로 진행한 뒤, 거기서 지정한 판정을 쏜다.
func _fire() -> void:
	var pos := _find_by_script(root, POS_SCRIPT)
	var result_panel := _find_by_script(root, RESULT_SCRIPT)
	if pos == null or result_panel == null:
		push_error("화면 구성이 바뀌었다 — POS 또는 결과 패널을 찾을 수 없다")
		_done = true
		return
	if _advanced < _target_index:
		# 판정과 진행을 같은 프레임에 쏘면 리플레이가 도는 중에 다음 손님이 들어온다.
		if _awaiting_continue:
			result_panel.continued.emit()
			_awaiting_continue = false
			_advanced += 1
		else:
			pos.verdict_chosen.emit(_step_verdict())
			_awaiting_continue = true
		_next_step_frame = _frames + STEP_FRAMES
		return
	pos.verdict_chosen.emit(_verdict)
	_fired = true
	_fire_frame = _frames
	print("손님 %d 에서 판정 발사: %s" % [_target_index, _verdict])


## 목표까지 가는 동안 무엇을 낼지. 기본은 정답(밤이 안 끝나야 하므로),
## `--wrong=1`이면 일부러 오답을 내서 밤을 실패시킨다 (사망 연출 촬영용).
func _step_verdict() -> String:
	var right := _correct_verdict()
	if not _play_wrong:
		return right
	return Verdict.REFUSE if right == Verdict.SERVE else Verdict.SERVE


func _correct_verdict() -> String:
	# **밤 번호를 넘겨야 한다.** 1로 굳히면 밤 2의 수칙이 빠진 채 정답을 계산해
	# 도구가 엉뚱한 판정을 쏘고, 밤이 의도대로 진행되지 않는다.
	var engine := RuleEngine.new(GameData.load_rules())
	var customers := NightPlan.load().customers_for(_night)
	var ctx := JudgeContext.new(
		_night, NightSession.arrival_minutes(_advanced, customers.size()), customers[_advanced])
	return engine.required_verdicts(ctx)[0].id()


func _capture() -> void:
	var image := root.get_texture().get_image()
	if image == null or image.save_png(_out_path) != OK:
		push_error("스크린샷 저장 실패")
		return
	print("저장됨: ", ProjectSettings.globalize_path(_out_path))


static func _find_by_script(node: Node, script_path: String) -> Node:
	var script: Variant = node.get_script()
	if script is Script and (script as Script).resource_path == script_path:
		return node
	for child in node.get_children():
		var found := _find_by_script(child, script_path)
		if found != null:
			return found
	return null


static func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
