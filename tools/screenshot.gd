extends SceneTree

## 특정 상태를 렌더해 PNG로 저장한다 (CLAUDE.md 3절 — "너는 실행 화면을 볼 수 없다").
##
##   xvfb-run -a godot --path . --script res://tools/screenshot.gd -- \
##       --scene=res://main/night_screen.tscn --out=/tmp/shot.png --frames=40
##
## 시각 변경은 반드시 이걸로 확인한다. 추측해서 진행하지 않는다.

const DEFAULT_SCENE := "res://main/night_screen.tscn"
const DEFAULT_OUT := "user://screenshot.png"
const DEFAULT_FRAMES := 40

var _frames_waited: int = 0
var _frames_needed: int = DEFAULT_FRAMES
var _out_path: String = DEFAULT_OUT
var _done: bool = false


func _initialize() -> void:
	var scene_path := _arg("--scene=", DEFAULT_SCENE)
	_out_path = _arg("--out=", DEFAULT_OUT)
	_frames_needed = int(_arg("--frames=", str(DEFAULT_FRAMES)))
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("씬을 열 수 없다: %s" % scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames_waited += 1
	if _frames_waited < _frames_needed:
		return false
	_capture()
	_done = true
	return true


func _capture() -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("뷰포트를 읽을 수 없다")
		return
	var error := image.save_png(_out_path)
	if error != OK:
		push_error("PNG 저장 실패(%d): %s" % [error, _out_path])
		return
	print("저장됨: ", ProjectSettings.globalize_path(_out_path))
	print("크기: %d x %d" % [image.get_width(), image.get_height()])


static func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
