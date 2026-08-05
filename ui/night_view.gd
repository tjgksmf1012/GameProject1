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

const MARGIN := 44
const GAP := 16
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


## 결과는 POS 자리를 대신 쓴다. 클립보드와 손님은 계속 보여야 한다 —
## 놓친 단서를 읽으면서 수칙을 다시 대조할 수 있어야 하기 때문이다.
func swap_to_result() -> void:
	pos.visible = false
	result.custom_minimum_size = Vector2(0, POS_MIN_HEIGHT)


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
