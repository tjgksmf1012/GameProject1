extends Control

## 계산대 앞 손님의 상반신 실루엣.
## 작은 전신과 막대기 다리를 폐기하고, 카운터에 밀착한 머리·어깨·소매·손으로 다시 만든다.
## 체형과 자세는 오직 손님 ID로 정하며 anomaly·판정·그림자는 입력조차 받지 않는다.

const Palette := preload("res://ui/theme_factory.gd")
const ProductGlyph := preload("res://ui/art/product_glyph.gd")
const Outline := preload("res://ui/art/figure_outline.gd")

const FIGURE_FILL := 0.92
const FIGURE_ANCHOR_X := 0.75
const BREATH_PIXELS := 1.6
const BREATH_SECONDS := 4.2
const BREATH_RATE := [1.0, 1.8, 2.8]
const BREATH_DEPTH := [1.0, 1.4, 1.9]
const OUTLINE_WIDTH := 2.4
const RIM_WIDTH := 1.8

const KEYLINE := Color("090c0d")
const BACKLIGHT := Color("59686b")
const FACE_VOID := Color("070a0b")
const FACE_LINE := Color("6a7d80")
const SEAM := Color("4a585c")
const STRAP := Color("596a6e")
const WET_RIM := Color("718f95")
const HOOD_VOID := Color("040607")
const GLOVE := Color("101719")
const COUNTER_TOP := Color("435154")
const COUNTER_FRONT := Color("0d1112")
const COUNTER_GRAIN := Color("344247")
const COAT_TONES := [
	Color("1b2326"), Color("20282a"), Color("182125"), Color("242b2e"),
]
const SHOULDER_WIDTH := [33.0, 36.0, 39.0, 35.0]
const WAIST_WIDTH := [28.0, 30.0, 32.0, 29.0]
const HEAD_RADIUS := [14.2, 14.8, 14.5, 15.0]

var _customer_id := ""
var _has_bag := false
var _hides_face := false
var _is_wet := false
var _item_key := ""
var _variant := 0
var _pose := 0
var _phase_offset := 0.0
var _breath := 0.0
var _stage := 0
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
	if _customer_id.is_empty():
		return
	var draw_scale := _figure_scale()
	var lean := _lean()
	var tilt := float(_pose) * 0.010 + sin(_phase()) * 0.0015
	draw_set_transform(_figure_origin(draw_scale) + _motion_offset(), tilt, Vector2.ONE * draw_scale)
	_draw_person(lean)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_counter(draw_scale)


func _draw_person(lean: float) -> void:
	var coat: Color = COAT_TONES[_variant]
	var shoulder := float(SHOULDER_WIDTH[_variant])
	var waist := float(WAIST_WIDTH[_variant])
	if _has_bag:
		_fill(Outline.bag(shoulder, lean), coat.darkened(0.10))
	_fill(Outline.silhouette(shoulder, waist, lean), coat)
	draw_colored_polygon(Outline.light_plane(shoulder, lean), COUNTER_GRAIN)
	draw_colored_polygon(Outline.neck(float(HEAD_RADIUS[_variant]), lean), coat)
	if _has_bag:
		_draw_strap(shoulder, lean)
	_draw_head(coat, lean)
	_draw_garment(shoulder, lean)
	_draw_hands(shoulder)
	_draw_backlight(shoulder, lean)
	if _is_wet:
		_draw_wet(shoulder, lean)


