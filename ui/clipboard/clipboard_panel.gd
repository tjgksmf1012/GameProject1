extends PanelContainer

## 점장이 남긴 수칙. 화면에서 유일하게 따뜻한 것 — 차가운 형광등 아래 종이 한 장.
##
## 거짓 수칙의 시각 차이(필체·잉크·종이 색조)는 F-05의 M2 항목이다.
## M1은 텍스트 규약으로 버틴다: 참 수칙은 명령만 하고, 거짓 수칙은 이유를 댄다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const RULE_SEPARATION := 14
const RISE_DURATION := 0.34
const STAGGER := 0.05
const MIN_LIST_HEIGHT := 120

signal rule_added

var _list: VBoxContainer = null
var _strings: Dictionary = {}
var _shown_ids: PackedStringArray = []


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
		var label := Palette.make_label("· " + _t(rule.text_key), Palette.SIZE_BODY, Palette.PAPER_TEXT)
		_list.add_child(label)
		Juice.fade_in(label, RISE_DURATION, added * STAGGER)
		added += 1
	if added > 0:
		rule_added.emit()
