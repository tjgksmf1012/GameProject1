extends RefCounted

## 트윈 · 히트스톱 · 스크린 셰이크.
## "기능이 동작한다는 건 완료가 아니다. 주스가 붙어야 완료다" (CLAUDE.md 5절).

const EASE := Tween.EASE_OUT
const TRANS := Tween.TRANS_CUBIC


## 컨테이너가 위치를 관리하는 자식용. **position을 건드리면 레이아웃과 싸운다.**
## VBox/HBox 안의 노드는 반드시 이걸 쓴다 — rise_in을 쓰면 전부 같은 자리에 겹쳐 그려진다.
##
## `to`가 있는 이유: 도착점이 1.0으로 박혀 있어서 **흐리게 남겨야 할 것까지 진하게 만들었다.**
## 밤 7의 찢긴 자국이 그랬다 — `modulate.a = TORN_ALPHA`로 0.72를 넣어놓고 바로 이 함수를
## 불렀고, 트윈이 1.0까지 올려버려 자국이 멀쩡한 수칙과 똑같은 농도로 그려졌다.
## **일곱 밤 내내 참이던 줄이 뜯겨 나간 사건이 줄 하나 조용히 추가된 것과 구분되지 않았다.**
static func fade_in(
	node: CanvasItem, duration: float, delay: float = 0.0, to: float = 1.0
) -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.set_ease(EASE).set_trans(TRANS)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", to, duration)


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


## 스캐너가 물건에 닿았다가 스프링으로 돌아오는 세 박자. 단순 축소보다 손에 남는다.
static func rebound(node: Control, duration: float) -> void:
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween()
	tween.set_ease(EASE).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2(0.90, 0.88), duration * 0.22)
	tween.tween_property(node, "scale", Vector2(1.05, 1.07), duration * 0.36)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.42)


## 감쇠하는 흔들림. 감쇠가 없으면 그냥 멀미다.
## **앵커가 걸린 Control에 `position`을 쓰면 움직이는 게 아니라 늘어난다.**
##
## `position`은 `offset_left`/`offset_top`만 건드리고 `offset_right`/`offset_bottom`은
## 그대로 둔다. 앵커가 0~1로 펼쳐져 있으면 그 차이가 곧 크기라서, 위로 밀면 아래로 자란다.
##
## 실제로 그랬다. 오답 셰이크 한 번에 720 화면에서 VBox가 **740**이 되고, 안에 있던
## POS가 화면 밖으로 밀려 **REFUSE를 누를 수 없게** 됐다. 오답일 때만 나는 버그라
## 정상 플레이 스크린샷에는 절대 안 잡힌다 — 실제로 두 번 잘못 진단했다.
##
## 네 offset을 **같이** 민다. 그러면 크기는 그대로고 자리만 움직인다.
static func shake(node: Control, strength: float, duration: float, steps: int = 8) -> void:
	var origin := Vector2(node.offset_left, node.offset_top)
	var span := Vector2(
		node.offset_right - node.offset_left, node.offset_bottom - node.offset_top)
	var tween := node.create_tween()
	tween.set_ease(EASE).set_trans(Tween.TRANS_SINE)
	var at := origin
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var target := origin + Vector2(
			randf_range(-strength, strength) * falloff,
			randf_range(-strength, strength) * falloff)
		tween.tween_method(_nudge.bind(node, span), at, target, duration / float(steps))
		at = target
	tween.tween_method(_nudge.bind(node, span), at, origin, duration / float(steps))


## 크기를 유지한 채 자리만 옮긴다. `position`을 쓰면 안 되는 이유는 `shake` 주석 참고.
static func _nudge(at: Vector2, node: Control, span: Vector2) -> void:
	if not is_instance_valid(node):
		return
	node.offset_left = at.x
	node.offset_top = at.y
	node.offset_right = at.x + span.x
	node.offset_bottom = at.y + span.y


## 판정 순간 시간을 멈춘다. 0.05~0.12초.
## 타이머는 time_scale을 무시해야 한다 — 아니면 영원히 멈춘다.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if seconds <= 0.0:
		return
	Engine.time_scale = 0.0
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
