extends PanelContainer

## 창밖 실루엣과 카운터 앞의 손님.
##
## `보이는 것` 목록은 공정성 불변식 1을 화면으로 옮긴 부분이다 —
## 손님의 모든 특성을 빠짐없이 보여준다. 숨겨진 스탯은 존재하지 않는다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")
const CustomerFigure := preload("res://ui/art/customer_figure.gd")

const RISE_DURATION := 0.3
const PRESSURE_FADE := 0.5
## 마지막 단계에서만 테두리가 맥동한다.
##
## 첫 단계에는 일부러 아무것도 안 한다. 읽기 부하를 재보니 **처음 보는 사람은 밤 1부터
## 다 읽기 전에 재촉을 받는다**(문턱의 2.13배). 늘 켜져 있는 신호는 신호가 아니다.
const PULSE_SECONDS := 0.7
const PULSE_TINT := Color("8a5a2a")

## 단계별 문구. 손님이 누구든 **똑같다** — `PatienceClock` 주석 참고.
const PRESSURE_KEYS := {
	PatienceClock.STAGE_URGING: "pressure.urging",
	PatienceClock.STAGE_DEMANDING: "pressure.demanding",
}

var _strings: Dictionary = {}
var _figure: CustomerFigure = null
var _name: Label = null
var _dialogue: Label = null
var _pressure: Label = null
var _traits: VBoxContainer = null
var _body: VBoxContainer = null
var _trait_rows: Dictionary = {}
var _cctv_traits: PackedStringArray = []
var _stage: int = PatienceClock.STAGE_CALM
var _edge: StyleBoxFlat = null
var _pulse: Tween = null


func _init() -> void:
	# 맥동시키려면 스타일박스를 들고 있어야 한다. 테마에서 다시 꺼내오면 공유본이라
	# 다른 패널까지 같이 깜빡인다.
	_edge = Palette.panel_style(Palette.PANEL, Palette.PANEL_EDGE)
	add_theme_stylebox_override("panel", _edge)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _build() -> void:
	if _body != null:
		return
	# **뒤에 먼저 깔고** 그 위에 글자를 얹는다. 자식 순서가 곧 그리는 순서다.
	_figure = CustomerFigure.new()
	add_child(_figure)

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


func show_customer(customer: Customer) -> void:
	set_pressure_stage(PatienceClock.STAGE_CALM)
	_figure.show_customer(
		customer.id, bool(customer.get_trait("has_bag")),
		bool(customer.get_trait("hides_face")), bool(customer.get_trait("is_wet")),
		customer.item_keys)
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
	_stage = stage
	if _figure != null:
		_figure.set_pressure_stage(stage)
	_set_pulse(stage == PatienceClock.STAGE_DEMANDING)
	if not PRESSURE_KEYS.has(stage):
		_pressure.modulate.a = 0.0
		return
	_pressure.text = _t(str(PRESSURE_KEYS[stage]))
	Juice.fade_in(_pressure, PRESSURE_FADE)


## 테두리가 천천히 밝아졌다 꺼진다. 손님이 카운터를 두드리는 것과 같은 박자다.
func _set_pulse(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_edge.border_color = Palette.PANEL_EDGE
	if not on:
		return
	_pulse = create_tween().set_loops()
	_pulse.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_edge, "border_color", PULSE_TINT, PULSE_SECONDS)
	_pulse.tween_property(_edge, "border_color", Palette.PANEL_EDGE, PULSE_SECONDS)


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
