extends RefCounted

## 트윈 · 히트스톱 · 스크린 셰이크.
## "기능이 동작한다는 건 완료가 아니다. 주스가 붙어야 완료다" (CLAUDE.md 5절).

const EASE := Tween.EASE_OUT
const TRANS := Tween.TRANS_CUBIC


## 컨테이너가 위치를 관리하는 자식용. **position을 건드리면 레이아웃과 싸운다.**
## VBox/HBox 안의 노드는 반드시 이걸 쓴다 — rise_in을 쓰면 전부 같은 자리에 겹쳐 그려진다.
static func fade_in(node: CanvasItem, duration: float, delay: float = 0.0) -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.set_ease(EASE).set_trans(TRANS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration)


## 아래에서 밀려 올라오며 나타난다. 컨테이너 밖에 있는 노드에만 쓴다.
static func rise_in(node: Control, duration: float, distance: float = 14.0) -> void:
	var target := node.position
	node.position = target + Vector2(0.0, distance)
	node.modulate.a = 0.0
	var tween := node.create_tween().set_parallel(true)
	tween.set_ease(EASE).set_trans(TRANS)
	tween.tween_property(node, "position", target, duration)
	tween.tween_property(node, "modulate:a", 1.0, duration)


## 눌린 순간 살짝 줄었다 돌아온다. 클릭에 무게를 준다.
static func press(node: Control, duration: float) -> void:
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween()
	tween.set_ease(EASE).set_trans(TRANS)
	tween.tween_property(node, "scale", Vector2(0.94, 0.94), duration * 0.3)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.7)


## 감쇠하는 흔들림. 감쇠가 없으면 그냥 멀미다.
static func shake(node: Control, strength: float, duration: float, steps: int = 8) -> void:
	var origin := node.position
	var tween := node.create_tween()
	tween.set_ease(EASE).set_trans(Tween.TRANS_SINE)
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var offset := Vector2(
			randf_range(-strength, strength) * falloff,
			randf_range(-strength, strength) * falloff
		)
		tween.tween_property(node, "position", origin + offset, duration / float(steps))
	tween.tween_property(node, "position", origin, duration / float(steps))


## 판정 순간 시간을 멈춘다. 0.05~0.12초.
## 타이머는 time_scale을 무시해야 한다 — 아니면 영원히 멈춘다.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if seconds <= 0.0:
		return
	Engine.time_scale = 0.0
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
