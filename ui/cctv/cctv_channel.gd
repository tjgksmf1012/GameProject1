extends Control

## CCTV 한 채널. 전부 절차적 도형이다 — 이미지 파일 0개 (CLAUDE.md 1.1).
##
## 계산대 채널(0번)은 **손님의 그림자를 비춘다.** 그림자는 카운터에서 눈으로 볼 수 없고
## 모니터로만 확인된다. 그래서 이 화면은 분위기가 아니라 **증거**다.

const Palette := preload("res://ui/theme_factory.gd")
const CCTV_SHADER := preload("res://shaders/cctv.gdshader")

const CHANNEL_WIDTH := 152.0
const CHANNEL_HEIGHT := 106.0
const COUNTER_INDEX := 0
const SHELF_COUNT := 3
const FIGURE_WIDTH := 14.0
const FIGURE_HEIGHT := 34.0
const SHADOW_WIDTH := 30.0
const SHADOW_HEIGHT := 9.0

var _index: int = 0
var _label_key: String = ""
var _strings: Dictionary = {}
var _screen: ColorRect = null
var _figure: Polygon2D = null
var _shadow: Polygon2D = null
var _time: float = 0.0


func setup(index: int, label_key: String, strings: Dictionary) -> void:
	_index = index
	_label_key = label_key
	_strings = strings
	custom_minimum_size = Vector2(CHANNEL_WIDTH, CHANNEL_HEIGHT)
	clip_contents = true
	_build()


func _build() -> void:
	if _screen != null:
		return
	_screen = ColorRect.new()
	_screen.color = Color(0.10, 0.11, 0.11)
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.material = _make_material()
	add_child(_screen)

	if _index == COUNTER_INDEX:
		# 계산대 위에는 조명이 있다. 밝은 바닥이 있어야 **그림자가 없다는 사실**이 읽힌다.
		# 어두운 바닥에 검은 그림자를 그리면 있으나 없으나 똑같아 보인다.
		_screen.add_child(_make_floor())
	else:
		for i in SHELF_COUNT:
			_screen.add_child(_make_shelf(i))

	_shadow = Polygon2D.new()
	_shadow.color = Color(0.0, 0.0, 0.0, 0.82)
	_screen.add_child(_shadow)

	_figure = Polygon2D.new()
	_figure.color = Color(0.0, 0.0, 0.0, 0.9)
	_screen.add_child(_figure)

	var tag := Palette.make_label(
		str(_strings.get(_label_key, _label_key)), Palette.SIZE_SMALL, Palette.TEXT_DIM)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.position = Vector2(6, 4)
	add_child(tag)


func _make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CCTV_SHADER
	# 채널마다 잡음·주사선·롤링이 달라야 네 화면이 한 화면처럼 안 보인다.
	material.set_shader_parameter("channel_seed", float(_index) * 0.27)
	material.set_shader_parameter("noise_amount", 0.10 + float(_index) * 0.022)
	material.set_shader_parameter("scanline_count", 120.0 + float(_index) * 38.0)
	material.set_shader_parameter("roll_speed", 0.08 + float(_index) * 0.05)
	return material


## 계산대 발밑의 조명 웅덩이. 그림자가 읽히는 유일한 배경이다.
func _make_floor() -> Polygon2D:
	var floor_light := Polygon2D.new()
	floor_light.color = Color(0.34, 0.35, 0.35, 1.0)
	var center := CHANNEL_WIDTH * 0.5
	floor_light.polygon = PackedVector2Array([
		Vector2(center - 44.0, 62.0), Vector2(center + 44.0, 62.0),
		Vector2(center + 54.0, 100.0), Vector2(center - 54.0, 100.0),
	])
	return floor_light


## 매대. 사각형 몇 개면 편의점처럼 보인다.
func _make_shelf(i: int) -> Polygon2D:
	var shelf := Polygon2D.new()
	shelf.color = Color(0.20, 0.21, 0.21, 0.9)
	var x := 14.0 + float(i) * 44.0
	var top := 52.0 + float((i + _index) % 2) * 10.0
	shelf.polygon = PackedVector2Array([
		Vector2(x, top), Vector2(x + 30.0, top),
		Vector2(x + 30.0, 96.0), Vector2(x, 96.0),
	])
	return shelf


func _process(delta: float) -> void:
	_time += delta
	_screen.material.set_shader_parameter("time_seed", _time)


## 계산대 채널에만 의미가 있다. 그림자가 없으면 발밑이 비어 있다.
func show_figure(visible_figure: bool, has_shadow: bool) -> void:
	var base := Vector2(CHANNEL_WIDTH * 0.5, 80.0)
	_figure.polygon = _figure_shape(base) if visible_figure else PackedVector2Array()
	_shadow.polygon = _shadow_shape(base) if visible_figure and has_shadow \
		else PackedVector2Array()


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
static func _shadow_shape(base: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var angle := TAU * float(i) / 8.0
		points.append(base + Vector2(
			cos(angle) * SHADOW_WIDTH * 0.5,
			sin(angle) * SHADOW_HEIGHT * 0.5 + 2.0))
	return points
