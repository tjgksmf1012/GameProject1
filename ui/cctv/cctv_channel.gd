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
const AISLE_INDEX := 1
const STORAGE_INDEX := 2
const ENTRANCE_INDEX := 3
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

	_build_environment()

	_add_actors()

	var tag := Palette.make_label(
		str(_strings.get(_label_key, _label_key)), Palette.SIZE_SMALL, Palette.TEXT_DIM,
		Palette.ROLE_MACHINE)
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


## 사람과 그림자. **그리는 순서가 곧 겹치는 순서다** — 그림자가 먼저, 사람이 나중.
func _add_actors() -> void:
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


func _build_environment() -> void:
	if _index == COUNTER_INDEX:
		_stage.add_child(_make_floor())
		_add_line([Vector2(20, 85), Vector2(132, 85)], Color(0.52, 0.53, 0.51, 0.35), 3.0)
	elif _index == AISLE_INDEX:
		_build_aisle()
	elif _index == STORAGE_INDEX:
		_build_storage()
	elif _index == ENTRANCE_INDEX:
		_build_entrance()


func _build_aisle() -> void:
	_add_quad([Vector2(55, 36), Vector2(97, 36), Vector2(132, 92), Vector2(20, 92)], Color(0.27, 0.28, 0.27, 0.34))
	for side in [0, 1]:
		var x := 5.0 if side == 0 else 111.0
		_add_quad([
			Vector2(x, 30), Vector2(x + 36, 35),
			Vector2(x + 36, 84), Vector2(x, 90),
		], Color(0.18, 0.20, 0.19, 0.95))
		for row in 3:
			var y := 45.0 + float(row) * 16.0
			_add_line([Vector2(x + 2, y), Vector2(x + 34, y + 2)], Color(0.45, 0.46, 0.43, 0.30), 2.0)
	_add_line([Vector2(76, 37), Vector2(76, 92)], Color(0.46, 0.48, 0.45, 0.15), 1.0)


func _build_storage() -> void:
	_add_quad([Vector2(48, 23), Vector2(105, 23), Vector2(105, 83), Vector2(48, 83)], Color(0.08, 0.10, 0.10, 0.98))
	_add_line([Vector2(48, 23), Vector2(105, 23), Vector2(105, 83)], Color(0.43, 0.45, 0.42, 0.42), 3.0)
	for i in 5:
		var col := i % 3
		var row := i / 3
		var x := 8.0 + float(col) * 34.0
		var y := 61.0 + float(row) * 18.0
		_add_quad([Vector2(x, y), Vector2(x + 28, y), Vector2(x + 26, y + 17), Vector2(x + 2, y + 17)], Color(0.22, 0.22, 0.20, 0.90))
		_add_line([Vector2(x + 2, y + 5), Vector2(x + 26, y + 5)], Color(0.38, 0.38, 0.35, 0.35), 1.0)
	_add_line([Vector2(16, 30), Vector2(16, 59), Vector2(39, 59)], Color(0.42, 0.45, 0.42, 0.30), 2.0)


func _build_entrance() -> void:
	_add_quad([Vector2(31, 17), Vector2(121, 17), Vector2(121, 90), Vector2(31, 90)], Color(0.07, 0.11, 0.11, 0.95))
	_add_line([Vector2(31, 17), Vector2(121, 17), Vector2(121, 90)], Color(0.47, 0.50, 0.47, 0.46), 3.0)
	_add_line([Vector2(76, 17), Vector2(76, 90)], Color(0.44, 0.48, 0.45, 0.38), 2.0)
	_add_line([Vector2(31, 58), Vector2(121, 58)], Color(0.37, 0.42, 0.40, 0.30), 1.0)
	for i in 9:
		var x := 38.0 + float((i * 19) % 76)
		var y := 25.0 + float((i * 23) % 43)
		_add_line([Vector2(x, y), Vector2(x - 2, y + 10)], Color(0.50, 0.59, 0.56, 0.31), 1.0)
	_add_quad([Vector2(42, 82), Vector2(111, 82), Vector2(135, 92), Vector2(18, 92)], Color(0.36, 0.38, 0.35, 0.23))


func _add_quad(points: Array[Vector2], color: Color) -> void:
	var shape := Polygon2D.new()
	shape.color = color
	shape.polygon = PackedVector2Array(points)
	_stage.add_child(shape)


func _add_line(points: Array[Vector2], color: Color, width: float) -> void:
	var line := Line2D.new()
	line.default_color = color
	line.width = width
	line.points = PackedVector2Array(points)
	_stage.add_child(line)


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
