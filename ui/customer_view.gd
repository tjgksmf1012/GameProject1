extends PanelContainer

## 창밖 실루엣과 카운터 앞의 손님.
##
## `보이는 것` 목록은 공정성 불변식 1을 화면으로 옮긴 부분이다 —
## 손님의 모든 특성을 빠짐없이 보여준다. 숨겨진 스탯은 존재하지 않는다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const FIGURE_DESIGN_HEIGHT := 96.0
## FIGURE_POINTS 의 x 한가운데. **폭이 아니라 중심**이다 —
## 점 좌표에 이미 x 오프셋(30~62)이 들어 있어서 폭으로 빼면 형상이 그만큼 밀린다.
## 실제로 밀려서 화면 밖으로 잘렸다.
const FIGURE_DESIGN_CENTER_X := 46.0
const RISE_DURATION := 0.3
const PRESSURE_FADE := 0.5

## 실루엣이 패널 높이의 몇 할을 차지하는가.
##
## 예전에는 78px 고정이었다. 363px 폭 패널 구석에 60x78 아이콘이 검정으로 그려져 있었고,
## 바탕이 #16191b라 **거의 안 보였다.** 이 게임의 주인공이 화면에서 가장 작았다.
##
## 세로로 쌓아서 키울 수는 없다 — 손님 패널의 최소 높이가 곧 화면 전체의 최소 높이라서
## 250px짜리를 목록 위에 얹으면 배치가 넘친다(실측: 571 > 390). 그래서 **뒤에 깐다.**
## 자리를 차지하지 않으므로 배치에 영향이 없고, 글자는 그 위에 얹힌다.
const FIGURE_FILL := 0.80
## 오른쪽으로 밀어 글자와 겹치는 면적을 줄인다. 0.5면 한가운데.
const FIGURE_ANCHOR_X := 0.74
## 숨. 정지한 실루엣은 아이콘이고, 미세하게 움직이면 사람이다.
const BREATH_PIXELS := 2.6
const BREATH_SECONDS := 4.2
## 뒤쪽 매대. 실루엣은 **대비할 것이 있어야** 실루엣이다.
const SHELF_COUNT := 3
const SHELF_TONE := Color("1d2325")

## 단계별 문구. 손님이 누구든 **똑같다** — `PatienceClock` 주석 참고.
const PRESSURE_KEYS := {
	PatienceClock.STAGE_URGING: "pressure.urging",
	PatienceClock.STAGE_DEMANDING: "pressure.demanding",
}

var _strings: Dictionary = {}
var _silhouette: Control = null
var _name: Label = null
var _dialogue: Label = null
var _pressure: Label = null
var _traits: VBoxContainer = null
var _body: VBoxContainer = null
var _trait_rows: Dictionary = {}
var _cctv_traits: PackedStringArray = []
var _figure_poly: Polygon2D = null
var _breath: float = 0.0


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PANEL, Palette.PANEL_EDGE))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _build() -> void:
	if _body != null:
		return
	# **뒤에 먼저 깔고** 그 위에 글자를 얹는다. 자식 순서가 곧 그리는 순서다.
	_silhouette = _make_silhouette()
	add_child(_silhouette)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	add_child(_body)

	_name = Palette.make_label("", Palette.SIZE_HEAD, Palette.TEXT)
	_body.add_child(_name)
	_dialogue = Palette.make_label("", Palette.SIZE_BODY, Palette.TEXT_DIM)
	_body.add_child(_dialogue)
	# 재촉하는 말은 처음 대사와 **다른 색**이라야 새로 한 말로 읽힌다.
	_pressure = Palette.make_label("", Palette.SIZE_BODY, Palette.ACCENT)
	_pressure.modulate.a = 0.0
	_body.add_child(_pressure)
	_body.add_child(Palette.make_label(_t("ui.observation_header"), Palette.SIZE_SMALL, Palette.SECTION))
	_traits = VBoxContainer.new()
	_traits.add_theme_constant_override("separation", 4)
	_body.add_child(_traits)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


## CCTV가 담당하는 특성은 여기서 빼고 보여준다. 두 곳에 그리면 CCTV가 장식이 된다.
func set_cctv_traits(names: PackedStringArray) -> void:
	_cctv_traits = names


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


## 창밖 실루엣. 이미지가 아니라 절차적 도형이다 (CLAUDE.md 1.1).
##
## 패널 전체를 덮는 배경판이다. 매대 몇 줄을 먼저 깔고 그 앞에 사람을 세운다 —
## **검정을 어두운 바탕에 그리면 실루엣이 아니라 얼룩이다.**
func _make_silhouette() -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	for i in SHELF_COUNT:
		holder.add_child(_make_shelf(i))
	_figure_poly = Polygon2D.new()
	_figure_poly.color = Color(0.0, 0.0, 0.0, 0.92)
	holder.add_child(_figure_poly)
	holder.resized.connect(_fit_figure.bind(holder))
	return holder


## 뒤쪽 매대. 사람이 서 있을 자리보다 밝아야 형상이 잘린다.
func _make_shelf(index: int) -> ColorRect:
	var shelf := ColorRect.new()
	shelf.color = SHELF_TONE
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shelf.anchor_left = 0.06 + float(index) * 0.30
	shelf.anchor_right = shelf.anchor_left + 0.20
	shelf.anchor_top = 0.30 + float(index % 2) * 0.08
	shelf.anchor_bottom = 1.0
	shelf.offset_left = 0.0
	shelf.offset_right = 0.0
	shelf.offset_top = 0.0
	shelf.offset_bottom = 0.0
	return shelf


