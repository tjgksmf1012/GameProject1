extends Control

## 카운터 앞 손님. **얼굴 없는 검은 실루엣이다** (`docs/art/GPT-BRIEF.md`).
##
## 사람인지 아닌지를 판단해야 하는 게임에서 얼굴이 보이면 판단이 아니라 인상이 된다.
## 스토어 캡슐 다섯 장도 전부 실루엣이므로 여기가 달라지면 광고가 거짓이 된다.
##
## 체형과 자세는 **오직 손님 ID로** 정한다. 판정·anomaly·그림자는 입력조차 받지 않는다 —
## 도형이 정답을 흘리면 CCTV도 클립보드도 필요 없어진다.
##
## 윤곽 자체는 `figure_outline.gd`가 소유한다. 비율이 틀리면 색을 아무리 고쳐도
## 어린이 그림으로 보이고, 비율은 노드 없이 검사할 수 있다.

const Palette := preload("res://ui/theme_factory.gd")
const ProductGlyph := preload("res://ui/art/product_glyph.gd")
const Outline := preload("res://ui/art/figure_outline.gd")

const FIGURE_FILL := 0.90
const FIGURE_ANCHOR_X := 0.76
const BREATH_PIXELS := 2.4
const BREATH_SECONDS := 4.2
const BREATH_RATE := [1.0, 1.8, 2.8]
const BREATH_DEPTH := [1.0, 1.5, 2.2]
const OUTLINE_WIDTH := 2.2

## **실루엣은 뒤보다 어두워야 실루엣이다.** 코트가 선반보다 밝았을 때는 검은 실루엣이
## 아니라 밝은 마네킹으로 보였다. 지금 코트는 밝기 23, 선반은 44다.
## 그리고 화면에서 따뜻한 것은 종이뿐이어야 한다 — `tests/test_art_palette.gd`가 잰다.
const SHELF_TONE := Color("262d2f")
const SHELF_LINE := Color("303739")
## 제한 팔레트에서 실루엣이 선반에 녹지 않도록 배경보다 밝은 차가운 윤곽을 쓴다.
const EDGE := Color("3d4648")
const RIM := Color("687173")
const STRAP := Color("4d585b")
const WET_RIM := Color("719096")
const HOOD_VOID := Color("050607")
const COAT_TONES := [
	Color("14181a"), Color("15191b"), Color("131718"), Color("161a1c"),
]
const SHOULDER_WIDTH := [21.0, 24.0, 26.0, 22.5]
const WAIST_WIDTH := [16.0, 18.0, 19.0, 17.0]
const HEAD_RADIUS := [9.6, 10.4, 10.0, 10.8]

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
	var tilt := float(_pose) * 0.008 + sin(_phase()) * 0.002
	draw_set_transform(_figure_origin(draw_scale) + _motion_offset(), tilt, Vector2.ONE * draw_scale)
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
			draw_line(Vector2(left, y), Vector2(rect.end.x, y), SHELF_LINE, 1.0)


## 그리는 순서가 곧 겹치는 순서다. 다리 → 가방 → 몸통 → 끈 → 머리.
## 끈은 몸통 **뒤에** 그리면 안 보이고, 가방은 몸통 뒤라야 혹으로 붙는다.
func _draw_person() -> void:
	var coat: Color = COAT_TONES[_variant]
	var shoulder := float(SHOULDER_WIDTH[_variant])
	var waist := float(WAIST_WIDTH[_variant])
	for side in [-1.0, 1.0]:
		_fill(Outline.leg(side, waist), coat)
	if _has_bag:
		_fill(Outline.bag(shoulder), coat)
	_fill(Outline.silhouette(shoulder, waist), coat)
	if _has_bag:
		_draw_strap(shoulder)
	_draw_head(coat)
	if _is_wet:
		_draw_wet(shoulder)


func _draw_strap(shoulder: float) -> void:
	var line := Outline.strap(shoulder)
	draw_line(_at(line[0]), _at(line[1]), STRAP.darkened(0.30), 2.2, true)


## 머리도 몸과 **같은 색**이다. 테두리를 한 바퀴 두르면 도넛으로 읽힌다 —
## 실제로 그렇게 보였다. 형광등을 등지고 있으니 왼쪽 위만 빛이 스친다.
func _draw_head(coat: Color) -> void:
	var radius := float(HEAD_RADIUS[_variant])
	if _hides_face:
		_fill(Outline.hood(radius), coat)
		draw_circle(_at(Vector2(0.0, Outline.HEAD_CENTER_Y + 2.0)), radius * 0.66, HOOD_VOID)
		return
	var center := _at(Vector2(0.0, Outline.HEAD_CENTER_Y))
	draw_circle(center, radius, coat)
	draw_arc(center, radius, PI * 1.05, PI * 1.75, 14, RIM.darkened(0.42), OUTLINE_WIDTH, true)


## 비를 맞고 왔다. 어깨에 맺히고 코트를 타고 흐른다. 전부 차가운 색이다.
func _draw_wet(shoulder: float) -> void:
	# 어깨선을 허리까지 길게 그었더니 물이 아니라 **멜빵으로 보였다.** 짧고 흐리게.
	for side in [-1.0, 1.0]:
		var top := _at(Vector2(side * shoulder * 0.86, Outline.SHOULDER_Y + 4.0))
		draw_line(top, _at(Vector2(side * shoulder * 0.82, Outline.SHOULDER_Y + 17.0)),
			WET_RIM.darkened(0.30), 1.0)
		draw_circle(_at(Vector2(side * shoulder * 0.94, Outline.SHOULDER_Y + 2.0)), 1.3, WET_RIM)
	for i in 5:
		var x := (float(i) - 2.0) * shoulder * 0.30
		var y := Outline.SHOULDER_Y + 12.0 + float((i * 13) % 19)
		draw_line(_at(Vector2(x, y)), _at(Vector2(x - 0.8, y + 8.0)), WET_RIM.darkened(0.22), 1.0)


func _fill(points: PackedVector2Array, color: Color) -> void:
	var moved := PackedVector2Array()
	for p in points:
		moved.append(_at(p))
	draw_colored_polygon(moved, color)
	draw_polyline(moved + PackedVector2Array([moved[0]]), EDGE, OUTLINE_WIDTH, true)


## 몸 한가운데를 원점으로 쓰는 좌표를 실제 그리는 좌표로 옮긴다.
func _at(point: Vector2) -> Vector2:
	return Vector2(_body_center() + point.x, point.y)


func _layout_item() -> void:
	if _item_glyph == null or not _item_glyph.visible or size.y <= 0.0:
		return
	var draw_scale := _figure_scale()
	var glyph_scale := draw_scale * 0.72
	var hand := Outline.hand_point(float(SHOULDER_WIDTH[_variant]))
	_item_glyph.scale = Vector2.ONE * glyph_scale
	_item_glyph.rotation = float(_pose) * 0.008
	_item_glyph.position = _figure_origin(draw_scale) + _motion_offset() \
		+ _at(hand) * draw_scale - Vector2.ONE * 16.0 * glyph_scale


func _figure_scale() -> float:
	return size.y * FIGURE_FILL / Outline.DESIGN_HEIGHT


func _figure_origin(draw_scale: float) -> Vector2:
	return Vector2(
		size.x * FIGURE_ANCHOR_X - 50.0 * draw_scale,
		size.y - Outline.DESIGN_HEIGHT * draw_scale)


func _body_center() -> float:
	return 50.0 + float(_pose) * 1.5


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
