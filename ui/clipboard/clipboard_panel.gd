extends PanelContainer

## 점장이 남긴 수칙. 화면에서 유일하게 따뜻한 것 — 차가운 형광등 아래 종이 한 장.
##
## **수칙마다 종이가 다르다.** 점장이 처음에 쓴 줄과 나중에 누군가 덧쓴 줄은
## 종이 색조와 잉크가 미세하게 다르다 (F-05, `shaders/paper.gdshader`).
##
## `tools/solver_audit.gd`가 확인한 대로 논리적 모순은 "둘 중 하나가 거짓"까지만 알려준다.
## **어느 쪽인지는 이 시각 단서가 말해준다.** 없으면 코어 훅은 도박이 된다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")
const PAPER_SHADER := preload("res://shaders/paper.gdshader")
const StrikeMark := preload("res://ui/clipboard/strike_mark.gd")

const RULE_SEPARATION := 7
const RISE_DURATION := 0.34
const STAGGER := 0.05
const MIN_LIST_HEIGHT := 120

# 점장의 종이 vs 나중에 덧쓴 종이. 훑으면 모르고 들여다보면 보이는 정도를 노린다.
const TONE_MANAGER := 1.0
const TONE_LATER := 0.962
const BLEED_MANAGER := 0.0
const BLEED_LATER := 0.75
# 오늘 고쳐 쓴 줄은 **훑어도 보여야 한다.** 나머지와 반대로 밝다 — 덧댄 새 종이다.
const TONE_REWRITTEN := 1.055
const DIM_ALPHA := 0.32

signal rule_added
## 플레이어가 수칙 하나를 그었다/지웠다. **믿음일 뿐이고 판정에는 영향이 없다.**
signal strike_toggled(rule_id: String)

var _list: VBoxContainer = null
var _strings: Dictionary = {}
var _shown_ids: PackedStringArray = []
var _rows: Dictionary = {}
var _labels: Dictionary = {}
var _strikes: Dictionary = {}


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PAPER, Palette.PAPER_EDGE))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build() -> void:
	if _list != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", RULE_SEPARATION)
	add_child(box)

	box.add_child(Palette.make_label(_t("ui.clipboard_header"), Palette.SIZE_HEAD, Palette.PAPER_TEXT))
	box.add_child(_divider())

	# 스크롤이 있어야 수칙이 늘어나도 화면이 안 무너진다 (F-05).
	# 부수 효과가 더 중요하다 — 최소 높이가 작아져서 결과 패널이 들어갈 자리가 난다.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, MIN_LIST_HEIGHT)
	box.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", RULE_SEPARATION)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Palette.PAPER_EDGE
	line.custom_minimum_size = Vector2(0, 1)
	return line


## 새 수칙만 골라 끼워 넣는다. 이미 붙어 있던 줄은 다시 애니메이션하지 않는다.
func show_rules(rules: Array[Rule]) -> void:
	var added := 0
	for rule in rules:
		if _shown_ids.has(rule.id):
			continue
		_shown_ids.append(rule.id)
		var row := _make_row(rule, _shown_ids.size() - 1)
		_list.add_child(row)
		_rows[rule.id] = row
		Juice.fade_in(row, RISE_DURATION, added * STAGGER)
		added += 1
	if added > 0:
		rule_added.emit()


func _make_row(rule: Rule, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(rule.id))
	var label := Palette.make_label("· " + _t(rule.text_key), Palette.SIZE_BODY, Palette.INK_MANAGER)
	row.add_child(label)
	_labels[rule.id] = label

	_strikes[rule.id] = StrikeMark.attach(label)
	return row


## 클릭하면 긋고, 다시 클릭하면 지운다. **표시일 뿐 판정은 바뀌지 않는다.**
## 밤 4에서 수칙이 아홉 줄이 된다. 어느 줄을 거짓으로 결론 냈는지 머리로 들고 있으라고 하면
## 그건 추론 게임이 아니라 기억력 게임이다.
func _on_row_input(event: InputEvent, rule_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	strike_toggled.emit(rule_id)


## 밤을 새로 열 때는 이미 그어져 있던 줄을 **애니메이션 없이** 되살린다.
## 밤이 시작되자마자 펜이 저절로 움직이면 누가 긋는 것처럼 보인다.
func set_struck(rule_ids: PackedStringArray, animate_id: String = "") -> void:
	for id in _strikes:
		var mark: Node2D = _strikes[id]
		if rule_ids.has(id):
			mark.show_stroke(str(id) == animate_id)
		else:
			mark.hide_stroke()


## 밤마다 줄의 종이와 잉크를 다시 칠한다.
## **전환된 수칙은 그 밤부터 고쳐 쓴 자국이 남는다** — 안 보이면 "속았다"가 된다.
func apply_night(rules: Array[Rule], night: int) -> void:
	for i in rules.size():
		var rule := rules[i]
		if not _rows.has(rule.id):
			continue
		var foreign := rule.hand_at(night) != Rule.HAND_MANAGER
		var rewritten := rule.has_decayed_by(night)
		(_rows[rule.id] as PanelContainer).material = _paper_material(foreign, rewritten, i)
		var label: Label = _labels[rule.id]
		label.add_theme_color_override(
			"font_color", Palette.INK_LATER if foreign else Palette.INK_MANAGER)
		# 고쳐 쓴 줄에는 표식이 남는다. 잉크 색만으로는 눈에 안 들어온다.
		label.text = ("✎ " if rewritten else "· ") + _t(rule.text_key)


static func _row_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


func _paper_material(foreign: bool, rewritten: bool, index: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAPER_SHADER
	var tone := TONE_LATER if foreign else TONE_MANAGER
	material.set_shader_parameter("paper_tone", TONE_REWRITTEN if rewritten else tone)
	material.set_shader_parameter("ink_bleed", BLEED_LATER if foreign else BLEED_MANAGER)
	material.set_shader_parameter("rewritten", 1.0 if rewritten else 0.0)
	# 줄마다 섬유가 달라야 종이 두 장이 똑같아 보이지 않는다.
	material.set_shader_parameter("fiber_seed", float(index) * 37.0 + 11.0)
	return material


## 특정 수칙만 남기고 나머지를 흐린다. 3초 리플레이(F-07)에서 놓친 줄을 짚어줄 때 쓴다.
func highlight(rule_ids: PackedStringArray) -> void:
	for id in _rows:
		var row: PanelContainer = _rows[id]
		row.modulate = Color.WHITE if rule_ids.has(id) else Color(1.0, 1.0, 1.0, DIM_ALPHA)


func clear_highlight() -> void:
	for id in _rows:
		(_rows[id] as PanelContainer).modulate = Color.WHITE
