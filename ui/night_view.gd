extends Control

## 밤 화면의 **배치**. 조각을 만들어 붙이고 참조를 들고 있는다.
## 흐름(판정 → 리플레이 → 결과)은 `main/night_screen.gd`가 맡는다.
##
## 레이아웃은 전부 코드다. 씬 파일은 루트 하나뿐이다 (CLAUDE.md 1.2).

const Palette := preload("res://ui/theme_factory.gd")
const ClipboardPanel := preload("res://ui/clipboard/clipboard_panel.gd")
const CustomerView := preload("res://ui/customer_view.gd")
const CctvMonitor := preload("res://ui/cctv/cctv_monitor.gd")
const PosTerminal := preload("res://ui/pos/pos_terminal.gd")
const ResultPanel := preload("res://ui/result_panel.gd")

## 720p에서 여백 44는 사치다. 밤 4에서 수칙 9줄 + 긴 단서가 들어오자 세로가 모자랐다.
const MARGIN := 28
const GAP := 14
const POS_MIN_HEIGHT := 182
const CLIPBOARD_RATIO := 1.35
const CCTV_MIN_WIDTH := 330

var clipboard: ClipboardPanel = null
var cctv: CctvMonitor = null
var customer_view: CustomerView = null
var pos: PosTerminal = null
var result: ResultPanel = null
var shake_target: Control = null

var _clock: Label = null
var _status: Label = null


func build(strings: Dictionary, prices: Dictionary, cctv_traits: PackedStringArray) -> void:
	# 앵커는 **트리에 붙인 뒤에** 건다. 붙기 전에 걸면 부모 크기가 0이라 아무 데도 안 늘어난다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Palette.BG
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	shake_target = VBoxContainer.new()
	shake_target.add_theme_constant_override("separation", GAP)
	add_child(shake_target)
	shake_target.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, MARGIN)

	shake_target.add_child(_build_header())
	shake_target.add_child(_build_main_row(strings, cctv_traits))
	shake_target.add_child(_build_result(strings))
	shake_target.add_child(_build_pos(strings, prices))


func _build_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_clock = Palette.make_label("", Palette.SIZE_CLOCK, Palette.ACCENT)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status = Palette.make_label("", Palette.SIZE_BODY, Palette.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_clock)
	row.add_child(_status)
	return row


func _build_main_row(strings: Dictionary, cctv_traits: PackedStringArray) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	clipboard = ClipboardPanel.new()
	clipboard.set_strings(strings)
	clipboard.size_flags_stretch_ratio = CLIPBOARD_RATIO

	cctv = CctvMonitor.new()
	cctv.set_strings(strings)
	cctv.custom_minimum_size = Vector2(CCTV_MIN_WIDTH, 0)
	cctv.size_flags_horizontal = Control.SIZE_FILL

	customer_view = CustomerView.new()
	customer_view.set_cctv_traits(cctv_traits)
	customer_view.set_strings(strings)

	row.add_child(clipboard)
	row.add_child(cctv)
	row.add_child(customer_view)
	return row


func _build_result(strings: Dictionary) -> Control:
	result = ResultPanel.new()
	result.set_strings(strings)
	return result


func _build_pos(strings: Dictionary, prices: Dictionary) -> Control:
	pos = PosTerminal.new()
	pos.custom_minimum_size = Vector2(0, POS_MIN_HEIGHT)
	pos.set_data(strings, prices)
	return pos


func set_header(clock_text: String, status_text: String) -> void:
	_clock.text = clock_text
	_status.text = status_text


## 클립보드를 지금 시점 상태로 맞춘다.
##
## 손님마다 다시 부른다 — **근무 중에 수칙이 늘어나기도 하고(밤 5) 찢겨 나가기도 한다(밤 7).**
## `show_rules`는 새 줄만 끼워 넣고 종이 소리를 낸다. 응대 중에 종이 소리가 나고
## 클립보드가 달라져 있는 것이 그 밤들의 연출이다.
func refresh_clipboard(
	engine: RuleEngine, night: int, minutes: int,
	reveal_new: bool, struck: PackedStringArray
) -> void:
	var visible := engine.visible_rules(night, minutes)
	clipboard.show_rules(visible, reveal_new)
	clipboard.show_torn(_torn_rules(engine, night, minutes))
	clipboard.apply_night(visible, night)
	clipboard.set_struck(struck)
	clipboard.reorder(_canonical_order(engine))


## 수칙이 정의된 순서. 클립보드는 늘 이 순서로 읽혀야 한다 — 찢긴 자국까지 포함해서.
static func _canonical_order(engine: RuleEngine) -> PackedStringArray:
	var out := PackedStringArray()
	for rule in engine.rules():
		out.append(rule.id)
	return out


## 이 시점에 이미 찢겨 나간 수칙들. 클립보드가 그 자리에 자국을 남긴다 (밤 7).
static func _torn_rules(engine: RuleEngine, night: int, minutes: int) -> Array[Rule]:
	var out: Array[Rule] = []
	for rule in engine.rules():
		if rule.introduced_night <= night and rule.was_removed_by(night, minutes):
			out.append(rule)
	return out


## 결과는 POS 자리를 대신 쓴다. 클립보드와 손님은 계속 보여야 한다 —
## 놓친 단서를 읽으면서 수칙을 다시 대조할 수 있어야 하기 때문이다.
## **높이는 결과 패널이 스스로 정한다** — 설명이 있으면 더 가져가야 하는데,
## 그건 여기서 알 수 없고 패널만 안다.
func swap_to_result() -> void:
	pos.visible = false


func swap_to_pos() -> void:
	result.hide_panel()
	pos.visible = true


## 3초 리플레이(F-07): 놓친 줄과 결정적 특성만 남기고 나머지를 흐린다.
func highlight_clues(rule_ids: PackedStringArray, fields: PackedStringArray, dim: float) -> void:
	clipboard.highlight(rule_ids)
	customer_view.highlight_fields(fields, dim)
	# 그림자는 CCTV에서만 보인다. 그게 결정적이었으면 모니터를 짚어줘야 한다.
	if fields.has(JudgeContext.CUSTOMER_PREFIX + "has_shadow"):
		cctv.highlight_counter(dim)


func clear_highlights() -> void:
	clipboard.clear_highlight()
	customer_view.clear_highlight()
	cctv.clear_highlight()
