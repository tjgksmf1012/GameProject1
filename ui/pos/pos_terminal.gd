extends PanelContainer

## POS 단말. 조작의 중심 (04-functional-spec F-03).
##
## **파는 것은 일이고, 거부는 즉시다.** 판매하려면 품목을 전부 찍고 주류면 신분 확인까지
## 해야 하지만, 거부는 언제든 한 번에 된다. 이 비대칭이 "그냥 다 거부해버릴까"라는
## 유혹을 만든다. 그게 이 게임의 압박이다.
##
## 이 게이트는 전부 UI 층에 있다. 판정의 정오답은 여전히 `systems/rules/`가 정한다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")
const ReceiptSlip := preload("res://ui/pos/receipt_slip.gd")
const ProductGlyph := preload("res://ui/art/product_glyph.gd")

const PRESS_DURATION := 0.18
const SCAN_REBOUND_SECONDS := 0.24

signal verdict_chosen(kind: String)
signal item_scanned
signal id_checked

var _strings: Dictionary = {}
var _prices: Dictionary = {}

var _scan_row: HBoxContainer = null
var _receipt: ReceiptSlip = null
var _id_button: Button = null
var _serve_button: Button = null
var _refuse_button: Button = null

var _pending: PackedStringArray = []
var _scanned: PackedStringArray = []
var _needs_id: bool = false
var _id_done: bool = false
var _locked: bool = false


func _init() -> void:
	# 여기는 벽이 아니라 **계산대 상판**이다. 다른 패널보다 밝게 둬서 손이 닿는 자리로 읽히게 한다.
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.COUNTER, Palette.COUNTER_EDGE))


## 문자열이 있어야 라벨을 만들 수 있으므로, 화면 구성을 여기서 한다.
## `_ready()`에 두면 트리 진입 시점에 의존하게 되고 테스트에서 깨진다.
func set_data(strings: Dictionary, prices: Dictionary) -> void:
	_strings = strings
	_prices = prices
	_build()


func _build() -> void:
	if _scan_row != null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)
	row.add_child(_build_scan_column())
	row.add_child(_build_receipt_column())
	row.add_child(_build_verdict_column())


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _build_scan_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(Palette.make_label(_t("ui.scan_header"), Palette.SIZE_SMALL, Palette.SECTION))
	_scan_row = HBoxContainer.new()
	_scan_row.add_theme_constant_override("separation", 8)
	column.add_child(_scan_row)
	return column


## 영수증은 이제 라벨이 아니라 **종이**다 (ui/pos/receipt_slip.gd).
func _build_receipt_column() -> Control:
	_receipt = ReceiptSlip.new()
	_receipt.setup(_strings)
	return _receipt


func _build_verdict_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_id_button = _make_button(_t("ui.id_check"), Palette.PANEL_EDGE, Palette.TEXT)
	_id_button.pressed.connect(_on_id_pressed)
	_serve_button = _make_button(_t("ui.serve"), Palette.OK.darkened(0.45), Palette.TEXT)
	_serve_button.pressed.connect(_on_verdict_pressed.bind(Verdict.SERVE))
	_refuse_button = _make_button(_t("ui.refuse"), Palette.DANGER.darkened(0.4), Palette.TEXT)
	_refuse_button.pressed.connect(_on_verdict_pressed.bind(Verdict.REFUSE))
	column.add_child(_id_button)
	column.add_child(_serve_button)
	column.add_child(_refuse_button)
	return column


func _make_button(text: String, tint: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 46)
	Palette.style_button(button, tint, text_color)
	return button


## 새 손님이 카운터에 물건을 올린다.
func present(customer: Customer) -> void:
	_pending = customer.item_keys.duplicate()
	_scanned = PackedStringArray()
	_needs_id = bool(customer.get_trait("wants_alcohol"))
	_id_done = false
	_locked = false
	_rebuild_scan_buttons()
	_refresh()
	# **패드·키보드에는 출발점이 필요하다.** 아무것도 포커스를 안 잡고 있으면 방향키를
	# 눌러도 아무 일이 없고, 플레이어는 조작이 안 되는 줄 안다. 마우스는 영향 없다.
	_first_focus().grab_focus()


