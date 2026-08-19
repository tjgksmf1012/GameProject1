extends Control

## 계산대 앞 손님 원화 레이어.
## 초상 선택에는 공개 특성과 ID만 쓰며 anomaly·verdict·그림자는 입력조차 받지 않는다.

const OFFICE := preload("res://assets/art/customers/office-worker.png")
const STUDENT := preload("res://assets/art/customers/student.png")
const OLDER_WOMAN := preload("res://assets/art/customers/older-woman.png")
const BAG_WOMAN := preload("res://assets/art/customers/bag-woman.png")
const BAG_WORKER := preload("res://assets/art/customers/bag-worker.png")
const HOOD := preload("res://assets/art/customers/hood-no-bag.png")
const HOOD_WOMAN := preload("res://assets/art/customers/hood-woman.png")
const HOOD_BAG := preload("res://assets/art/customers/hood-bag.png")

const OPEN_PORTRAITS := [OFFICE, STUDENT, OLDER_WOMAN]
const BAG_PORTRAITS := [BAG_WOMAN, BAG_WORKER]
const HOOD_PORTRAITS := [HOOD, HOOD_WOMAN]

const PORTRAIT_LEFT := 0.27
const BREATH_SECONDS := 4.2
const BREATH_RATE := [1.0, 1.8, 2.8]
const BREATH_DEPTH := [1.2, 2.0, 3.0]
const INFO_SHADE := Color(0.018, 0.024, 0.027, 0.90)
const INFO_FADE := Color(0.018, 0.024, 0.027, 0.0)
const WET_STREAK := Color(0.42, 0.58, 0.61, 0.18)

var _portrait: TextureRect = null
var _customer_id := ""
var _is_wet := false
var _stage := 0
var _phase := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait.anchor_left = PORTRAIT_LEFT
	_portrait.anchor_right = 1.0
	_portrait.anchor_bottom = 1.0
	add_child(_portrait)
	set_process(true)


func show_customer(
	customer_id: String, has_bag: bool, hides_face: bool, is_wet: bool,
	_item_keys: PackedStringArray
) -> void:
	_customer_id = customer_id
	_is_wet = is_wet
	_portrait.texture = _select_portrait(customer_id, has_bag, hides_face)
	_portrait.modulate = Color(0.88, 0.93, 0.93, 0.0)
	var entrance := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	entrance.tween_property(_portrait, "modulate:a", 1.0, 0.28)
	queue_redraw()


func set_pressure_stage(stage: int) -> void:
	_stage = clampi(stage, 0, BREATH_RATE.size() - 1)


func _process(delta: float) -> void:
	if _customer_id.is_empty():
		return
	_phase = fposmod(_phase + delta * float(BREATH_RATE[_stage]), BREATH_SECONDS)
	var motion := sin(_phase / BREATH_SECONDS * TAU) * float(BREATH_DEPTH[_stage])
	_portrait.offset_top = motion
	_portrait.offset_bottom = motion
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var shade_end := size.x * 0.62
	var fade_end := size.x * 0.82
	draw_rect(Rect2(0.0, 0.0, shade_end, size.y), INFO_SHADE)
	draw_polygon(PackedVector2Array([
		Vector2(shade_end, 0.0), Vector2(fade_end, 0.0),
		Vector2(fade_end, size.y), Vector2(shade_end, size.y),
	]), PackedColorArray([INFO_SHADE, INFO_FADE, INFO_FADE, INFO_SHADE]))
	if not _is_wet:
		return
	for i in 8:
		var x := size.x * (0.37 + float(i) * 0.075)
		var y := fposmod(float(i * 47) + _phase * 19.0, size.y * 0.78)
		draw_line(Vector2(x, y), Vector2(x - 2.0, y + 16.0), WET_STREAK, 1.0)


static func _select_portrait(customer_id: String, has_bag: bool, hides_face: bool) -> Texture2D:
	var seed := _stable_seed(customer_id)
	if hides_face:
		return HOOD_BAG if has_bag else HOOD_PORTRAITS[seed % HOOD_PORTRAITS.size()]
	if has_bag:
		return BAG_PORTRAITS[seed % BAG_PORTRAITS.size()]
	return OPEN_PORTRAITS[seed % OPEN_PORTRAITS.size()]


static func _stable_seed(value: String) -> int:
	var seed: int = 5381
	for i in value.length():
		seed = int((seed * 33 + value.unicode_at(i)) % 2147483647)
	return seed
