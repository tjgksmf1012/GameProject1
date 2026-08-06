extends PanelContainer

## 창밖 실루엣과 카운터 앞의 손님.
##
## `보이는 것` 목록은 공정성 불변식 1을 화면으로 옮긴 부분이다 —
## 손님의 모든 특성을 빠짐없이 보여준다. 숨겨진 스탯은 존재하지 않는다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const SILHOUETTE_HEIGHT := 78
const FIGURE_DESIGN_HEIGHT := 96.0
const RISE_DURATION := 0.3
const PRESSURE_FADE := 0.5

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


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PANEL, Palette.PANEL_EDGE))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _build() -> void:
	if _body != null:
		return
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	add_child(_body)

	_silhouette = _make_silhouette()
	_body.add_child(_silhouette)
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
## **도형은 홀더 높이에 맞춰 그린다.** 높이만 줄이면 발이 잘린다 — 실제로 그랬다.
func _make_silhouette() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, SILHOUETTE_HEIGHT)
	var polygon := Polygon2D.new()
	polygon.color = Color(0.0, 0.0, 0.0, 0.85)
	polygon.polygon = _figure(float(SILHOUETTE_HEIGHT) / FIGURE_DESIGN_HEIGHT)
	holder.add_child(polygon)
	return holder


## 원래 96픽셀 높이로 잡은 형상. 배율만 곱해 다시 쓴다.
static func _figure(scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in [
		Vector2(28, 96), Vector2(28, 44), Vector2(36, 30),
		Vector2(34, 18), Vector2(46, 8), Vector2(58, 18),
		Vector2(56, 30), Vector2(64, 44), Vector2(64, 96),
	]:
		out.append(Vector2(p.x, p.y * scale))
	return out


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
