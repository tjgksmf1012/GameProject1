extends Control

## 카운터 앞 손님을 만드는 절차적 도형.
## 체형과 자세는 오직 손님 ID로 정한다. 판정·anomaly·그림자 특성은 입력조차 받지 않는다.

const Palette := preload("res://ui/theme_factory.gd")
const ProductGlyph := preload("res://ui/art/product_glyph.gd")

const DESIGN_HEIGHT := 150.0
const DESIGN_CENTER_X := 50.0
const FIGURE_FILL := 0.86
const FIGURE_ANCHOR_X := 0.76
const BREATH_PIXELS := 2.6
const BREATH_SECONDS := 4.2
const BREATH_RATE := [1.0, 1.8, 2.8]
const BREATH_DEPTH := [1.0, 1.5, 2.2]
const SHELF_TONE := Color("262d2f")
const OUTLINE := Color("0a0c0d")
const RIM := Color("687173")
## **손님은 실루엣이다. 얼굴이 없다.**
##
## 사람인지 아닌지를 판단해야 하는 게임에서 얼굴이 보이면 판단이 아니라 인상이 된다
## (`docs/art/GPT-BRIEF.md`). 그리고 화면에서 **따뜻한 것은 종이뿐이어야 한다** —
## 살구색 얼굴과 황토색 가방을 넣었더니 손님 패널의 가장 밝은 픽셀이 종이가 아니게 됐다.
## 여기 색은 전부 종이보다 어둡고 차갑다. `tests/test_art_palette.gd`가 매번 잰다.
const BAG_EDGE := Color("4d585b")
const WET_RIM := Color("719096")
## **실루엣은 뒤보다 어두워야 실루엣이다.**
##
## 처음에는 코트가 `#252b2d`(밝기 41)이고 뒤 선반이 `#1d2325`(33)이었다. 손님이
## 배경보다 밝았다는 뜻이고, 그래서 검은 실루엣이 아니라 밝은 마네킹으로 보였다.
## 지금은 코트가 23, 선반이 44다. 손님은 형광등을 등지고 서 있다.
const COAT_TONES := [
	Color("14181a"), Color("15191b"), Color("131718"), Color("161a1c"),
]
const SHOULDER_WIDTH := [20.0, 25.0, 28.0, 23.0]
const WAIST_WIDTH := [14.0, 18.0, 19.0, 16.0]
const HEAD_RADIUS := [9.0, 10.0, 9.5, 11.0]

var _customer_id: String = ""
var _has_bag: bool = false
var _hides_face: bool = false
var _is_wet: bool = false
var _item_key: String = ""
var _variant: int = 0
var _pose: int = 0
var _phase_offset: float = 0.0
var _breath: float = 0.0
var _stage: int = 0
var _item_glyph: ProductGlyph = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_glyph = ProductGlyph.new()
	add_child(_item_glyph)
	_item_glyph.visible = false
	resized.connect(_layout_item)


func show_customer(
	customer_id: String, has_bag: bool, hides_face: bool, is_wet: bool,
	item_keys: PackedStringArray
) -> void:
	_customer_id = customer_id
	_has_bag = has_bag
	_hides_face = hides_face
	_is_wet = is_wet
	_item_key = item_keys[0] if not item_keys.is_empty() else ""
	var seed := _stable_seed(customer_id)
	_variant = seed % COAT_TONES.size()
	_pose = (_stable_seed(customer_id + ":pose") % 3) - 1
	_phase_offset = float(seed % 628) / 100.0
	_item_glyph.set_item_key(_item_key)
	_item_glyph.visible = not _item_key.is_empty()
	queue_redraw()
	_layout_item()


func set_pressure_stage(stage: int) -> void:
	_stage = stage


func _process(delta: float) -> void:
	if _customer_id.is_empty():
		return
	var level := clampi(_stage, 0, BREATH_RATE.size() - 1)
	_breath = fposmod(_breath + delta * float(BREATH_RATE[level]), BREATH_SECONDS)
	queue_redraw()
	_layout_item()