## 이 손님에게 처음 손이 갈 곳. 찍을 것이 있으면 첫 품목, 없으면 거부(항상 누를 수 있다).
func _first_focus() -> Button:
	if _scan_row.get_child_count() > 0:
		return _scan_row.get_child(0) as Button
	return _refuse_button


func lock() -> void:
	_locked = true
	_refresh()


func is_locked() -> bool:
	return _locked


func _rebuild_scan_buttons() -> void:
	for child in _scan_row.get_children():
		# **트리에서 먼저 빼야 한다.** `queue_free()`만 하면 이번 프레임 끝까지 자식으로 남아
		# 바로 뒤의 `get_child(0)`이 **곧 사라질 버튼**을 돌려준다. 거기에 포커스를 줘봐야
		# 그 버튼과 함께 사라져서, 패드로는 출발점이 아예 안 잡혔다.
		_scan_row.remove_child(child)
		child.queue_free()
	for key in _pending:
		var button := _make_item_button(key)
		button.pressed.connect(_on_scan_pressed.bind(key, button))
		_scan_row.add_child(button)


## 이름은 Button.text에 그대로 둔다. 아이콘은 장식이라 포커스와 클릭을 가로채지 않는다.
func _make_item_button(key: String) -> Button:
	var button := _make_button(_t(key), Palette.PANEL_EDGE, Palette.TEXT)
	button.custom_minimum_size = Vector2(168, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var glyph := ProductGlyph.new()
	glyph.set_item_key(key)
	button.add_child(glyph)
	glyph.set_anchor(SIDE_TOP, 0.5)
	glyph.set_anchor(SIDE_BOTTOM, 0.5)
	glyph.offset_left = 10.0
	glyph.offset_top = -16.0
	glyph.offset_right = 42.0
	glyph.offset_bottom = 16.0
	return button


## 품목 하나를 찍는다. 실제로 찍혔으면 true.
func scan(key: String) -> bool:
	if _locked or _scanned.has(key) or not _pending.has(key):
		return false
	_scanned.append(key)
	item_scanned.emit()
	_refresh(true)
	return true


## 신분을 확인한다. 실제로 확인됐으면 true.
func check_id() -> bool:
	if _locked or _id_done or not _needs_id:
		return false
	_id_done = true
	id_checked.emit()
	_refresh()
	return true


func _on_scan_pressed(key: String, button: Button) -> void:
	if not scan(key):
		return
	Juice.rebound(button, SCAN_REBOUND_SECONDS)
	button.disabled = true


func _on_id_pressed() -> void:
	if not check_id():
		return
	Juice.press(_id_button, PRESS_DURATION)


func _on_verdict_pressed(kind: String) -> void:
	if _locked:
		return
	var button := _serve_button if kind == Verdict.SERVE else _refuse_button
	Juice.press(button, PRESS_DURATION)
	verdict_chosen.emit(kind)


## 모든 품목을 찍었고, 주류면 신분 확인까지 끝났는가.
func can_serve() -> bool:
	if _scanned.size() < _pending.size():
		return false
	return _id_done or not _needs_id


func _refresh(grew: bool = false) -> void:
	_receipt.print_lines(_receipt_items(), _format_won(_total_price()), grew)
	_id_button.disabled = _locked or _id_done or not _needs_id
	_serve_button.disabled = _locked or not can_serve()
	_refuse_button.disabled = _locked


func _receipt_items() -> Array:
	var out := []
	for key in _scanned:
		out.append({"name": _t(key), "price": _format_won(_price_of(key))})
	return out


func _total_price() -> int:
	var sum := 0
	for key in _scanned:
		sum += _price_of(key)
	return sum


func _price_of(key: String) -> int:
	return int(_prices.get(key, 0))


static func _format_won(amount: int) -> String:
	var digits := str(amount)
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += ","
		grouped += digits[i]
	return "₩" + grouped
