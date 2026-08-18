extends Control

## 결과 패널의 물리적 도장 자국. 판정이 끝난 뒤에만 보이므로 새 정보를 누설하지 않는다.

const Palette := preload("res://ui/theme_factory.gd")

var _correct := true
var _shown := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func show_decision(correct: bool) -> void:
	_correct = correct
	_shown = true
	queue_redraw()


func clear() -> void:
	_shown = false
	queue_redraw()


func _draw() -> void:
	if not _shown or size.x < 120.0 or size.y < 80.0:
		return
	var center := Vector2(size.x - 238.0, size.y * 0.52)
	var color := Color(Palette.OK if _correct else Palette.DANGER, 0.18)
	draw_set_transform(center, -0.13, Vector2.ONE)
	draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 48, color, 5.0, true)
	draw_arc(Vector2.ZERO, 39.0, 0.0, TAU, 48, color, 2.0, true)
	if _correct:
		draw_polyline(PackedVector2Array([
			Vector2(-23.0, 0.0), Vector2(-6.0, 18.0), Vector2(26.0, -19.0),
		]), color, 8.0, true)
	else:
		draw_line(Vector2(-22.0, -22.0), Vector2(22.0, 22.0), color, 8.0, true)
		draw_line(Vector2(22.0, -22.0), Vector2(-22.0, 22.0), color, 8.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
