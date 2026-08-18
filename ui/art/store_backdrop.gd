extends Control

## 제목 화면의 편의점 외관. 메뉴 뒤의 빈 배경이 아니라 첫 스크린샷의 사건 장소다.
## 실존 상표·이미지 없이 유리, 형광등, 비, 반사와 문 뒤 인기척만 코드로 그린다.

const Palette := preload("res://ui/theme_factory.gd")

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const STORE := Rect2(62.0, 82.0, 1156.0, 482.0)
const GLASS_Y := 246.0
const GROUND_Y := 564.0
const RAIN_COUNT := 76
const REFLECTION_COUNT := 14

const SKY := Color("080c0f")
const WALL := Color("151b1d")
const WALL_LIT := Color("263033")
const FRAME := Color("536063")
const GLASS := Color("0b171a")
const GLASS_LIT := Color("193035")
const FLOOR := Color("090d0f")
const FLUORESCENT := Color("a4b3af")
const SODIUM := Color("d17f31")
const SIGN_DARK := Color("111719")
const SILHOUETTE := Color("050708")

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 40.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN_SIZE)
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), SKY)
	_draw_distant_city()
	_draw_store_shell()
	_draw_windows()
	_draw_sign()
	_draw_interior()
	_draw_visitor()
	_draw_foreground()
	_draw_rain()


func _draw_distant_city() -> void:
	for i in 9:
		var width := 58.0 + float((i * 17) % 54)
		var height := 92.0 + float((i * 43) % 118)
		var x := float(i) * 154.0 - 34.0
		draw_rect(Rect2(x, GROUND_Y - height, width, height), Color(0.04, 0.06, 0.07, 0.80))
		for window in 3:
			var y := GROUND_Y - height + 24.0 + float(window) * 28.0
			draw_rect(Rect2(x + 13.0, y, 9.0, 4.0), Color(0.29, 0.31, 0.27, 0.10))


func _draw_store_shell() -> void:
	draw_rect(STORE, WALL)
	draw_rect(Rect2(STORE.position, Vector2(STORE.size.x, 26.0)), WALL_LIT)
	draw_rect(Rect2(40.0, 66.0, 1200.0, 22.0), Color("090d0e"))
	draw_line(Vector2(40.0, 88.0), Vector2(1240.0, 88.0), FRAME.darkened(0.38), 5.0)
	for x in [82.0, 1198.0]:
		draw_rect(Rect2(x, 108.0, 12.0, 456.0), Color("0b1012"))
		draw_line(Vector2(x + 4.0, 112.0), Vector2(x + 4.0, 556.0), FRAME.darkened(0.42), 2.0)
	_draw_awning_lights()


func _draw_awning_lights() -> void:
	var pulse := 0.88 + sin(_time * 0.74) * 0.035
	for x in [138.0, 448.0, 758.0, 1032.0]:
		draw_polygon(PackedVector2Array([
			Vector2(x, 103.0), Vector2(x + 216.0, 103.0),
			Vector2(x + 194.0, 122.0), Vector2(x + 18.0, 122.0),
		]), PackedColorArray([Color(FLUORESCENT, 0.24 * pulse)]))
		draw_line(Vector2(x + 20.0, 124.0), Vector2(x + 192.0, 124.0),
			Color(FLUORESCENT, 0.12 * pulse), 7.0)


func _draw_windows() -> void:
	var glass := Rect2(92.0, GLASS_Y, 1096.0, GROUND_Y - GLASS_Y)
	draw_rect(glass, GLASS)
	draw_rect(Rect2(96.0, GLASS_Y + 5.0, 1088.0, 96.0), GLASS_LIT)
	for x in [92.0, 334.0, 576.0, 818.0, 988.0, 1188.0]:
		draw_line(Vector2(x, GLASS_Y), Vector2(x, GROUND_Y), FRAME.darkened(0.30), 5.0)
	draw_line(Vector2(92.0, 398.0), Vector2(1188.0, 398.0), FRAME.darkened(0.43), 3.0)
	_draw_door()
	_draw_glass_reflections()


func _draw_door() -> void:
	var door := Rect2(988.0, GLASS_Y, 200.0, GROUND_Y - GLASS_Y)
	draw_rect(door, Color("091316"))
	draw_rect(door, FRAME.darkened(0.28), false, 6.0)
	draw_line(Vector2(1088.0, GLASS_Y), Vector2(1088.0, GROUND_Y), FRAME.darkened(0.30), 3.0)
	draw_rect(Rect2(1069.0, 401.0, 38.0, 6.0), FRAME.darkened(0.10))
	draw_rect(Rect2(1112.0, 414.0, 5.0, 48.0), SODIUM.darkened(0.28))


