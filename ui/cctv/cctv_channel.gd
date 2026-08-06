extends Control

## CCTV 한 채널. 전부 절차적 도형이다 — 이미지 파일 0개 (CLAUDE.md 1.1).
##
## 계산대 채널(0번)은 **손님의 그림자를 비춘다.** 그림자는 카운터에서 눈으로 볼 수 없고
## 모니터로만 확인된다. 그래서 이 화면은 분위기가 아니라 **증거**다.

const Palette := preload("res://ui/theme_factory.gd")
const CCTV_SHADER := preload("res://shaders/cctv.gdshader")

const CHANNEL_WIDTH := 152.0
const CHANNEL_HEIGHT := 92.0
const COUNTER_INDEX := 0
const SHELF_COUNT := 3
const FIGURE_WIDTH := 14.0
const FIGURE_HEIGHT := 34.0
const SHADOW_WIDTH := 30.0
const SHADOW_HEIGHT := 9.0
const EXTRA_SHADOW_OFFSET := 21.0
## 주사선 하나의 굵기(픽셀)와 잡음 셀 한 변(픽셀).
## **패널 크기에서 역산한다.** 줄 수를 직접 박으면 패널 크기가 바뀔 때 조용히 깨진다 —
## 실제로 깨져 있었다. 92px에 120~234줄이면 주기가 1픽셀 미만이라 무늬가 성립하지 않는다.
const SCANLINE_PITCH_PX := 4.0
const NOISE_CELL_PX := 4.0

var _index: int = 0
var _label_key: String = ""
var _strings: Dictionary = {}
var _screen: ColorRect = null
## 도형을 전부 담는 무대. **설계 좌표(152x92)를 그대로 쓰고 이 노드만 늘린다.**
## 좌표를 하나하나 비율로 고치면 조명 웅덩이·그림자·형상의 관계가 어긋나기 쉽고,
## 그 관계가 곧 「그림자가 없다」를 읽히게 하는 장치다 (F-04).
var _stage: Node2D = null
var _figure: Polygon2D = null
var _shadow: Polygon2D = null
var _extra_shadow: Polygon2D = null
var _time: float = 0.0


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
	_screen = ColorRect.new()
	_screen.color = Color(0.10, 0.11, 0.11)
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.material = _make_material()
	add_child(_screen)

	_stage = Node2D.new()
	_screen.add_child(_stage)

	if _index == COUNTER_INDEX:
		# 계산대 위에는 조명이 있다. 밝은 바닥이 있어야 **그림자가 없다는 사실**이 읽힌다.
		# 어두운 바닥에 검은 그림자를 그리면 있으나 없으나 똑같아 보인다.
		_stage.add_child(_make_floor())
	else:
		for i in SHELF_COUNT:
			_stage.add_child(_make_shelf(i))

	_shadow = Polygon2D.new()
	_shadow.color = Color(0.0, 0.0, 0.0, 0.82)
	_stage.add_child(_shadow)

	# 두 번째 그림자. 방향이 어긋나 있어야 "하나가 더 있다"로 읽힌다.
	_extra_shadow = Polygon2D.new()
	_extra_shadow.color = Color(0.0, 0.0, 0.0, 0.72)
	_stage.add_child(_extra_shadow)

	_figure = Polygon2D.new()
	_figure.color = Color(0.0, 0.0, 0.0, 0.9)
	_stage.add_child(_figure)

	var tag := Palette.make_label(
		str(_strings.get(_label_key, _label_key)), Palette.SIZE_SMALL, Palette.TEXT_DIM)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.position = Vector2(6, 4)
	add_child(tag)


## 패널이 커지면 무대도 같이 커진다. **도형만 원래 크기로 남으면 조명 웅덩이 밖에
## 사람이 서게 되고, 그 순간 「그림자가 없다」가 안 읽힌다.**
func _fit_stage() -> void:
	if _stage == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_stage.scale = Vector2(size.x / CHANNEL_WIDTH, size.y / CHANNEL_HEIGHT)
	# 주사선과 잡음은 **설계 크기가 아니라 실제 크기**에서 역산한다.
	# 설계 크기로 굳혀두면 패널을 키우는 순간 주기가 같이 늘어나 줄이 굵어지고
	# 잡음 셀이 네모가 아니게 된다 — 92px용 값을 175px 패널에 쓰면 주기가 7.6px다.
	var material := _screen.material as ShaderMaterial
	material.set_shader_parameter("scanline_count", 2.0 * size.y / SCANLINE_PITCH_PX)
	material.set_shader_parameter("noise_cells", Vector2(
		size.x / NOISE_CELL_PX, size.y / NOISE_CELL_PX))


