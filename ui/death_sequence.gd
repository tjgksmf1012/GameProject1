extends CanvasLayer

## 밤이 실패했을 때의 연출 1종 (F-07).
##
## **가장 먼저 하는 일은 소리를 끄는 것이다.** 굉음보다 정적이 무섭다.
## 그 다음에 형광등이 나가고, CCTV가 죽고, 카운터 너머의 것이 다가온다.
##
## 부조리는 여기서만 허용된다. 플레이 중에는 절대 웃기지 않는다 (02-user-needs 충돌 C).
## 전부 절차적 도형과 색이다 — 이미지 0개 (CLAUDE.md 1.1).

const Palette := preload("res://ui/theme_factory.gd")

const LAYER_INDEX := 90
const SILENCE_SECONDS := 0.45
const FLICKER_COUNT := 6
const APPROACH_SECONDS := 1.55
const BLACKOUT_SECONDS := 0.26
const HOLD_SECONDS := 0.55

const FIGURE_START_SCALE := 0.18
const FIGURE_END_SCALE := 4.2

signal finished

var _veil: ColorRect = null
var _figure: Polygon2D = null
var _holder: Node2D = null


func _init() -> void:
	layer = LAYER_INDEX


func _ready() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_holder = Node2D.new()
	_holder.visible = false
	add_child(_holder)

	_figure = Polygon2D.new()
	_figure.color = Color(0.0, 0.0, 0.0, 1.0)
	_figure.polygon = _silhouette()
	_holder.add_child(_figure)


## 사람 형상. 위로 갈수록 좁아지는 단순한 실루엣이면 충분하다.
static func _silhouette() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-30, 90), Vector2(-30, -10), Vector2(-18, -40),
		Vector2(-16, -66), Vector2(0, -80), Vector2(16, -66),
		Vector2(18, -40), Vector2(30, -10), Vector2(30, 90),
	])


## 화면 중앙 아래에서 커지며 다가온다.
##
## **깜빡임과 접근을 겹친다.** 검은 실루엣을 검은 화면에 그리면 아무것도 안 보인다.
## 형광등이 터지는 흰 섬광 순간에만 형체가 보이고, 그때마다 더 커져 있다.
## 계속 보이는 것보다 이쪽이 훨씬 무섭다.
func play(viewport: Vector2) -> void:
	_holder.position = Vector2(viewport.x * 0.5, viewport.y * 0.78)
	_holder.scale = Vector2.ONE * FIGURE_START_SCALE
	_holder.visible = false
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)

	var approach := create_tween()
	approach.tween_interval(SILENCE_SECONDS)
	approach.tween_callback(func() -> void: _holder.visible = true)
	approach.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	approach.tween_property(_holder, "scale", Vector2.ONE * FIGURE_END_SCALE, APPROACH_SECONDS)

	var lights := create_tween()
	lights.tween_interval(SILENCE_SECONDS)
	_append_flicker(lights)
	lights.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	lights.tween_property(_veil, "color", Color(0.0, 0.0, 0.0, 1.0), BLACKOUT_SECONDS)
	lights.tween_interval(HOLD_SECONDS)
	lights.tween_callback(_emit_finished)


## 형광등이 터진다. 섬광은 점점 짧고 밝아지고, 어둠은 점점 깊어진다.
func _append_flicker(tween: Tween) -> void:
	var step := APPROACH_SECONDS / float(FLICKER_COUNT)
	for i in FLICKER_COUNT:
		var t := float(i) / float(FLICKER_COUNT)
		var flash := Color(1.0, 1.0, 1.0, 0.30 + t * 0.55)
		var dark := Color(0.0, 0.0, 0.0, 0.55 + t * 0.35)
		tween.tween_property(_veil, "color", flash, step * 0.22)
		tween.tween_property(_veil, "color", dark, step * 0.78)


func _emit_finished() -> void:
	finished.emit()


## 연출이 끝난 뒤 정산을 보여줘야 하므로 장막을 걷는다.
func clear() -> void:
	_holder.visible = false
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)


static func total_seconds() -> float:
	return SILENCE_SECONDS + APPROACH_SECONDS + BLACKOUT_SECONDS + HOLD_SECONDS