func _draw_glass_reflections() -> void:
	draw_polygon(PackedVector2Array([
		Vector2(120.0, GLASS_Y), Vector2(296.0, GLASS_Y),
		Vector2(478.0, GROUND_Y), Vector2(344.0, GROUND_Y),
	]), PackedColorArray([Color(FLUORESCENT, 0.035)]))
	draw_polygon(PackedVector2Array([
		Vector2(758.0, GLASS_Y), Vector2(842.0, GLASS_Y),
		Vector2(714.0, GROUND_Y), Vector2(630.0, GROUND_Y),
	]), PackedColorArray([Color(FLUORESCENT, 0.025)]))
	for i in 11:
		var x := 114.0 + float((i * 97) % 1012)
		var y := 278.0 + float((i * 47) % 244)
		draw_line(Vector2(x, y), Vector2(x - 2.0, y + 16.0), Color(0.48, 0.62, 0.64, 0.18), 1.2)


func _draw_sign() -> void:
	var sign := Rect2(270.0, 138.0, 740.0, 130.0)
	draw_rect(sign.grow(12.0), Color("080b0c"))
	draw_rect(sign, SIGN_DARK)
	draw_rect(sign, FRAME.darkened(0.25), false, 3.0)
	var glow := 0.045 + sin(_time * 1.3) * 0.008
	draw_rect(sign.grow(18.0), Color(FLUORESCENT, glow), false, 12.0)
	draw_line(Vector2(304.0, 257.0), Vector2(976.0, 257.0), Color(SODIUM, 0.24), 3.0)


func _draw_interior() -> void:
	for bank in 3:
		var x := 112.0 + float(bank) * 282.0
		var rect := Rect2(x, 330.0, 222.0, 190.0)
		draw_rect(rect, Color("11191b"))
		for row in 4:
			var y := rect.position.y + 32.0 + float(row) * 42.0
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), FRAME.darkened(0.48), 3.0)
			_draw_product_blocks(rect.position.x + 8.0, y - 24.0, bank + row)
	draw_rect(Rect2(738.0, 454.0, 246.0, 68.0), Color("121719"))
	draw_line(Vector2(730.0, 454.0), Vector2(988.0, 454.0), FRAME.darkened(0.30), 5.0)


func _draw_product_blocks(start_x: float, y: float, seed: int) -> void:
	for i in 8:
		var height := 13.0 + float((i * 7 + seed * 11) % 12)
		var tone := 0.17 + float((i + seed) % 3) * 0.025
		draw_rect(Rect2(start_x + float(i) * 25.0, y + 20.0 - height, 17.0, height),
			Color(tone, tone * 1.08, tone * 1.05, 0.86))


func _draw_visitor() -> void:
	var sway := sin(_time * 0.66) * 1.2
	var center := Vector2(1070.0 + sway, 419.0)
	draw_circle(center + Vector2(0.0, -71.0), 21.0, SILHOUETTE)
	draw_polygon(PackedVector2Array([
		center + Vector2(-29.0, -52.0), center + Vector2(21.0, -55.0),
		center + Vector2(39.0, 54.0), center + Vector2(-35.0, 54.0),
	]), PackedColorArray([SILHOUETTE]))
	draw_line(center + Vector2(18.0, -21.0), center + Vector2(48.0, 4.0),
		Color("12191a"), 8.0, true)
	draw_circle(center + Vector2(48.0, 4.0), 5.0, Color("12191a"))
	draw_line(center + Vector2(-25.0, -43.0), center + Vector2(-19.0, 51.0),
		Color(FRAME, 0.22), 2.0)


func _draw_foreground() -> void:
	draw_rect(Rect2(0.0, GROUND_Y, 1280.0, 156.0), FLOOR)
	draw_line(Vector2(0.0, GROUND_Y), Vector2(1280.0, GROUND_Y), Color("30393b"), 5.0)
	for i in REFLECTION_COUNT:
		var x := 50.0 + float((i * 109) % 1180)
		var width := 28.0 + float((i * 23) % 96)
		var color := Color(SODIUM, 0.035) if i % 4 == 0 else Color(FLUORESCENT, 0.025)
		draw_polygon(PackedVector2Array([
			Vector2(x, GROUND_Y + 8.0), Vector2(x + width, GROUND_Y + 8.0),
			Vector2(x + width * 0.68, 710.0), Vector2(x + width * 0.24, 710.0),
		]), PackedColorArray([color]))


func _draw_rain() -> void:
	for i in RAIN_COUNT:
		var speed := 90.0 + float((i * 23) % 84)
		var x := fposmod(float(i * 83) + _time * 15.0, DESIGN_SIZE.x)
		var y := fposmod(float(i * 137) + _time * speed, DESIGN_SIZE.y)
		var length := 10.0 + float(i % 5) * 4.0
		draw_line(Vector2(x, y), Vector2(x - 4.0, y + length),
			Color(0.46, 0.59, 0.61, 0.16), 1.0)
