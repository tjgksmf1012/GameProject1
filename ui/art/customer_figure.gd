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
const SHELF_TONE := Color("1d2325")
const OUTLINE := Color("0a0c0d")
const RIM := Color("687173")
const SKIN := Color("625850")
const BAG := Color("504936")
const BAG_EDGE := Color("8b7b57")
const WET_RIM := Color("719096")
const COAT_TONES := [
	Color("252b2d"), Color("2c2b29"), Color("242c2a"), Color("2d292c"),
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
		_draw_bag(center, shoulder)
	_draw_legs(center, waist, coat)
	_draw_arms(center, shoulder, coat)
	_draw_torso(center, shoulder, waist, coat)
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
	_closed_shape(left_leg, coat.darkened(0.24))
	_closed_shape(right_leg, coat.darkened(0.18))
	draw_line(Vector2(center - waist - 5, 148), Vector2(center - 3, 148), RIM.darkened(0.45), 2.0)
	draw_line(Vector2(center + 3, 148), Vector2(center + waist + 5, 148), RIM.darkened(0.45), 2.0)


func _draw_torso(center: float, shoulder: float, waist: float, coat: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(center - shoulder, 49), Vector2(center - shoulder - 3, 67),
		Vector2(center - waist - 2, 111), Vector2(center + waist + 2, 111),
		Vector2(center + shoulder + 3, 67), Vector2(center + shoulder, 49),
	])
	_closed_shape(torso, coat)
	draw_line(Vector2(center, 52), Vector2(center, 108), RIM.darkened(0.42), 1.0)
	draw_line(Vector2(center - waist, 105), Vector2(center + waist, 105), RIM.darkened(0.52), 1.0)


func _draw_arms(center: float, shoulder: float, coat: Color) -> void:
	var hand_y := 91.0 + float(_pose) * 2.0
	var left_arm := PackedVector2Array([
		Vector2(center - shoulder + 2, 53), Vector2(center - shoulder - 7, 80),
		Vector2(center - 10, hand_y + 7), Vector2(center - 5, hand_y),
	])
	var right_arm := PackedVector2Array([
		Vector2(center + shoulder - 2, 53), Vector2(center + shoulder + 7, 78),
		Vector2(center + 14, hand_y + 5), Vector2(center + 8, hand_y - 2),
	])
	_closed_shape(left_arm, coat.darkened(0.08))
	_closed_shape(right_arm, coat.lightened(0.03))
	draw_circle(Vector2(center - 7, hand_y + 3), 3.1, SKIN)
	draw_circle(Vector2(center + 11, hand_y + 2), 3.1, SKIN)


func _draw_head(center: float) -> void:
	var head_center := Vector2(center + float(_pose) * 2.0, 31.0)
	var radius := float(HEAD_RADIUS[_variant])
	draw_rect(Rect2(head_center.x - 4, 39, 8, 12), SKIN.darkened(0.16))
	if _hides_face:
		_draw_hidden_face(head_center, radius)
		return
	draw_circle(head_center, radius, SKIN)
	draw_arc(head_center, radius, 0.0, TAU, 24, OUTLINE, 1.2, true)
	draw_arc(head_center + Vector2(0, -2), radius * 0.92, PI, TAU, 16, Color("17191a"), 5.0, true)
	draw_line(head_center + Vector2(2, 0), head_center + Vector2(4, 4), RIM.darkened(0.35), 1.0)


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


func _draw_bag(center: float, shoulder: float) -> void:
	var bag_shape := PackedVector2Array([
		Vector2(center - shoulder - 11, 55), Vector2(center - shoulder - 4, 50),
		Vector2(center - shoulder + 1, 62), Vector2(center - shoulder - 1, 93),
		Vector2(center - shoulder - 17, 92), Vector2(center - shoulder - 20, 67),
	])
	_closed_shape(bag_shape, BAG, BAG_EDGE.darkened(0.25))
	draw_arc(Vector2(center - shoulder - 8, 60), 10.0, PI * 0.84, TAU * 0.93, 14, BAG_EDGE, 1.8, true)
	draw_line(Vector2(center - shoulder - 16, 75), Vector2(center - shoulder - 2, 75), BAG_EDGE.darkened(0.2), 1.0)


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
	var point := Vector2(_body_center() + 2.0, 89.0) * draw_scale
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