func _make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CCTV_SHADER
	# 채널마다 잡음·주사선·롤링이 달라야 네 화면이 한 화면처럼 안 보인다.
	material.set_shader_parameter("channel_seed", float(_index) * 0.27)
	material.set_shader_parameter("noise_amount", 0.10 + float(_index) * 0.022)
	# 주사선은 네 채널이 **같아야** 한다. 예전에는 채널마다 줄 수를 달리해 구분했는데,
	# 그 차이가 전부 앨리어싱이라 화면마다 다른 **밝기 얼룩**으로 나왔다.
	# 구분은 잡음·롤링 속도로 낸다 — 그쪽은 정말로 채널마다 달라도 되는 것들이다.
	# 실제 값은 `_fit_stage`가 패널 크기에서 다시 잡는다. 여기 것은 첫 프레임용이다.
	material.set_shader_parameter("roll_speed", 0.08 + float(_index) * 0.05)
	return material


## 계산대 발밑의 조명 웅덩이. 그림자가 읽히는 유일한 배경이다.
func _make_floor() -> Polygon2D:
	var floor_light := Polygon2D.new()
	floor_light.color = Color(0.34, 0.35, 0.35, 1.0)
	var center := CHANNEL_WIDTH * 0.5
	floor_light.polygon = PackedVector2Array([
		Vector2(center - 42.0, 56.0), Vector2(center + 42.0, 56.0),
		Vector2(center + 52.0, 90.0), Vector2(center - 52.0, 90.0),
	])
	return floor_light


## 매대. 사각형 몇 개면 편의점처럼 보인다.
func _make_shelf(i: int) -> Polygon2D:
	var shelf := Polygon2D.new()
	shelf.color = Color(0.20, 0.21, 0.21, 0.9)
	var x := 14.0 + float(i) * 44.0
	var top := 46.0 + float((i + _index) % 2) * 9.0
	shelf.polygon = PackedVector2Array([
		Vector2(x, top), Vector2(x + 30.0, top),
		Vector2(x + 30.0, 86.0), Vector2(x, 86.0),
	])
	return shelf


func _process(delta: float) -> void:
	_time += delta
	_screen.material.set_shader_parameter("time_seed", _time)


## 계산대 채널에만 의미가 있다. 그림자가 없으면 발밑이 비어 있다.
func show_figure(visible_figure: bool, has_shadow: bool, has_extra: bool) -> void:
	var base := Vector2(CHANNEL_WIDTH * 0.5, 72.0)
	_figure.polygon = _figure_shape(base) if visible_figure else PackedVector2Array()
	_shadow.polygon = _shadow_shape(base, 0.0) if visible_figure and has_shadow \
		else PackedVector2Array()
	_extra_shadow.polygon = _shadow_shape(base, EXTRA_SHADOW_OFFSET) \
		if visible_figure and has_extra else PackedVector2Array()


static func _figure_shape(base: Vector2) -> PackedVector2Array:
	var half := FIGURE_WIDTH * 0.5
	return PackedVector2Array([
		base + Vector2(-half, 0.0),
		base + Vector2(-half, -FIGURE_HEIGHT * 0.6),
		base + Vector2(-half * 0.6, -FIGURE_HEIGHT),
		base + Vector2(half * 0.6, -FIGURE_HEIGHT),
		base + Vector2(half, -FIGURE_HEIGHT * 0.6),
		base + Vector2(half, 0.0),
	])


## 발밑에 깔리는 타원 근사. 8각형이면 충분히 그림자로 읽힌다.
static func _shadow_shape(base: Vector2, offset_x: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU * float(i) / 8.0
		points.append(base + Vector2(
			cos(angle) * SHADOW_WIDTH * 0.5 + offset_x,
			sin(angle) * SHADOW_HEIGHT * 0.5 + 2.0))
	return points
