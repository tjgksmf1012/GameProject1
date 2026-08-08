extends CanvasLayer

## 밤이 실패했을 때의 연출 3종 (F-07, N5 — 클립화 가능해야 한다).
##
## **가장 먼저 하는 일은 소리를 끄는 것이다.** 굉음보다 정적이 무섭다.
##
## 연출은 **무엇이 당신을 죽였는지에 따라 달라진다.**
##   · 거짓 수칙에 속아 죽었으면 → 수칙이 화면을 채운다
##   · 그림자를 놓쳐 죽었으면 → CCTV가 하나씩 그것을 비춘다
##   · 그 외 → 카운터 너머의 것이 다가온다
## 같은 화면이 세 번 나오면 세 번째부터는 무섭지 않다. 그리고 클립이 겹친다.
##
## 부조리는 여기서만 허용된다. 플레이 중에는 절대 웃기지 않는다 (02-user-needs 충돌 C).
## 전부 절차적 도형과 색이다 — 이미지 0개 (CLAUDE.md 1.1).

const Palette := preload("res://ui/theme_factory.gd")

const KIND_APPROACH := "approach"
const KIND_CCTV := "cctv"
const KIND_RULES := "rules"

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
var _stage: Control = null
var _holder: Node2D = null
var _figure: Polygon2D = null
var _strings: Dictionary = {}


func _init() -> void:
	layer = LAYER_INDEX


func setup(strings: Dictionary) -> void:
	_strings = strings


func _ready() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	# 연출마다 다른 것을 그린다. 매번 비우고 새로 채운다.
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_holder = Node2D.new()
	_holder.visible = false
	add_child(_holder)
	_figure = Polygon2D.new()
	_figure.color = Color(0.0, 0.0, 0.0, 1.0)
	_figure.polygon = silhouette()
	_holder.add_child(_figure)


## 무엇이 죽였는지로 연출을 고른다.
## 판정 결과에서 바로. 결과가 없으면(첫 손님 전 등) 다가오는 쪽으로 둔다.
static func kind_for_result(result: JudgeResult) -> String:
	if result == null:
		return KIND_APPROACH
	return kind_for(result.trap_triggered, result.decisive_fields)


static func kind_for(trapped: bool, decisive_fields: PackedStringArray) -> String:
	if trapped:
		return KIND_RULES
	for field in decisive_fields:
		if field.contains("shadow"):
			return KIND_CCTV
	return KIND_APPROACH


## 사람 형상. 위로 갈수록 좁아지는 단순한 실루엣이면 충분하다.
static func silhouette(scale: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array([
		Vector2(-30, 90), Vector2(-30, -10), Vector2(-18, -40),
		Vector2(-16, -66), Vector2(0, -80), Vector2(16, -66),
		Vector2(18, -40), Vector2(30, -10), Vector2(30, 90),
	])
	if is_equal_approx(scale, 1.0):
		return points
	var scaled := PackedVector2Array()
	for p in points:
		scaled.append(p * scale)
	return scaled


func play(kind: String, viewport: Vector2) -> void:
	_reset(viewport)
	match kind:
		KIND_CCTV:
			_play_cctv(viewport)
		KIND_RULES:
			_play_rules(viewport)
		_:
			_play_approach(viewport)


func _reset(viewport: Vector2) -> void:
	for child in _stage.get_children():
		child.queue_free()
	_stage.size = viewport
	_holder.visible = false
	_holder.position = Vector2(viewport.x * 0.5, viewport.y * 0.78)
	_holder.scale = Vector2.ONE * FIGURE_START_SCALE
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)


## ① 접근 — 형광등이 터지고, 흰 섬광 순간에만 형체가 보인다.
## 검은 실루엣을 검은 화면에 계속 그리면 아무것도 안 보인다. 깜빡임과 접근을 겹친다.
func _play_approach(_viewport: Vector2) -> void:
	var approach := create_tween()
	approach.tween_interval(SILENCE_SECONDS)
	approach.tween_callback(func() -> void: _holder.visible = true)
	approach.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	approach.tween_property(_holder, "scale", Vector2.ONE * FIGURE_END_SCALE, APPROACH_SECONDS)
	# 깜빡임은 접근과 **동시에** 돈다. 별도 트윈이라야 겹친다.
	_finish_tween(create_tween(), SILENCE_SECONDS)


