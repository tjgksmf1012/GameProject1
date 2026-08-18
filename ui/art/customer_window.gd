extends Control

## 손님 패널 뒤의 유리창. 인물이 목록 옆 아이콘이 아니라 비 오는 점포 앞 방문자로 읽히게 한다.
## 모든 손님에게 똑같은 환경만 그리므로 판정·이상 여부를 누설하지 않는다.

const Palette := preload("res://ui/theme_factory.gd")

const RAIN_COUNT := 34
const GLASS := Color("0b1417")
const GLASS_TOP := Color("142326")
const FRAME := Color("3a4649")
const FRAME_EDGE := Color("111719")
const STREET := Color("090d0f")
const SODIUM := Color("95602e")
const REFLECTION := Color("6b8284")
const INFO_SHADE := Color(0.025, 0.035, 0.039, 0.88)

var _time := 0.0
var _tension := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 60.0)
	queue_redraw()


func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	_draw_glass()
	_draw_street()
	_draw_door_frame()
	_draw_light()
	_draw_reflections()
	_draw_rain()
	_draw_info_shade()
	_draw_counter_glass()


func _draw_glass() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GLASS)
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.36), GLASS_TOP)
	for i in 5:
		var y := size.y * (0.08 + float(i) * 0.065)
		var alpha := 0.025 + float(i) * 0.008
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.36, 0.48, 0.49, alpha), 2.0)


func _draw_street() -> void:
	var horizon := size.y * 0.62
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), STREET)
	for i in 5:
		var x := size.x * (0.48 + float(i) * 0.13)
		draw_line(Vector2(x, horizon), Vector2(x - size.x * 0.07, size.y),
			Color(0.23, 0.29, 0.30, 0.13), 1.0)
	for i in 4:
		var y := lerpf(horizon, size.y, float(i + 1) / 5.0)
		draw_line(Vector2(size.x * 0.35, y), Vector2(size.x, y),
			Color(0.22, 0.27, 0.28, 0.10), 1.0)


func _draw_door_frame() -> void:
	var post_x := size.x * 0.67
	draw_rect(Rect2(post_x - 5.0, 0.0, 10.0, size.y), FRAME_EDGE)
	draw_rect(Rect2(post_x - 2.0, 0.0, 3.0, size.y), FRAME)
	var transom := size.y * 0.22
	draw_rect(Rect2(post_x, transom - 4.0, size.x - post_x, 8.0), FRAME_EDGE)
	draw_line(Vector2(post_x, transom), Vector2(size.x, transom), FRAME, 2.0)
	draw_rect(Rect2(size.x - 12.0, 0.0, 12.0, size.y), FRAME_EDGE)
	draw_rect(Rect2(size.x * 0.86, size.y * 0.44, 24.0, 4.0), FRAME)


func _draw_light() -> void:
	var flicker := 0.82 + sin(_time * 0.82) * 0.04
	if fposmod(_time, 11.4) > 11.26:
		flicker *= 0.28
	var center := Vector2(size.x * 0.92, size.y * 0.20)
	for radius in [92.0, 58.0, 28.0]:
		var alpha: float = 0.012 + (92.0 - float(radius)) * 0.00023
		draw_circle(center, radius, Color(SODIUM, alpha * flicker))
	draw_circle(center, 4.0, Color(SODIUM.lightened(0.18), 0.78 * flicker))
	draw_line(center + Vector2(0.0, 4.0), center + Vector2(0.0, size.y * 0.38),
		Color(SODIUM, 0.22), 2.0)


func _draw_reflections() -> void:
	draw_polygon(PackedVector2Array([
		Vector2(size.x * 0.72, 0.0), Vector2(size.x * 0.84, 0.0),
		Vector2(size.x * 0.50, size.y), Vector2(size.x * 0.38, size.y),
	]), PackedColorArray([Color(REFLECTION, 0.035)]))
	draw_polygon(PackedVector2Array([
		Vector2(size.x * 0.94, size.y * 0.22), Vector2(size.x, size.y * 0.22),
		Vector2(size.x, size.y), Vector2(size.x * 0.79, size.y),
	]), PackedColorArray([Color(SODIUM, 0.024)]))
	for i in 7:
		var y := size.y * (0.30 + float(i) * 0.075)
		draw_line(Vector2(size.x * 0.70, y), Vector2(size.x * 0.97, y - 8.0),
			Color(REFLECTION, 0.028), 3.0)


func _draw_rain() -> void:
	for i in RAIN_COUNT:
		var x := fposmod(float(i * 71) + _time * 8.0, size.x)
		var speed := 44.0 + float((i * 17) % 38)
		var y := fposmod(float(i * 113) + _time * speed, size.y)
		var length := 7.0 + float(i % 5) * 3.0
		var alpha := 0.13 + _tension * 0.04
		draw_line(Vector2(x, y), Vector2(x - 2.0, y + length),
			Color(0.40, 0.55, 0.57, alpha), 1.0)


func _draw_info_shade() -> void:
	var width := size.x * 0.60
	draw_rect(Rect2(0.0, 0.0, width, size.y), INFO_SHADE)
	draw_polygon(PackedVector2Array([
		Vector2(width, 0.0), Vector2(width + size.x * 0.12, 0.0),
		Vector2(width, size.y), Vector2(width - size.x * 0.08, size.y),
	]), PackedColorArray([Color(INFO_SHADE, 0.42)]))


func _draw_counter_glass() -> void:
	var y := size.y * 0.86
	draw_rect(Rect2(0.0, y, size.x, size.y - y), Color("0b1012"))
	draw_line(Vector2(0.0, y), Vector2(size.x, y), Palette.COUNTER_EDGE, 5.0)
	draw_line(Vector2(0.0, y + 7.0), Vector2(size.x, y + 7.0), FRAME_EDGE, 3.0)