## 패널 크기가 정해진 뒤에 형상을 그 높이에 맞춘다.
## **발이 바닥에 닿아야 한다** — 예전에 홀더만 줄였다가 발이 잘린 적이 있다.
func _fit_figure(holder: Control) -> void:
	if _figure_poly == null or holder.size.y <= 0.0:
		return
	var scale := holder.size.y * FIGURE_FILL / FIGURE_DESIGN_HEIGHT
	_figure_poly.polygon = _figure(scale)
	_figure_poly.position = Vector2(
		holder.size.x * FIGURE_ANCHOR_X - FIGURE_DESIGN_CENTER_X * scale,
		holder.size.y - FIGURE_DESIGN_HEIGHT * scale)


## 96픽셀 높이로 잡은 형상. 배율만 곱해 다시 쓴다.
##
## 점이 많은 이유: 예전 9각형은 78px에서만 사람으로 읽혔다. 300px로 키우니 목도 어깨도
## 없는 **기둥**이 됐다. 크기를 바꾸면 필요한 해상도도 바뀐다.
## 머리는 전체 높이의 약 1/7 — 그보다 크면 만화, 작으면 사람으로 안 읽힌다.
const FIGURE_POINTS := [
	Vector2(33, 96), Vector2(31, 58), Vector2(30, 34),   # 왼쪽 몸통
	Vector2(36, 26), Vector2(42, 22), Vector2(41, 17),   # 왼쪽 어깨 · 목
	Vector2(40, 13), Vector2(42, 8), Vector2(46, 6),     # 머리 왼쪽
	Vector2(50, 8), Vector2(52, 13), Vector2(51, 17),    # 머리 오른쪽
	Vector2(50, 22), Vector2(56, 26), Vector2(62, 34),   # 오른쪽 목 · 어깨
	Vector2(61, 58), Vector2(59, 96),                    # 오른쪽 몸통
]


static func _figure(scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in FIGURE_POINTS:
		out.append((point as Vector2) * scale)
	return out


## 숨. 아주 작게 — 알아채면 안 되고, 없으면 아이콘으로 보인다.
func _process(delta: float) -> void:
	if _figure_poly == null:
		return
	_breath = fposmod(_breath + delta, BREATH_SECONDS)
	var phase := sin(_breath / BREATH_SECONDS * TAU)
	_figure_poly.skew = phase * 0.004
	_figure_poly.offset = Vector2(0.0, phase * BREATH_PIXELS)


func show_customer(customer: Customer) -> void:
	_name.text = _t(customer.name_key)
	_dialogue.text = _dialogue_text(customer)
	_pressure.text = ""
	_pressure.modulate.a = 0.0
	_fill_traits(customer)
	Juice.fade_in(_body, RISE_DURATION)


## 손님이 오래 기다렸다. 단계가 바뀐 순간에만 부른다.
##
## 문구는 손님마다 다르지 않다. **이상 손님만 다르게 굴면 플레이어는 관찰 대신
## 기다리기로 푼다** — CCTV도 클립보드도 필요 없어진다 (PatienceClock 주석).
func set_pressure_stage(stage: int) -> void:
	if not PRESSURE_KEYS.has(stage):
		_pressure.modulate.a = 0.0
		return
	_pressure.text = _t(str(PRESSURE_KEYS[stage]))
	Juice.fade_in(_pressure, PRESSURE_FADE)


func _dialogue_text(customer: Customer) -> String:
	var lines := PackedStringArray()
	for key in customer.dialogue_keys:
		lines.append("\"%s\"" % _t(key))
	return "\n".join(lines)


func _fill_traits(customer: Customer) -> void:
	for child in _traits.get_children():
		child.queue_free()
	_trait_rows.clear()
	for name in customer.trait_names():
		if _cctv_traits.has(name):
			continue
		# 있고 없음은 표식(●/○)만으로 나타낸다. **색으로 나타내면 안 된다.**
		# 없는 특성을 흐리게 그리면 "그림자 없음" 같은 가장 중요한 단서가 가장 안 보이게 되고,
		# 3초 리플레이의 흐림과도 충돌해 무엇이 강조된 건지 구분이 안 된다.
		var mark := "●" if bool(customer.get_trait(name)) else "○"
		var row := Palette.make_label(
			"%s  %s" % [mark, _t("trait." + name)], Palette.SIZE_BODY, Palette.TEXT)
		_traits.add_child(row)
		_trait_rows[JudgeContext.CUSTOMER_PREFIX + name] = row


## 3초 리플레이(F-07)에서 결정적이었던 특성만 남기고 나머지를 흐린다.
func highlight_fields(fields: PackedStringArray, dim: float) -> void:
	for path in _trait_rows:
		var row: Label = _trait_rows[path]
		row.modulate = Color.WHITE if fields.has(path) else Color(1.0, 1.0, 1.0, dim)


func clear_highlight() -> void:
	for path in _trait_rows:
		(_trait_rows[path] as Label).modulate = Color.WHITE