func _draw_head(coat: Color, lean: float) -> void:
	var radius := float(HEAD_RADIUS[_variant])
	var points := Outline.hood(radius, lean) if _hides_face \
		else Outline.head(radius, lean, _facing())
	_fill(points, coat)
	if not _hides_face: draw_colored_polygon(Outline.face_plane(radius, lean, _facing()), COUNTER_GRAIN)
	if _hides_face:
		var center := Vector2(lean * 0.95, Outline.HEAD_CENTER_Y + 1.5)
		_draw_ellipse(center, Vector2(radius * 0.68, radius * 0.86), HOOD_VOID)
		draw_arc(center, radius * 1.02, PI * 1.03, PI * 1.50, 10,
			BACKLIGHT.darkened(0.10), RIM_WIDTH, true)
		return
	draw_polyline(Outline.head_rim(radius, lean, _facing()),
		BACKLIGHT.darkened(0.10), RIM_WIDTH, true)
	# 중립적인 한쪽 눈과 콧날만 남긴다. 표정은 읽히지 않지만 마네킹처럼 보이지는 않는다.
	var center := Vector2(lean * 0.95, Outline.HEAD_CENTER_Y)
	var facing := _facing()
	var eye := center + Vector2(facing * 4.8, -3.2)
	_draw_ellipse(eye, Vector2(2.4, 1.35), FACE_VOID)
	draw_circle(eye + Vector2(facing * 0.7, -0.2), 0.55, FACE_LINE)
	draw_line(eye + Vector2(-facing * 3.5, -2.4), eye + Vector2(facing * 2.8, -2.0),
		FACE_LINE.darkened(0.28), 1.1, true)
	draw_line(center + Vector2(facing * 5.4, -0.2), center + Vector2(facing * 8.0, 4.0),
		FACE_LINE.darkened(0.38), 1.0, true)


func _draw_garment(shoulder: float, lean: float) -> void:
	for side in [-1.0, 1.0]:
		var seam := Outline.sleeve_seam(side, shoulder, lean)
		draw_polyline(seam, SEAM.darkened(0.16), 1.25, true)
	if _customer_id == "cust_office_worker":
		_draw_loose_tie(lean)
		return
	var collar := Vector2(lean * 0.8, Outline.NECK_Y + 3.0)
	match _variant:
		0:
			draw_line(collar, Vector2(-13.0, Outline.SHOULDER_Y + 21.0), SEAM, 1.4, true)
			draw_line(collar, Vector2(12.0, Outline.SHOULDER_Y + 19.0), SEAM, 1.4, true)
		1:
			draw_line(collar, Vector2(lean * 0.4, Outline.COUNTER_Y - 14.0), SEAM, 1.2, true)
		2:
			draw_line(Vector2(-14.0, Outline.SHOULDER_Y + 12.0),
				Vector2(18.0, Outline.SHOULDER_Y + 16.0), SEAM, 1.4, true)
		_:
			draw_arc(Vector2(lean * 0.6, Outline.SHOULDER_Y + 5.0),
				15.0, 0.15, PI - 0.15, 12, SEAM, 1.4, true)


func _draw_loose_tie(lean: float) -> void:
	var knot := Vector2(lean * 0.72 + 1.5, Outline.NECK_Y + 10.0)
	draw_line(knot, Vector2(-15.0 + lean * 0.6, Outline.SHOULDER_Y + 20.0), SEAM, 1.5, true)
	draw_line(knot, Vector2(14.0 + lean * 0.5, Outline.SHOULDER_Y + 18.0), SEAM, 1.5, true)
	var tie := PackedVector2Array([
		knot + Vector2(-3.0, 1.0), knot + Vector2(3.0, 0.0),
		knot + Vector2(1.0, 11.0), knot + Vector2(-2.5, 36.0),
		knot + Vector2(-7.0, 42.0), knot + Vector2(-8.0, 34.0),
	])
	draw_colored_polygon(tie, SEAM.darkened(0.20))
	draw_polyline(tie + PackedVector2Array([tie[0]]), STRAP.darkened(0.10), 1.1, true)


func _draw_hands(shoulder: float) -> void:
	var hand := Outline.hand_point(shoulder)
	_draw_ellipse(hand + Vector2(-10.0, 0.0), Vector2(8.0, 4.6), GLOVE)
	draw_line(hand + Vector2(-17.0, 0.0), hand + Vector2(-5.0, -1.0), SEAM, 1.1, true)
	if not _item_key.is_empty():
		_draw_ellipse(hand + Vector2(11.0, 1.0), Vector2(7.0, 4.2), GLOVE)
	else:
		_draw_ellipse(Vector2(-shoulder * 0.22, Outline.COUNTER_Y - 2.0),
			Vector2(8.0, 4.5), GLOVE)


