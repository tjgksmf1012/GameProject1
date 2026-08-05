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

var _after_frames: int = AFTER_FRAMES

var _frames: int = 0
var _fired: bool = false
var _done: bool = false
var _out_path: String = "user://state.png"
var _verdict: String = Verdict.REFUSE
var _target_index: int = 0
var _advanced: int = 0


func _initialize() -> void:
	_out_path = _arg("--out=", _out_path)
	_verdict = _arg("--verdict=", _verdict)
	_after_frames = int(_arg("--after=", str(AFTER_FRAMES)))
	_target_index = int(_arg("--index=", "0"))
	var packed: PackedScene = load(SCENE)
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if not _fired and _frames >= SETTLE_FRAMES:
		_fire()
		return false
	if _fired and _frames >= SETTLE_FRAMES + _after_frames:
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
	while _advanced < _target_index:
		pos.verdict_chosen.emit(_correct_verdict())
		result_panel.continued.emit()
		_advanced += 1
	pos.verdict_chosen.emit(_verdict)
	_fired = true
	print("손님 %d 에서 판정 발사: %s" % [_target_index, _verdict])


## 지금 손님의 정답. 목표까지 가는 동안은 틀리지 않아야 밤이 안 끝난다.
func _correct_verdict() -> String:
	var engine := RuleEngine.new(GameData.load_rules())
	var customers := GameData.load_customers()
	var per := int(GameData.load_balance().get("minutes_per_customer", 80))
	var ctx := JudgeContext.new(1, _advanced * per, customers[_advanced])
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