## ② CCTV — 채널마다 하나씩 그것이 나타나고, 마지막이 계산대다. 즉 당신 뒤.
func _play_cctv(viewport: Vector2) -> void:
	var figures := _build_cctv_grid(viewport)
	var tween := create_tween()
	tween.tween_interval(SILENCE_SECONDS)
	# 순서가 중요하다. 매대 → 창고 → 출입구 → **계산대**.
	for i in [1, 2, 3, 0]:
		tween.tween_property(figures[i], "modulate:a", 1.0, 0.26)
		tween.tween_interval(0.16)
	_finish_tween(tween)


func _build_cctv_grid(viewport: Vector2) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	var cell := Vector2(viewport.x * 0.5, viewport.y * 0.5)
	for i in 4:
		var origin := Vector2(float(i % 2) * cell.x, float(i / 2) * cell.y)
		var panel := ColorRect.new()
		panel.color = Color(0.07, 0.075, 0.075)
		panel.position = origin + Vector2(4, 4)
		panel.size = cell - Vector2(8, 8)
		_stage.add_child(panel)

		var figure := Polygon2D.new()
		figure.color = Color(0.0, 0.0, 0.0, 1.0)
		figure.polygon = silhouette(1.4)
		figure.position = origin + cell * Vector2(0.5, 0.72)
		figure.modulate.a = 0.0
		_stage.add_child(figure)
		out.append(figure)
	return out


## ③ 수칙 — 당신을 죽인 건 그것이 아니라 종이다. 줄이 하나씩 지워지고 한 줄만 남는다.
func _play_rules(viewport: Vector2) -> void:
	var paper := ColorRect.new()
	paper.color = Palette.PAPER
	paper.position = viewport * Vector2(0.18, 0.14)
	paper.size = viewport * Vector2(0.64, 0.72)
	_stage.add_child(paper)

	var lines := _build_rule_lines(paper)
	var tween := create_tween()
	tween.tween_interval(SILENCE_SECONDS)
	for line in lines:
		tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_interval(0.35)
	tween.tween_property(_final_line(paper), "modulate:a", 1.0, 0.9)
	_finish_tween(tween)


func _build_rule_lines(paper: ColorRect) -> Array[Label]:
	var out: Array[Label] = []
	for i in 6:
		var line := Palette.make_label(
			"·" + "―".repeat(18 + i % 3 * 4), Palette.SIZE_BODY, Palette.INK_MANAGER)
		line.position = Vector2(34, 40 + i * 38)
		paper.add_child(line)
		out.append(line)
	return out


func _final_line(paper: ColorRect) -> Label:
	var line := Palette.make_label(
		str(_strings.get("death.last_line", "death.last_line")),
		Palette.SIZE_HEAD, Palette.INK_MANAGER)
	line.position = Vector2(34, paper.size.y * 0.44)
	line.size = Vector2(paper.size.x - 68, 0)
	line.modulate.a = 0.0
	paper.add_child(line)
	return line


## 형광등이 터진다. 섬광은 점점 짧고 밝아지고, 어둠은 점점 깊어진다. 그리고 암전.
func _finish_tween(tween: Tween, lead_in: float = 0.0) -> Tween:
	if lead_in > 0.0:
		tween.tween_interval(lead_in)
	var step := APPROACH_SECONDS / float(FLICKER_COUNT)
	for i in FLICKER_COUNT:
		var t := float(i) / float(FLICKER_COUNT)
		tween.tween_property(_veil, "color", Color(1, 1, 1, 0.30 + t * 0.55), step * 0.22)
		tween.tween_property(_veil, "color", Color(0, 0, 0, 0.55 + t * 0.35), step * 0.78)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_veil, "color", Color(0, 0, 0, 1.0), BLACKOUT_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_callback(func() -> void: finished.emit())
	return tween


func clear() -> void:
	_holder.visible = false
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	for child in _stage.get_children():
		child.queue_free()


static func total_seconds() -> float:
	return SILENCE_SECONDS + APPROACH_SECONDS + BLACKOUT_SECONDS + HOLD_SECONDS