func _draw_backlight(shoulder: float, lean: float) -> void:
	var rim := Outline.shoulder_rim(shoulder, lean)
	draw_polyline(rim, BACKLIGHT, RIM_WIDTH, true)
	var right := Outline.sleeve_seam(1.0, shoulder, lean)
	draw_polyline(PackedVector2Array([right[1], right[2], right[3]]),
		BACKLIGHT.darkened(0.36), 1.15, true)


func _draw_strap(shoulder: float, lean: float) -> void:
	var line := Outline.strap(shoulder, lean)
	draw_line(line[0], line[1], STRAP.darkened(0.20), 2.4, true)
	draw_line(line[0], line[1], STRAP, 0.8, true)


func _draw_wet(shoulder: float, lean: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * shoulder * 0.82 + lean * 0.5
		draw_line(Vector2(x, Outline.SHOULDER_Y + 3.0),
			Vector2(x + side, Outline.SHOULDER_Y + 18.0), WET_RIM, 1.2, true)
	for i in 5:
		var x: float = (float(i) - 2.0) * shoulder * 0.25 + lean * 0.35
		var y: float = Outline.SHOULDER_Y + 19.0 + float((i * 11) % 25)
		draw_line(Vector2(x, y), Vector2(x - 1.0, y + 9.0), WET_RIM.darkened(0.18), 1.0)


func _fill(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), KEYLINE, OUTLINE_WIDTH, true)


func _draw_counter(draw_scale: float) -> void:
	var y := _figure_origin(draw_scale).y + Outline.COUNTER_Y * draw_scale
	draw_rect(Rect2(0.0, y, size.x, size.y - y), COUNTER_FRONT)
	draw_rect(Rect2(0.0, y, size.x, 5.0), COUNTER_TOP)
	if not _item_key.is_empty():
		var hand := Outline.hand_point(float(SHOULDER_WIDTH[_variant]))
		var item_x := _figure_origin(draw_scale).x + hand.x * draw_scale
		draw_line(Vector2(item_x - 18.0, y + 5.0), Vector2(item_x + 18.0, y + 5.0),
			KEYLINE, 3.0, true)
	draw_line(Vector2(0.0, y + 6.0), Vector2(size.x, y + 6.0), KEYLINE, 2.0)
	for i in 5:
		var x := size.x * (0.08 + float(i) * 0.21)
		draw_line(Vector2(x, y + 12.0), Vector2(x - 9.0, size.y), COUNTER_GRAIN, 1.0)


func _layout_item() -> void:
	if _item_glyph == null or not _item_glyph.visible or size.y <= 0.0:
		return
	var draw_scale := _figure_scale()
	var glyph_scale := draw_scale * 0.66
	var hand := Outline.hand_point(float(SHOULDER_WIDTH[_variant]))
	var item_top := Vector2(hand.x - 2.0, Outline.COUNTER_Y - 32.0 * 0.66)
	_item_glyph.scale = Vector2.ONE * glyph_scale
	_item_glyph.rotation = float(_pose) * 0.010
	_item_glyph.position = _figure_origin(draw_scale) + _motion_offset() \
		+ item_top * draw_scale - Vector2(16.0, 0.0) * glyph_scale


func _figure_scale() -> float:
	return size.y * FIGURE_FILL / Outline.DESIGN_HEIGHT


func _figure_origin(draw_scale: float) -> Vector2:
	return Vector2(size.x * FIGURE_ANCHOR_X, size.y - Outline.DESIGN_HEIGHT * draw_scale)


func _lean() -> float:
	return float(_pose) * 3.0


func _facing() -> float:
	return -1.0 if _variant % 2 == 0 else 1.0


func _phase() -> float:
	return _breath / BREATH_SECONDS * TAU + _phase_offset


func _motion_offset() -> Vector2:
	var level := clampi(_stage, 0, BREATH_DEPTH.size() - 1)
	var phase := sin(_phase())
	return Vector2(phase * 0.18, phase * BREATH_PIXELS * float(BREATH_DEPTH[level]))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


static func _stable_seed(value: String) -> int:
	var seed: int = 5381
	for i in value.length():
		seed = int((seed * 33 + value.unicode_at(i)) % 2147483647)
	return seed