func _draw() -> void:
	if size.y <= 0.0:
		return
	_draw_shelves()
	if _customer_id.is_empty():
		return
	var draw_scale := _figure_scale()
	var origin := _figure_origin(draw_scale) + _motion_offset()
	var tilt := float(_pose) * 0.008 + sin(_phase()) * 0.002
	draw_set_transform(origin, tilt, Vector2.ONE * draw_scale)
	_draw_person()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shelves() -> void:
	for i in 3:
		var left := size.x * (0.05 + float(i) * 0.31)
		var top := size.y * (0.31 + float(i % 2) * 0.08)
		var rect := Rect2(left, top, size.x * 0.21, size.y - top)
		draw_rect(rect, SHELF_TONE)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Palette.PANEL_EDGE, 2.0)
		for row in 3:
			var y := top + (float(row) + 1.0) * rect.size.y / 4.0
			draw_line(Vector2(left, y), Vector2(rect.end.x, y), Color("303739"), 1.0)


func _draw_person() -> void:
	var center := _body_center()
	var shoulder := float(SHOULDER_WIDTH[_variant])
	var waist := float(WAIST_WIDTH[_variant])
	var coat: Color = COAT_TONES[_variant]
	if _has_bag:
		_draw_bag(center, shoulder, coat)
	_draw_legs(center, waist, coat)
	_draw_arms(center, shoulder, coat)
	_draw_torso(center, shoulder, waist, coat)
	if _has_bag:
		_draw_bag_strap(center, shoulder)
	_draw_head(center)
	if _is_wet:
		_draw_wet_overlay(center, shoulder, waist)


func _draw_legs(center: float, waist: float, coat: Color) -> void:
	var left_leg := PackedVector2Array([
		Vector2(center - waist, 105), Vector2(center - 2, 105),
		Vector2(center - 4, 148), Vector2(center - waist - 4, 148),
	])
	var right_leg := PackedVector2Array([
		Vector2(center + 2, 105), Vector2(center + waist, 105),
		Vector2(center + waist + 3, 148), Vector2(center + 4, 148),
	])
	_closed_shape(left_leg, coat)
	_closed_shape(right_leg, coat)


func _draw_torso(center: float, shoulder: float, waist: float, coat: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(center - shoulder, 49), Vector2(center - shoulder - 3, 67),
		Vector2(center - waist - 2, 111), Vector2(center + waist + 2, 111),
		Vector2(center + shoulder + 3, 67), Vector2(center + shoulder, 49),
	])
	_closed_shape(torso, coat)


func _draw_arms(center: float, shoulder: float, coat: Color) -> void:
	var hand_y := _hand_y()
	var left_arm := PackedVector2Array([
		Vector2(center - shoulder + 2, 53), Vector2(center - shoulder - 7, 80),
		Vector2(center - 10, hand_y + 7), Vector2(center - 5, hand_y),
	])
	var right_arm := PackedVector2Array([
		Vector2(center + shoulder - 2, 53), Vector2(center + shoulder + 7, 78),
		Vector2(center + 14, hand_y + 5), Vector2(center + 8, hand_y - 2),
	])
	_closed_shape(left_arm, coat)
	_closed_shape(right_arm, coat)
	draw_circle(Vector2(center - 7, hand_y + 3), 3.1, coat)
	draw_circle(Vector2(center + 11, hand_y + 2), 3.1, coat)


func _draw_head(center: float) -> void:
	var head_center := Vector2(center + float(_pose) * 2.0, 31.0)
	var radius := float(HEAD_RADIUS[_variant])
	var coat: Color = COAT_TONES[_variant]
	draw_rect(Rect2(head_center.x - 4, 38, 8, 13), coat)
	if _hides_face:
		_draw_hidden_face(head_center, radius)
		return
	# 형광등을 등지고 서 있다. 몸과 **같은 색**으로 채우고 왼쪽 위만 빛이 스친다.
	# 테두리를 한 바퀴 두르면 머리가 아니라 도넛으로 읽힌다 — 실제로 그렇게 보였다.
	draw_circle(head_center, radius, coat)
	draw_arc(head_center, radius, PI * 1.05, PI * 1.75, 14, RIM.darkened(0.58), 1.2, true)


func _draw_hidden_face(center: Vector2, radius: float) -> void:
	var hood := PackedVector2Array([
		center + Vector2(-radius - 4, 4), center + Vector2(-radius, -7),
		center + Vector2(0, -radius - 5), center + Vector2(radius, -7),
		center + Vector2(radius + 4, 4), center + Vector2(radius - 1, 13),
		center + Vector2(-radius + 1, 13),
	])
	_closed_shape(hood, Color("171b1c"), RIM.darkened(0.40))
	draw_circle(center + Vector2(0, 2), radius * 0.72, Color("050607"))
	draw_arc(center + Vector2(0, 2), radius * 0.75, 0.0, TAU, 20, Color("333a3c"), 1.0, true)


