extends Node

## CRT와 제한 팔레트 신호를 화면 전체에 덮는다.
## **항상 켜져 있되 시간축 결함의 강도만 상황에 따라 변한다** (CLAUDE.md 5절).
##
## 긴장도는 화면에 이미 보이는 것에서만 계산한다 — 남은 오판 여유와 밤의 진행도.
## 이상 손님 여부에 연동하면 셰이더가 정답을 흘리게 되고, 그 순간 퍼즐이 죽는다.

const CRT_SHADER := preload("res://shaders/crt.gdshader")
const GRAIN_SHADER := preload("res://shaders/grain.gdshader")

const CRT_LAYER := 100
const GRAIN_LAYER := 101

const DEFAULT_GRAIN_BASE := 0.025
const DEFAULT_GRAIN_PEAK := 0.065
const DEFAULT_CHROMATIC_PEAK := 1.4
const DEFAULT_GHOST_PEAK := 0.12
const DEFAULT_JITTER_PEAK := 1.1
const DEFAULT_INTERLACE_PEAK := 0.55
const DEFAULT_TEMPORAL_CURVE := 2.0
const DEFAULT_DITHER_LEVELS := 8.0
const DEFAULT_DITHER_STRENGTH := 1.0
const DEFAULT_SAFE_SIGNAL := 0.32

## 보호 영역을 클립보드 실제 크기보다 이만큼(화면 비율) 넓게 잡는다.
##
## `protect()`의 가장자리는 부드럽게 넘어간다 — 딱 끊으면 그 경계선이 화면에 보인다.
## 그 전이 구간이 종이 위에 오면 그게 곧 기울기이고, 막으려던 문제가 그대로 돌아온다.
## 그래서 전이 구간이 **바깥 배경에서 끝나도록** 여유를 준다.
const SAFE_PAD := 0.08

var _crt: ColorRect = null
var _grain: ColorRect = null
var _tension: float = 0.0
var _clock: float = 0.0
var _config: Dictionary = {}


func _ready() -> void:
	_crt = _make_layer(CRT_SHADER, CRT_LAYER)
	_grain = _make_layer(GRAIN_SHADER, GRAIN_LAYER)
	_apply_device_config()
	set_tension(0.0)


## 그래픽 수치는 balance.json에서 온다. 부스·스팀덱별로 셰이더를 고치지 않고 조절한다.
func configure(config: Dictionary) -> void:
	_config = config.duplicate(true)
	if _grain != null:
		_apply_device_config()
		set_tension(_tension)


## 매끄러운 휘도 효과를 끌 영역. **여기 종이 단서가 있다** (F-05, 3.8% 차이).
##
## 노드 경로를 박지 않고 사각형만 받는다 (CLAUDE.md 1.2). 화면이 바뀌면 부르는 쪽이
## 다시 넘기면 되고, 안 넘기면 보호가 꺼진 채로 **조용히** 돈다 — 그래서
## `tools/paper_probe.gd`가 실제 렌더를 재서 그 상태를 잡는다.
func protect_rect(rect: Rect2, screen: Vector2) -> void:
	if _crt == null or screen.x <= 0.0 or screen.y <= 0.0:
		return
	var pos := rect.position / screen
	var size := rect.size / screen
	_crt.material.set_shader_parameter("safe_rect", Vector4(
		pos.x - SAFE_PAD, pos.y - SAFE_PAD,
		size.x + SAFE_PAD * 2.0, size.y + SAFE_PAD * 2.0))
	_grain.material.set_shader_parameter("safe_rect", Vector4(
		pos.x - SAFE_PAD, pos.y - SAFE_PAD,
		size.x + SAFE_PAD * 2.0, size.y + SAFE_PAD * 2.0))


func _process(delta: float) -> void:
	# 초 단위 시계를 넘긴다. 프레임률이 달라도 지터의 빈도와 잔상 방향이 같아야 한다.
	_clock = fposmod(_clock + delta, 1000.0)
	_grain.material.set_shader_parameter("seed", _clock)


func _make_layer(shader: Shader, layer_index: int) -> ColorRect:
	var canvas := CanvasLayer.new()
	canvas.layer = layer_index
	add_child(canvas)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	canvas.add_child(rect)
	return rect


func _apply_device_config() -> void:
	_grain.material.set_shader_parameter(
		"dither_levels", _g("dither_levels", DEFAULT_DITHER_LEVELS))
	_grain.material.set_shader_parameter(
		"dither_strength", _g("dither_strength", DEFAULT_DITHER_STRENGTH))
	_grain.material.set_shader_parameter(
		"safe_signal", _g("safe_signal", DEFAULT_SAFE_SIGNAL))


## 0.0 = 평온, 1.0 = 곧 죽는다.
func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)
	_crt.material.set_shader_parameter("tension", _tension)
	var temporal := pow(_tension, _g("temporal_curve", DEFAULT_TEMPORAL_CURVE))
	_grain.material.set_shader_parameter("tension", _tension)
	_grain.material.set_shader_parameter("intensity", lerpf(
		_g("grain_base", DEFAULT_GRAIN_BASE), _g("grain_peak", DEFAULT_GRAIN_PEAK), _tension))
	# 오판 한 번에 글씨가 흐려지지 않도록 색 번짐·잔상·지터는 후반 곡선에 몰린다.
	_grain.material.set_shader_parameter(
		"chromatic", temporal * _g("chromatic_peak_px", DEFAULT_CHROMATIC_PEAK))
	_grain.material.set_shader_parameter(
		"ghost_strength", temporal * _g("ghost_peak", DEFAULT_GHOST_PEAK))
	_grain.material.set_shader_parameter(
		"jitter_pixels", temporal * _g("jitter_peak_px", DEFAULT_JITTER_PEAK))
	_grain.material.set_shader_parameter(
		"interlace_pixels", temporal * _g("interlace_peak_px", DEFAULT_INTERLACE_PEAK))


func tension() -> float:
	return _tension


func _g(key: String, fallback: float) -> float:
	return float(_config.get(key, fallback))
