extends Control

## CCTV 한 채널. 장소는 래스터 아틀라스, 판정 단서인 사람과 그림자는 코드 오버레이다.
## 배경 이미지에는 정답 정보가 없고 네 채널 모두 같은 아틀라스를 쓴다.

const Palette := preload("res://ui/theme_factory.gd")
const CCTV_SHADER := preload("res://shaders/cctv.gdshader")
const CCTV_ATLAS := preload("res://assets/art/cctv-atlas.png")

const CHANNEL_WIDTH := 152.0
const CHANNEL_HEIGHT := 142.0
const FIGURE_WIDTH := 20.0
const FIGURE_HEIGHT := 52.0
const SHADOW_WIDTH := 40.0
const SHADOW_HEIGHT := 11.0
const EXTRA_SHADOW_OFFSET := 21.0
const SCANLINE_PITCH_PX := 4.0
const NOISE_CELL_PX := 4.0

var _index := 0
var _label_key := ""
var _strings: Dictionary = {}
var _screen: TextureRect = null
var _stage: Node2D = null
var _figure: Polygon2D = null
var _shadow: Polygon2D = null
var _extra_shadow: Polygon2D = null
var _time := 0.0


func setup(index: int, label_key: String, strings: Dictionary) -> void:
	_index = index
	_label_key = label_key
	_strings = strings
	custom_minimum_size = Vector2(CHANNEL_WIDTH, CHANNEL_HEIGHT)
	clip_contents = true
	_build()
	resized.connect(_fit_stage)


func _build() -> void:
	if _screen != null:
		return
	_screen = TextureRect.new()
	_screen.texture = _atlas_region(_index)
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.material = _make_material()
	add_child(_screen)
	_stage = Node2D.new()
	add_child(_stage)
	_add_actors()
	var tag := Palette.make_label(
		str(_strings.get(_label_key, _label_key)), Palette.SIZE_SMALL, Palette.TEXT,
		Palette.ROLE_MACHINE)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.position = Vector2(6.0, 4.0)
	add_child(tag)


func _fit_stage() -> void:
	if _stage == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_stage.scale = Vector2(size.x / CHANNEL_WIDTH, size.y / CHANNEL_HEIGHT)
	var material := _screen.material as ShaderMaterial
	material.set_shader_parameter("scanline_count", 2.0 * size.y / SCANLINE_PITCH_PX)
	material.set_shader_parameter("noise_cells", Vector2(
		size.x / NOISE_CELL_PX, size.y / NOISE_CELL_PX))


func _add_actors() -> void:
	_shadow = Polygon2D.new()
	_shadow.color = Color(0.0, 0.0, 0.0, 0.88)
	_stage.add_child(_shadow)
	_extra_shadow = Polygon2D.new()
	_extra_shadow.color = Color(0.0, 0.0, 0.0, 0.78)
	_stage.add_child(_extra_shadow)
	_figure = Polygon2D.new()
	_figure.color = Color(0.015, 0.018, 0.018, 0.96)
	_stage.add_child(_figure)


func _make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CCTV_SHADER
	material.set_shader_parameter("channel_seed", float(_index) * 0.27)
	material.set_shader_parameter("noise_amount", 0.08 + float(_index) * 0.018)
	material.set_shader_parameter("roll_speed", 0.08 + float(_index) * 0.05)
	return material


func _process(delta: float) -> void:
	_time += delta
	if _screen != null:
		(_screen.material as ShaderMaterial).set_shader_parameter("time_seed", _time)


func show_figure(visible_figure: bool, has_shadow: bool, has_extra: bool) -> void:
	var base := Vector2(CHANNEL_WIDTH * 0.5, 126.0)
	_figure.polygon = _figure_shape(base) if visible_figure else PackedVector2Array()
	_shadow.polygon = _shadow_shape(base, 0.0) if visible_figure and has_shadow \
		else PackedVector2Array()
	_extra_shadow.polygon = _shadow_shape(base, EXTRA_SHADOW_OFFSET) \
		if visible_figure and has_extra else PackedVector2Array()


static func _atlas_region(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = CCTV_ATLAS
	var half := CCTV_ATLAS.get_size() * 0.5
	texture.region = Rect2(Vector2(float(index % 2), float(index / 2)) * half, half)
	return texture


static func _figure_shape(base: Vector2) -> PackedVector2Array:
	var half := FIGURE_WIDTH * 0.5
	return PackedVector2Array([
		base + Vector2(-half, 0.0), base + Vector2(-half, -FIGURE_HEIGHT * 0.6),
		base + Vector2(-half * 0.6, -FIGURE_HEIGHT),
		base + Vector2(half * 0.6, -FIGURE_HEIGHT),
		base + Vector2(half, -FIGURE_HEIGHT * 0.6), base + Vector2(half, 0.0),
	])


static func _shadow_shape(base: Vector2, offset_x: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU * float(i) / 8.0
		points.append(base + Vector2(
			cos(angle) * SHADOW_WIDTH * 0.5 + offset_x,
			sin(angle) * SHADOW_HEIGHT * 0.5 + 2.0))
	return points
