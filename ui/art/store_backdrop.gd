extends Control

## 제목 화면 뒤의 편의점. 이미지 대신 선·면·빛만으로 한 공간을 만든다.
## 중앙은 글자를 위해 비우고, 가장자리의 선반과 유리문이 장소를 설명한다.

const Palette := preload("res://ui/theme_factory.gd")

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const HORIZON_Y := 430.0
const RAIN_COUNT := 42
const PRODUCT_ROWS := 4

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, 20.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN_SIZE)
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Palette.BG)
	_draw_ceiling()
	_draw_floor()
	_draw_shelves()
	_draw_entrance()
	_draw_sign_backing()
	_draw_counter()
	_draw_reading_well()


func _draw_ceiling() -> void:
	var cold := Color(0.19, 0.25, 0.25, _light_alpha())
	draw_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1110, 150), Vector2(170, 150),
	]), PackedColorArray([Color("101516")]))
	for x in [205.0, 530.0, 855.0]:
		draw_polygon(PackedVector2Array([
			Vector2(x, 48), Vector2(x + 220, 48),
			Vector2(x + 194, 72), Vector2(x + 24, 72),
		]), PackedColorArray([cold]))
		draw_line(Vector2(x + 24, 75), Vector2(x + 194, 75), Color(0.4, 0.5, 0.49, 0.10), 5.0)


func _draw_floor() -> void:
	draw_rect(Rect2(0, HORIZON_Y, 1280, 290), Color("0a0d0d"))
	for x in range(0, 1281, 128):
		draw_line(Vector2(640, HORIZON_Y), Vector2(float(x), 720), Color(0.20, 0.25, 0.24, 0.12), 1.0)
	for y in [474.0, 523.0, 579.0, 644.0]:
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.20, 0.25, 0.24, 0.10), 1.0)
	var reflection := Color(0.20, 0.29, 0.28, 0.035 * _light_alpha())
	draw_polygon(PackedVector2Array([
		Vector2(390, HORIZON_Y), Vector2(890, HORIZON_Y),
		Vector2(1040, 720), Vector2(240, 720),
	]), PackedColorArray([reflection]))


func _draw_shelves() -> void:
	_draw_shelf_bank(Rect2(22, 155, 270, 330), false)
	_draw_shelf_bank(Rect2(988, 164, 250, 290), true)


func _draw_shelf_bank(rect: Rect2, right_side: bool) -> void:
	draw_rect(rect, Color(0.055, 0.072, 0.073, 0.96))
	draw_rect(rect, Color(0.22, 0.27, 0.27, 0.28), false, 2.0)
	var row_h := rect.size.y / float(PRODUCT_ROWS)
	for row in PRODUCT_ROWS:
		var y := rect.position.y + float(row + 1) * row_h
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.33, 0.37, 0.36, 0.24), 3.0)
		_draw_product_row(rect, row, right_side)


func _draw_product_row(rect: Rect2, row: int, right_side: bool) -> void:
	var cell_w := rect.size.x / 9.0
	var base_y := rect.position.y + float(row) * rect.size.y / float(PRODUCT_ROWS)
	for i in 8:
		var h := 25.0 + float((i * 7 + row * 11) % 24)
		var x := rect.position.x + 8.0 + float(i) * cell_w
		var tint := 0.10 + float((i + row) % 3) * 0.025
		if right_side:
			tint *= 0.82
		draw_rect(Rect2(x, base_y + 58.0 - h, cell_w - 6.0, h), Color(tint, tint * 1.08, tint * 1.03, 0.82))


func _draw_entrance() -> void:
	var frame := Rect2(924, 118, 274, 405)
	draw_rect(frame, Color(0.025, 0.040, 0.043, 0.96))
	draw_rect(frame, Color(0.27, 0.32, 0.31, 0.42), false, 5.0)
	draw_line(Vector2(1061, 118), Vector2(1061, 523), Color(0.31, 0.36, 0.35, 0.40), 4.0)
	draw_line(Vector2(924, 370), Vector2(1198, 370), Color(0.24, 0.29, 0.29, 0.35), 3.0)
	_draw_sodium_light()
	_draw_rain(frame.grow(-8.0))
	draw_polygon(PackedVector2Array([
		Vector2(938, 523), Vector2(1184, 523), Vector2(1235, 685), Vector2(875, 685),
	]), PackedColorArray([Color(0.17, 0.20, 0.19, 0.12)]))


func _draw_sodium_light() -> void:
	var glow := 0.55 + sin(_time * 0.43) * 0.04
	draw_circle(Vector2(1152, 205), 34.0, Color(0.75, 0.40, 0.13, 0.035 * glow))
	draw_circle(Vector2(1152, 205), 7.0, Color(0.90, 0.56, 0.22, 0.72 * glow))
	draw_line(Vector2(1152, 212), Vector2(1152, 355), Color(0.31, 0.24, 0.16, 0.40), 3.0)


func _draw_rain(window: Rect2) -> void:
	for i in RAIN_COUNT:
		var seed := float((i * 47 + 13) % 101) / 101.0
		var speed := 54.0 + float((i * 17) % 44)
		var x := window.position.x + fmod(seed * window.size.x + _time * 9.0, window.size.x)
		var y := window.position.y + fmod(seed * 397.0 + _time * speed, window.size.y)
		var length := 7.0 + float(i % 5) * 3.0
		if y + length < window.end.y:
			draw_line(Vector2(x, y), Vector2(x - 2.0, y + length), Color(0.45, 0.58, 0.58, 0.20), 1.0)


func _draw_sign_backing() -> void:
	var sign := Rect2(332, 150, 616, 148)
	draw_rect(sign, Color(0.025, 0.032, 0.033, 0.92))
	draw_rect(sign, Color(0.26, 0.31, 0.30, 0.40), false, 2.0)
	draw_line(Vector2(367, 298), Vector2(913, 298), Color(0.54, 0.61, 0.58, 0.08 * _light_alpha()), 7.0)


func _draw_counter() -> void:
	draw_polygon(PackedVector2Array([
		Vector2(0, 608), Vector2(1280, 608), Vector2(1280, 720), Vector2(0, 720),
	]), PackedColorArray([Color("111514")]))
	draw_line(Vector2(0, 608), Vector2(1280, 608), Color(0.28, 0.32, 0.30, 0.50), 5.0)
	draw_line(Vector2(0, 622), Vector2(1280, 622), Color(0.03, 0.04, 0.04, 0.90), 12.0)


func _draw_reading_well() -> void:
	# 화면 중앙의 두 문장이 배경 선과 싸우지 않게 하는 아주 약한 광학 암실.
	draw_circle(Vector2(640, 365), 315.0, Color(0.0, 0.0, 0.0, 0.23))


func _light_alpha() -> float:
	var phase := fmod(_time, 8.7)
	if phase > 8.56:
		return 0.25
	if phase > 8.42:
		return 0.72
	return 0.92 + sin(_time * 1.7) * 0.025
