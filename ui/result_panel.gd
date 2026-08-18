extends PanelContainer

## 판정 직후와 밤 종료를 보여준다.
##
## 실패했을 때 **놓친 단서를 반드시 보여준다** — 공정성 불변식 3.
## 이게 "속았다"를 "알아챌 수 있었는데 놓쳤다"로 바꾸는 유일한 장치다.
## `05-prioritization.md` §4가 절대 자르지 말라고 못박은 항목이기도 하다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")
const DecisionStamp := preload("res://ui/art/decision_stamp.gd")

const RISE_DURATION := 0.26
const BUTTON_SIZE := Vector2(170, 44)
## 배치가 돌 때까지 높이 재기를 몇 프레임 따라가는가.
const FIT_FRAMES := 4

## 정상 응대는 한 줄이면 끝난다. 실패는 아니다 — **놓친 단서를 끝까지 읽게 하는 것이
## 이 패널의 존재 이유다** (공정성 불변식 3). 그래서 설명이 있을 때만 자리를 더 가져간다.
## 위쪽 행이 EXPAND_FILL이라 그만큼 줄어든다. 클립보드와 손님은 그대로 보인다.
## 정상 응대는 POS와 **같은 높이**로 둔다. 손님 대부분은 정상 응대이고,
## 그때마다 화면이 위아래로 튀면 게임이 불안해 보인다. 여백보다 안정이 낫다.
##
## 실패는 이 둘 **사이 어디든** 될 수 있다. 예전에는 설명이 있으면 무조건 272였고,
## 단서가 한 줄뿐인 흔한 실패에서 패널 아래 150px가 통째로 비었다 — 판정 직후는
## 이 게임의 감정적 정점인데 화면 아래 40%가 빈 상자였다. 그렇다고 자유롭게 늘리면
## 밤 4에서 그랬듯 버튼이 화면 밖으로 나간다. 그래서 **내용에 맞추되 위아래로 가둔다.**
const HEIGHT_BRIEF := 182
const HEIGHT_EXPLAINED := 272

signal continued

var _strings: Dictionary = {}
var _headline: Label = null
var _detail: Label = null
var _detail_scroll: ScrollContainer = null
var _button: Button = null
var _body: VBoxContainer = null
var _stamp: DecisionStamp = null
## 높이를 재려고 남은 프레임 수 (`_process` 참고).
var _fit_frames: int = 0
## 이번 결과에서 잰 높이 중 가장 큰 것.
var _fit_wanted: float = 0.0


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
	_stamp = DecisionStamp.new()
	add_child(_stamp)
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
	# 오답의 근거는 장식 문구가 아니라 다음 판정을 위한 핵심 피드백이다.
	# 어두운 결과 패널에서도 본문 대비를 유지한다.
	_detail = Palette.make_label("", Palette.SIZE_BODY, Palette.TEXT)
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
	_stamp.show_decision(result.correct)
	_headline.text = _headline_for(result)
	# 초록(정상)도 빨강(오판)도 아니다. 맞힌 것도 틀린 것도 아닌 화면이라야 한다.
	var tone := Palette.OK if result.correct else Palette.DANGER
	_headline.add_theme_color_override(
		"font_color", Palette.ACCENT if result.had_true_conflict else tone)
	_detail.text = _detail_for(result)
	_reveal(button_text)


func show_summary(headline: String, detail: String, button_text: String) -> void:
	_stamp.clear()
	_headline.text = headline
	_headline.add_theme_color_override("font_color", Palette.ACCENT)
	_detail.text = detail
	_reveal(button_text)


func _reveal(button_text: String) -> void:
	_button.text = button_text
	visible = true
	# 일단 최대로 잡아 **줄바꿈이 잘리지 않은 상태**에서 재게 한다. 좁게 잡아두고 재면
	# 스크롤이 글을 감춘 채로 "짧다"고 답한다.
	custom_minimum_size = Vector2(
		0, HEIGHT_EXPLAINED if _detail.text != "" else HEIGHT_BRIEF)
	# 새 결과는 항상 맨 위부터 읽는다. 앞 손님에서 내려둔 스크롤이 남아 있으면 안 된다.
	_detail_scroll.scroll_vertical = 0
	# **패드 루프를 닫는다.** 판정하면 POS가 숨겨지고 그 위에 있던 포커스도 같이 사라진다.
	# 여기서 안 잡아주면 화면에 누를 수 있는 것이 이 버튼 하나뿐인데 아무것도 선택돼 있지
	# 않아, 패드 플레이어는 첫 판정에서 멈춘다.
	_button.grab_focus()
	_fit_wanted = 0.0
	_fit_frames = FIT_FRAMES if _detail.text != "" else 0
	set_process(_fit_frames > 0)
	Juice.fade_in(_body, RISE_DURATION)


## 배치가 끝난 뒤에 재려고 몇 프레임 따라간다.
##
## 신호로 잡으려다 두 번 틀렸다. `call_deferred`는 너무 일러서 폭이 1px일 때 재고
## (두 줄짜리 글이 135줄로 나왔다), `_detail.resized`는 **폭이 안 바뀌면 안 온다** —
## 둘째 손님부터 신호가 없어 첫 손님만 고쳐지고 있었다. 프레임을 세는 쪽이 정직하다.
func _process(_delta: float) -> void:
	_fit_frames -= 1
	_fit_to_content()
	if _fit_frames <= 0:
		set_process(false)


## 설명 길이에 맞춰 패널을 줄인다.
##
## 단서가 여러 줄이면 272를 다 쓰고 넘치면 스크롤한다. 한 줄이면 182로 줄어
## 아래 90px가 위쪽 행으로 돌아간다 — 빈 상자 대신 클립보드가 그만큼 더 보인다.
##
## **폭이 정해진 뒤라야 줄 수를 알 수 있다.** 아직이면 그냥 돌아가고 다음 프레임에 다시 온다.
##
## 잰 값 중 **가장 큰 것**을 쓴다. 줄이면 스크롤 막대가 생기고, 막대가 생기면 글이 좁아져
## 줄 수가 늘고, 그러면 아까 잰 높이로는 마지막 줄이 잘린다. 실제로 잘렸다 —
## 「일곱. 얼굴을 볼 수 없는 손님에게는」 이 반쯤 잘린 채로 화면에 남았고,
## **그 줄이 바로 공정성 불변식 3이 지키라는 놓친 단서다.** 남는 자리보다 잘린 단서가 나쁘다.
func _fit_to_content() -> void:
	if not visible or _detail.size.x <= 1.0:
		return
	var box := get_theme_stylebox("panel") as StyleBoxFlat
	var padding := box.content_margin_top + box.content_margin_bottom if box != null else 28.0
	var head := float(_headline.get_line_count()) * float(_headline.get_line_height())
	# **한 줄 여유를 준다.** 딱 맞게 계산하면 4px가 모자라 마지막 줄이 반쯤 잘렸다.
	# 상자 모형을 끝까지 파고들 수도 있지만, 여기서 틀렸을 때 잃는 것이 「놓친 단서」다.
	# 흔한 실패는 어차피 바닥(182)에 걸려 이 여유가 공짜다.
	var text_height := float(_detail.get_line_count() + 1) * float(_detail.get_line_height())
	var wanted := head + float(_body.get_theme_constant("separation")) + text_height + padding
	_fit_wanted = maxf(_fit_wanted, wanted)
	custom_minimum_size.y = clampf(_fit_wanted, HEIGHT_BRIEF, HEIGHT_EXPLAINED)


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
