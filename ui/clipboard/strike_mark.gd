extends Node2D

## 수칙 한 줄을 그어버린 자국. 플레이어가 "이건 거짓말이다"라고 표시한 것이다.
##
## **믿음이지 사실이 아니다.** 판정에는 아무 영향을 주지 않는다 —
## 정답은 오직 참 수칙이 정한다 (`systems/rules/rule_engine.gd`).
##
## 이미지가 아니라 절차적 선이다 (CLAUDE.md 1.1). 자로 그은 듯 곧으면 종이 위의 펜으로
## 안 보이므로 흔들림을 준다. **글이 두 줄이면 두 줄 다 긋는다** — 한 줄만 그으면
## 지우다 만 것처럼 보인다.

const Palette := preload("res://ui/theme_factory.gd")

const WIDTH := 2.4
const PRESS_WIDTH := 4.4
const SEGMENTS := 7
const JITTER := 2.2
const OVERSHOOT := 5.0
const DRAW_SECONDS := 0.17
const RECOIL_PIXELS := 2.6
const RECOIL_SECONDS := 0.14
const STRUCK_TEXT_ALPHA := 0.55

var _label: Label = null
var _tweens: Array[Tween] = []


## 라벨의 자식으로 붙는다. 라벨이 줄바꿈으로 커지면 `resized`로 따라 그린다.
static func attach(label: Label) -> Node2D:
	var mark := (preload("res://ui/clipboard/strike_mark.gd") as GDScript).new() as Node2D
	mark.visible = false
	label.add_child(mark)
	mark.set("_label", label)
	label.resized.connect(mark._redraw_if_visible)
	return mark


func show_stroke(animate: bool) -> void:
	visible = true
	_label.modulate.a = STRUCK_TEXT_ALPHA  # 지우는 게 아니라 뒤로 보낸다
	_rebuild(animate)


func hide_stroke() -> void:
	visible = false
	_stop_tweens()
	_label.modulate.a = 1.0


## 라벨이 줄바꿈으로 커지면 줄 위치가 바뀐다. 다시 그린다.
func _redraw_if_visible() -> void:
	if visible:
		_rebuild(false)


## **그리는 도중에 다시 그려질 수 있다.** 트윈을 세우지 않으면 콜백이 이미 free된
## Line2D를 잡고 있다가 터진다 — `label.resized`가 애니메이션 중에 들어오면 그렇게 된다.
func _stop_tweens() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()


func _rebuild(animate: bool) -> void:
	_stop_tweens()
	position = Vector2.ZERO
	for child in get_children():
		child.queue_free()
	var lines := maxi(1, _label.get_line_count())
	var line_height := float(_label.size.y) / float(lines)
	for i in lines:
		var stroke := Line2D.new()
		stroke.width = PRESS_WIDTH if animate else WIDTH
		stroke.default_color = Palette.INK_MANAGER
		stroke.points = _points(_label.size.x, line_height * (float(i) + 0.55), i)
		add_child(stroke)
		if animate:
			_animate(stroke, i)
	if animate:
		_pressure_recoil()


## 흔들리는 손으로 그은 한 줄. 줄마다 흔들림이 달라야 두 번 그은 것으로 보인다.
static func _points(width: float, y: float, seed_index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var x := lerpf(-OVERSHOOT, width + OVERSHOOT, t)
		points.append(Vector2(x, y + sin(t * 7.3 + float(seed_index) * 2.1) * JITTER))
	return points


## 펜이 지나가듯 왼쪽에서 오른쪽으로. 한 번에 나타나면 도장 같다.
func _animate(stroke: Line2D, order: int) -> void:
	var full := stroke.points
	stroke.points = PackedVector2Array([full[0]])
	var tween := create_tween()
	_tweens.append(tween)
	tween.tween_interval(DRAW_SECONDS * float(order))
	for i in range(1, full.size()):
		tween.tween_callback(func() -> void:
			# 트윈을 세워도 이미 큐에 들어간 콜백은 한 번 더 돌 수 있다.
			if not is_instance_valid(stroke):
				return
			var grown := stroke.points
			grown.append(full[i])
			stroke.points = grown)
		tween.tween_interval(DRAW_SECONDS / float(full.size()))
	tween.tween_property(stroke, "width", WIDTH, DRAW_SECONDS * 0.45)


## 펜촉이 종이를 누른 뒤 손으로 돌아오는 짧은 반동. 선 자체의 굵기 변화와 동시에 돈다.
func _pressure_recoil() -> void:
	position.y = RECOIL_PIXELS
	var tween := create_tween()
	_tweens.append(tween)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", -0.8, RECOIL_SECONDS * 0.58)
	tween.tween_property(self, "position:y", 0.0, RECOIL_SECONDS * 0.42)
