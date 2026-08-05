extends PanelContainer

## 판정 직후와 밤 종료를 보여준다.
##
## 실패했을 때 **놓친 단서를 반드시 보여준다** — 공정성 불변식 3.
## 이게 "속았다"를 "알아챌 수 있었는데 놓쳤다"로 바꾸는 유일한 장치다.
## `05-prioritization.md` §4가 절대 자르지 말라고 못박은 항목이기도 하다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const RISE_DURATION := 0.26

signal continued

var _strings: Dictionary = {}
var _headline: Label = null
var _detail: Label = null
var _button: Button = null
var _body: VBoxContainer = null


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PANEL, Palette.PANEL_EDGE))
	visible = false


func _build() -> void:
	if _body != null:
		return
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)
	_headline = Palette.make_label("", Palette.SIZE_HEAD, Palette.TEXT)
	_body.add_child(_headline)
	_detail = Palette.make_label("", Palette.SIZE_BODY, Palette.TEXT_DIM)
	_body.add_child(_detail)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(170, 44)
	Palette.style_button(_button, Palette.PANEL_EDGE, Palette.TEXT)
	_button.pressed.connect(_on_continue)
	_body.add_child(_button)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func show_result(result: JudgeResult, button_text: String) -> void:
	_headline.text = _headline_for(result)
	_headline.add_theme_color_override("font_color", Palette.OK if result.correct else Palette.DANGER)
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
	Juice.fade_in(_body, RISE_DURATION)


func hide_panel() -> void:
	visible = false


func _headline_for(result: JudgeResult) -> String:
	if result.correct:
		return _t("result.correct")
	if result.is_trap_death():
		return _t("result.trap_grace") if result.graced else _t("result.trap")
	return _t("result.wrong")


func _detail_for(result: JudgeResult) -> String:
	if result.correct:
		return ""
	var lines := PackedStringArray()
	lines.append(_t("result.expected") % _t("ui." + result.expected[0].id()))
	lines.append("")
	lines.append(_t("result.missed_header"))
	for key in result.missed_clue_keys:
		lines.append("· " + _t(key))
	return "\n".join(lines)


func _on_continue() -> void:
	Juice.press(_button, 0.18)
	continued.emit()
