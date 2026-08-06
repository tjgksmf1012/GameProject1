extends Node

## CRT와 그레인을 화면 전체에 덮는다. **항상 켜져 있되 강도가 상황에 따라 변한다** (CLAUDE.md 5절).
##
## 긴장도는 화면에 이미 보이는 것에서만 계산한다 — 남은 오판 여유와 밤의 진행도.
## 이상 손님 여부에 연동하면 셰이더가 정답을 흘리게 되고, 그 순간 퍼즐이 죽는다.

const CRT_SHADER := preload("res://shaders/crt.gdshader")
const GRAIN_SHADER := preload("res://shaders/grain.gdshader")

const CRT_LAYER := 100
const GRAIN_LAYER := 101

const GRAIN_BASE := 0.045
const GRAIN_PEAK := 0.10
const CHROMATIC_PEAK := 1.7
const CHROMATIC_CURVE := 2.0

## 보호 영역을 클립보드 실제 크기보다 이만큼(화면 비율) 넓게 잡는다.
##
## `protect()`의 가장자리는 부드럽게 넘어간다 — 딱 끊으면 그 경계선이 화면에 보인다.
## 그 전이 구간이 종이 위에 오면 그게 곧 기울기이고, 막으려던 문제가 그대로 돌아온다.
## 그래서 전이 구간이 **바깥 배경에서 끝나도록** 여유를 준다.
const SAFE_PAD := 0.08

var _crt: ColorRect = null
var _grain: ColorRect = null
var _tension: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_crt = _make_layer(CRT_SHADER, CRT_LAYER)
	_grain = _make_layer(GRAIN_SHADER, GRAIN_LAYER)
	set_tension(0.0)


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


func _process(delta: float) -> void:
	# 그레인이 정지해 있으면 사진처럼 보인다. 매 프레임 흔들어야 필름이 된다.
	_seed = fposmod(_seed + delta * 60.0, 1000.0)
	_grain.material.set_shader_parameter("seed", _seed)


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


## 0.0 = 평온, 1.0 = 곧 죽는다.
func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)
	_crt.material.set_shader_parameter("tension", _tension)
	_grain.material.set_shader_parameter("intensity", lerpf(GRAIN_BASE, GRAIN_PEAK, _tension))
	# 선형이면 오판 한 번에 벌써 글씨가 흐려진다. 후반에만 몰리도록 곡선을 준다.
	_grain.material.set_shader_parameter(
		"chromatic", pow(_tension, CHROMATIC_CURVE) * CHROMATIC_PEAK)


func tension() -> float:
	return _tension