## 실루엣에서 가방은 **윤곽의 혹**이다.
##
## 처음에는 몸 옆에 따로 떠 있었다 — 팔이 사이를 가려서 몸에서 떨어진 정체불명의 도형으로
## 보였고, 채도를 낮추자 이번엔 열린 「C」자 테두리만 남았다. 지금은 몸과 **같은 색으로**
## 어깨에 붙여 실루엣을 한 덩어리로 만들고, 어깨를 가로지르는 끈만 빛을 받는다.
## 끈은 몸통 **뒤에** 그리면 안 보이므로 몸통 다음에 따로 그린다.
func _draw_bag(center: float, shoulder: float, coat: Color) -> void:
	var bag_shape := PackedVector2Array([
		Vector2(center - shoulder - 1, 57), Vector2(center - shoulder + 7, 55),
		Vector2(center - shoulder + 7, 97), Vector2(center - shoulder - 3, 96),
		Vector2(center - shoulder - 15, 89), Vector2(center - shoulder - 14, 66),
	])
	_closed_shape(bag_shape, coat)


func _draw_bag_strap(center: float, shoulder: float) -> void:
	draw_line(
		Vector2(center + shoulder * 0.30, 51), Vector2(center - shoulder + 1, 84),
		BAG_EDGE.darkened(0.30), 2.4, true)


func _draw_wet_overlay(center: float, shoulder: float, waist: float) -> void:
	draw_line(Vector2(center - shoulder + 2, 51), Vector2(center - waist, 102), WET_RIM, 1.2)
	draw_line(Vector2(center + shoulder - 2, 51), Vector2(center + waist - 2, 100), WET_RIM, 1.2)
	for i in 4:
		var x := center - 12.0 + float(i) * 8.0
		var y := 58.0 + float((i * 11) % 17)
		draw_line(Vector2(x, y), Vector2(x - 1, y + 9), WET_RIM.darkened(0.15), 1.0)
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(center + side * (shoulder + 3.0), 61), 1.4, WET_RIM)
		draw_line(Vector2(center + side * (shoulder + 3.0), 63), Vector2(center + side * (shoulder + 3.0), 68), WET_RIM, 1.0)


func _closed_shape(
	points: PackedVector2Array, fill: Color, edge: Color = OUTLINE
) -> void:
	draw_colored_polygon(points, fill)
	var closed := points + PackedVector2Array([points[0]])
	draw_polyline(closed, edge, 1.2, true)


func _layout_item() -> void:
	if _item_glyph == null or not _item_glyph.visible or size.y <= 0.0:
		return
	var draw_scale := _figure_scale()
	var glyph_scale := draw_scale * 0.72
	# 가슴 한가운데에 놓으면 몸에 박혀 보인다. 손이 그려지는 자리와 같은 값을 봐야 한다.
	var point := Vector2(_body_center() + 12.0, _hand_y() + 2.0) * draw_scale
	_item_glyph.scale = Vector2.ONE * glyph_scale
	_item_glyph.rotation = float(_pose) * 0.008
	_item_glyph.position = _figure_origin(draw_scale) + _motion_offset() + point \
		- Vector2.ONE * 16.0 * glyph_scale


func _figure_scale() -> float:
	return size.y * FIGURE_FILL / DESIGN_HEIGHT


func _figure_origin(draw_scale: float) -> Vector2:
	return Vector2(
		size.x * FIGURE_ANCHOR_X - DESIGN_CENTER_X * draw_scale,
		size.y - DESIGN_HEIGHT * draw_scale)


## 손이 그려지는 높이. `_draw_arms`와 `_layout_item`이 **같은 값**을 봐야
## 품목이 손에 놓인다. 예전에는 각자 상수를 들고 있어서 물건이 가슴에 박혔다.
func _hand_y() -> float:
	return 91.0 + float(_pose) * 2.0


func _body_center() -> float:
	return DESIGN_CENTER_X + float(_pose) * 1.5


func _phase() -> float:
	return _breath / BREATH_SECONDS * TAU + _phase_offset


func _motion_offset() -> Vector2:
	var level := clampi(_stage, 0, BREATH_DEPTH.size() - 1)
	var phase := sin(_phase())
	return Vector2(phase * 0.25, phase * BREATH_PIXELS * float(BREATH_DEPTH[level]))


static func _stable_seed(value: String) -> int:
	var seed: int = 5381
	for i in value.length():
		seed = int((seed * 33 + value.unicode_at(i)) % 2147483647)
	return seed
