extends Control

## 밤 화면의 네 기능을 같은 계산대에 고정하는 금속 프레임.
## 좁은 여백과 패널 사이 틈도 빈 UI 공간이 아니라 실제 장치의 이음새로 읽히게 한다.

const Palette := preload("res://ui/theme_factory.gd")

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const METAL := Color("1a2224")
const METAL_EDGE := Color("3c484a")
const VOID := Color("070a0b")
const CABLE := Color("090d0e")
const LAMP := Color("708482")
const SODIUM := Color("865527")

var _time := 0.0
var _tension := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 30.0)
	queue_redraw()


func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN_SIZE)
	_draw_ceiling_rig()
	_draw_side_posts()
	_draw_cable_tray()
	_draw_counter_body()
	_draw_bolts()


func _draw_ceiling_rig() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 18.0), VOID)
	draw_rect(Rect2(0.0, 18.0, 1280.0, 9.0), METAL)
	draw_line(Vector2(0.0, 27.0), Vector2(1280.0, 27.0), METAL_EDGE, 2.0)
	var strength := 0.13 + (1.0 - _tension) * 0.06
	if fposmod(_time, 9.7) > 9.58:
		strength *= 0.2
	for x in [166.0, 492.0, 818.0]:
		draw_polygon(PackedVector2Array([
			Vector2(x, 28.0), Vector2(x + 244.0, 28.0),
			Vector2(x + 214.0, 47.0), Vector2(x + 25.0, 47.0),
		]), PackedColorArray([Color(LAMP, strength)]))
		draw_line(Vector2(x + 26.0, 50.0), Vector2(x + 213.0, 50.0),
			Color(LAMP, strength * 0.62), 6.0)


func _draw_side_posts() -> void:
	for x in [0.0, 1262.0]:
		draw_rect(Rect2(x, 26.0, 18.0, 694.0), METAL)
		var edge_x: float = float(x) + 17.0 if float(x) < 100.0 else float(x)
		draw_line(Vector2(edge_x, 28.0), Vector2(edge_x, 720.0), METAL_EDGE.darkened(0.18), 2.0)
	for y in [86.0, 492.0, 704.0]:
		draw_rect(Rect2(16.0, y, 1248.0, 8.0), VOID)
		draw_line(Vector2(18.0, y), Vector2(1262.0, y), METAL_EDGE.darkened(0.30), 1.0)


func _draw_cable_tray() -> void:
	draw_line(Vector2(20.0, 492.0), Vector2(1260.0, 492.0), CABLE, 12.0)
	for x in [438.0, 802.0, 905.0]:
		draw_line(Vector2(x, 78.0), Vector2(x, 493.0), CABLE, 6.0)
		draw_line(Vector2(x + 6.0, 78.0), Vector2(x + 6.0, 493.0), METAL_EDGE.darkened(0.50), 2.0)
	for i in 5:
		var x := 46.0 + float(i) * 247.0
		draw_arc(Vector2(x, 507.0), 13.0, 0.0, PI, 12, CABLE, 4.0, true)


func _draw_counter_body() -> void:
	draw_rect(Rect2(0.0, 494.0, 1280.0, 226.0), Palette.COUNTER.darkened(0.18))
	draw_rect(Rect2(0.0, 494.0, 1280.0, 13.0), Palette.COUNTER_EDGE)
	draw_line(Vector2(0.0, 507.0), Vector2(1280.0, 507.0), VOID, 4.0)
	for x in [26.0, 440.0, 848.0, 1254.0]:
		draw_line(Vector2(x, 520.0), Vector2(x, 718.0), METAL_EDGE.darkened(0.47), 2.0)
	var spill := 0.025 + sin(_time * 0.4) * 0.004
	draw_polygon(PackedVector2Array([
		Vector2(974.0, 494.0), Vector2(1250.0, 494.0),
		Vector2(1280.0, 720.0), Vector2(1082.0, 720.0),
	]), PackedColorArray([Color(SODIUM, spill)]))


func _draw_bolts() -> void:
	for point in [
		Vector2(10.0, 74.0), Vector2(1270.0, 74.0),
		Vector2(10.0, 486.0), Vector2(1270.0, 486.0),
		Vector2(10.0, 694.0), Vector2(1270.0, 694.0),
	]:
		draw_circle(point, 4.0, VOID)
		draw_circle(point, 2.0, METAL_EDGE)
