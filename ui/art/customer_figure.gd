extends Control

## 계산대 앞 손님의 연기 레이어.
##
## 각 원화는 2x2 시트다: 대기, 말하기, 초조, 압박. 공개 특성과 ID만으로
## 시트를 고르고, 대사 공개와 모든 손님에게 공통인 인내 단계만으로 칸을 바꾼다.
## 정답, anomaly, verdict, 그림자 정보는 이 레이어에 들어오지 않는다.

const BUS_DRIVER := preload("res://assets/art/performers/bus-driver.png")
const NIGHT_FLORIST := preload("res://assets/art/performers/night-florist.png")
const LAB_TECHNICIAN := preload("res://assets/art/performers/lab-technician.png")
const NIGHT_OFFICE_WORKER := preload("res://assets/art/performers/night-office-worker.png")
const DELIVERY_RIDER := preload("res://assets/art/performers/delivery-rider.png")
const PORTRAIT_RETOUCHER := preload("res://assets/art/performers/portrait-retoucher.png")
const PRINTMAKING_STUDENT := preload("res://assets/art/performers/printmaking-student.png")
const AMATEUR_BOXER := preload("res://assets/art/performers/amateur-boxer.png")
const FISH_AUCTIONEER := preload("res://assets/art/performers/fish-auctioneer.png")
const LAUNDRY_COLLECTOR := preload("res://assets/art/performers/laundry-collector.png")

const OPEN_SHEETS := [BUS_DRIVER, NIGHT_FLORIST, LAB_TECHNICIAN, NIGHT_OFFICE_WORKER]
const BAG_SHEETS := [DELIVERY_RIDER, PORTRAIT_RETOUCHER, PRINTMAKING_STUDENT]
const HOOD_SHEETS := [AMATEUR_BOXER, FISH_AUCTIONEER]

## 이름에 성별이나 역할이 명시된 첫 손님은 해시 운에 맡기지 않는다. 값은 모두 공개된
## ID와 관찰 특성에 맞는 시트이며, 이상 여부나 정답은 이 표의 입력이 아니다.
const APPEARANCE_OVERRIDES := {
	"cust_office_worker": NIGHT_OFFICE_WORKER,
	"cust_student_bag": PRINTMAKING_STUDENT,
	"cust_wet_normal": NIGHT_FLORIST,
	"cust_two_shadows": BUS_DRIVER,
	"cust_wet_bag": PORTRAIT_RETOUCHER,
	"cust_late_drinker": DELIVERY_RIDER,
}

const ACT_ARRIVAL := 0
const ACT_SPEAKING := 1
const ACT_URGING := 2
const ACT_DEMANDING := 3

const PORTRAIT_LEFT := 0.27
const ACT_CROSSFADE := 0.16
const BREATH_SECONDS := 4.2
const BREATH_RATE := [1.0, 1.8, 2.8]
const BREATH_DEPTH := [1.2, 2.0, 3.0]
const PORTRAIT_TINT := Color(0.88, 0.93, 0.93, 1.0)
const INFO_SHADE := Color(0.018, 0.024, 0.027, 0.90)
const INFO_FADE := Color(0.018, 0.024, 0.027, 0.0)
const WET_STREAK := Color(0.42, 0.58, 0.61, 0.18)

var _portrait: TextureRect = null
var _incoming: TextureRect = null
var _sheet: Texture2D = null
var _customer_id := ""
var _session_salt: int = randi()
var _is_wet := false
var _stage := 0
var _act := -1
var _dialogue_active := false
var _dialogue_silent := false
var _phase := 0.0
var _transition: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait = _make_layer()
	add_child(_portrait)
	_incoming = _make_layer()
	_incoming.modulate = Color(PORTRAIT_TINT, 0.0)
	add_child(_incoming)
	set_process(true)


func _make_layer() -> TextureRect:
	var layer := TextureRect.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.anchor_left = PORTRAIT_LEFT
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	return layer


