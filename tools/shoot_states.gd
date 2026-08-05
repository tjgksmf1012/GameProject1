extends SceneTree

## 실제 게임 화면을 몰아서 특정 상태를 찍는다.
##   xvfb-run -a godot --script res://tools/shoot_states.gd -- --out=/tmp/state.png --verdict=refuse
##
## `screenshot.gd`는 시작 화면만 찍는다. 이건 시그널을 직접 쏘아 판정 이후 화면까지 간다.
## 통합 경로(POS → NightScreen → ResultPanel)를 그대로 태우므로 연결이 끊기면 여기서 드러난다.

const POS_SCRIPT := "res://ui/pos/pos_terminal.gd"
const SCENE := "res://main/night_screen.tscn"

const SETTLE_FRAMES := 30
const AFTER_FRAMES := 45

var _frames: int = 0
var _fired: bool = false
var _done: bool = false
var _out_path: String = "user://state.png"
var _verdict: String = Verdict.REFUSE


func _initialize() -> void:
	_out_path = _arg("--out=", _out_path)
	_verdict = _arg("--verdict=", _verdict)
	var packed: PackedScene = load(SCENE)
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if not _fired and _frames >= SETTLE_FRAMES:
		_fire()
		return false
	if _fired and _frames >= SETTLE_FRAMES + AFTER_FRAMES:
		_capture()
		_done = true
	return false


func _fire() -> void:
	var pos := _find_by_script(root, POS_SCRIPT)
	if pos == null:
		push_error("POS 단말을 찾을 수 없다 — 화면 구성이 바뀌었다")
		_done = true
		return
	pos.verdict_chosen.emit(_verdict)
	_fired = true
	print("판정 발사: ", _verdict)


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
