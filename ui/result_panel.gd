extends PanelContainer

## 판정 직후와 밤 종료를 보여준다.
##
## 실패했을 때 **놓친 단서를 반드시 보여준다** — 공정성 불변식 3.
## 이게 "속았다"를 "알아챌 수 있었는데 놓쳤다"로 바꾸는 유일한 장치다.
## `05-prioritization.md` §4가 절대 자르지 말라고 못박은 항목이기도 하다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const RISE_DURATION := 0.26
const BUTTON_SIZE := Vector2(170, 44)

## 정상 응대는 한 줄이면 끝난다. 실패는 아니다 — **놓친 단서를 끝까지 읽게 하는 것이
## 이 패널의 존재 이유다** (공정성 불변식 3). 그래서 설명이 있을 때만 자리를 더 가져간다.
## 위쪽 행이 EXPAND_FILL이라 그만큼 줄어든다. 클립보드와 손님은 그대로 보인다.
## 정상 응대는 POS와 **같은 높이**로 둔다. 손님 대부분은 정상 응대이고,
## 그때마다 화면이 위아래로 튀면 게임이 불안해 보인다. 여백보다 안정이 낫다.
const HEIGHT_BRIEF := 182
const HEIGHT_EXPLAINED := 272

signal continued

var _strings: Dictionary = {}
var _headline: Label = null
var _detail: Label = null
var _detail_scroll: ScrollContainer = null
var _button: Button = null
var _body: VBoxContainer = null


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PANEL, Palette.PANEL_EDGE))
	# 무슨 일이 있어도 준 자리 밖으로 넘치지 않는다. 넘치면 버튼이 화면 밖으로 나간다.
	clip_contents = true
	visible = false


## **단서는 길이 제한이 없다.** 수칙이 늘수록 놓친 단서도 길어지는데 자리는 그대로다.
## 밤 4에서 단서 두 개만으로 패널이 화면 밖까지 자라 「다음 손님」 버튼이 사라졌다.
## 그래서 버튼을 글 옆에 두고, 글은 스크롤 안에 가둔다 — 세로로 쌓지 않는다.
func _build() -> void:
	if _body != null:
		return
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	_headline = Palette.make_label("", Palette.SIZE_HEAD, Palette.TEXT)
	_body.add_child(_headline)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_detail_scroll)
	_detail = Palette.make_label("", Palette.SIZE_BODY, Palette.TEXT_DIM)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail)

	_button = Button.new()
	_button.custom_minimum_size = BUTTON_SIZE
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Palette.style_button(_button, Palette.PANEL_EDGE, Palette.TEXT)
	_button.pressed.connect(_on_continue)
	row.add_child(_button)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func show_result(result: JudgeResult, button_text: String) -> void:
	_headline.text = _headline_for(result)
	# 초록(정상)도 빨강(오판)도 아니다. 맞힌 것도 틀린 것도 아닌 화면이라야 한다.
	var tone := Palette.OK if result.correct else Palette.DANGER
	_headline.add_theme_color_override(
		"font_color", Palette.ACCENT if result.had_true_conflict else tone)
	_detail.text = _detail_for(result)
	_reveal(button_text)


func show_summary(headline: String, detail: String, button_text: String) -> void:
	_headline.text = headline
	_headline.add_theme_color_override("font_color", Palette.ACCENT)
	_detail.text = detail
	_reveal(button_text)


func _reveal(button_text: String) -> void:
	_button.text = button_text
	visible = true
	custom_minimum_size = Vector2(
		0, HEIGHT_EXPLAINED if _detail.text != "" else HEIGHT_BRIEF)
	# 새 결과는 항상 맨 위부터 읽는다. 앞 손님에서 내려둔 스크롤이 남아 있으면 안 된다.
	_detail_scroll.scroll_vertical = 0
	Juice.fade_in(_body, RISE_DURATION)


func hide_panel() -> void:
	visible = false


## 참 수칙끼리 부딪히면 **어느 쪽도 오답이 아니다** (밤 6).
## 그때 「정상 응대했다」로 넘어가면 이 밤의 유일한 사건이 화면에서 사라진다.
func _headline_for(result: JudgeResult) -> String:
	if result.correct and result.had_true_conflict:
		return _t("result.either")
	if result.correct:
		return _t("result.correct")
	if result.is_trap_death():
		return _t("result.trap_grace") if result.graced else _t("result.trap")
	return _t("result.wrong")


func _detail_for(result: JudgeResult) -> String:
	if result.correct and result.had_true_conflict:
		return _t("result.either_detail")
	if result.correct:
		return ""
	# 빈 줄과 별도 머리글은 세로를 두 줄 먹는다. 그 두 줄이 단서 두 줄이다 —
	# 실패 화면에서는 설명이 여백보다 중요하다 (공정성 불변식 3).
	var lines := PackedStringArray()
	lines.append("%s   %s" % [
		_t("result.expected") % _t("ui." + result.expected[0].id()),
		_t("result.missed_header"),
	])
	for key in result.missed_clue_keys:
		lines.append("· " + _t(key))
	return "\n".join(lines)


func _on_continue() -> void:
	Juice.press(_button, 0.18)
	continued.emit()