func show_customer(
	customer_id: String, has_bag: bool, hides_face: bool, is_wet: bool,
	_item_keys: PackedStringArray
) -> void:
	_customer_id = customer_id
	_is_wet = is_wet
	_stage = 0
	_dialogue_active = false
	_dialogue_silent = false
	_sheet = _select_sheet(customer_id, has_bag, hides_face)
	_act = -1
	_set_act(ACT_ARRIVAL, true)
	_portrait.modulate = Color(PORTRAIT_TINT, 0.0)
	var entrance := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	entrance.tween_property(_portrait, "modulate:a", 1.0, 0.28)
	queue_redraw()


func set_dialogue_active(active: bool, silent: bool = false) -> void:
	_dialogue_active = active
	_dialogue_silent = silent
	_refresh_act()


func set_pressure_stage(stage: int) -> void:
	_stage = clampi(stage, 0, BREATH_RATE.size() - 1)
	_refresh_act()


func _refresh_act() -> void:
	if _stage >= 2:
		_set_act(ACT_DEMANDING)
	elif _stage == 1:
		_set_act(ACT_URGING)
	elif _dialogue_active and not _dialogue_silent:
		_set_act(ACT_SPEAKING)
	else:
		_set_act(ACT_ARRIVAL)


func _set_act(next_act: int, immediate: bool = false) -> void:
	if _sheet == null or next_act == _act:
		return
	_act = next_act
	var texture := _atlas_region(_sheet, next_act)
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if immediate or _portrait.texture == null:
		_portrait.texture = texture
		_portrait.modulate = PORTRAIT_TINT
		_incoming.modulate = Color(PORTRAIT_TINT, 0.0)
		return
	_incoming.texture = texture
	_incoming.modulate = Color(PORTRAIT_TINT, 0.0)
	_portrait.modulate = PORTRAIT_TINT
	_transition = create_tween().set_parallel(true)
	_transition.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_transition.tween_property(_incoming, "modulate:a", 1.0, ACT_CROSSFADE)
	_transition.tween_property(_portrait, "modulate:a", 0.0, ACT_CROSSFADE)
	_transition.finished.connect(_finish_transition.bind(texture))


func _finish_transition(texture: Texture2D) -> void:
	_portrait.texture = texture
	_portrait.modulate = PORTRAIT_TINT
	_incoming.modulate = Color(PORTRAIT_TINT, 0.0)


func _process(delta: float) -> void:
	if _customer_id.is_empty():
		return
	_phase = fposmod(_phase + delta * float(BREATH_RATE[_stage]), BREATH_SECONDS)
	var motion := sin(_phase / BREATH_SECONDS * TAU) * float(BREATH_DEPTH[_stage])
	for layer in [_portrait, _incoming]:
		layer.offset_top = motion
		layer.offset_bottom = motion
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


static func _atlas_region(sheet: Texture2D, act: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var half := sheet.get_size() * 0.5
	texture.region = Rect2(Vector2(float(act % 2), float(act / 2)) * half, half)
	return texture


func _select_sheet(customer_id: String, has_bag: bool, hides_face: bool) -> Texture2D:
	if APPEARANCE_OVERRIDES.has(customer_id):
		return APPEARANCE_OVERRIDES[customer_id] as Texture2D
	var seed := _stable_seed("%s:%d" % [customer_id, _session_salt])
	if hides_face:
		return LAUNDRY_COLLECTOR if has_bag else HOOD_SHEETS[seed % HOOD_SHEETS.size()]
	if has_bag:
		return BAG_SHEETS[seed % BAG_SHEETS.size()]
	return OPEN_SHEETS[seed % OPEN_SHEETS.size()]


static func _stable_seed(value: String) -> int:
	var seed: int = 5381
	for i in value.length():
		seed = int((seed * 33 + value.unicode_at(i)) % 2147483647)
	return seed
