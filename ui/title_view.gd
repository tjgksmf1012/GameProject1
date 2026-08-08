extends Control

## 첫 화면. **부스에서 처음 앉은 사람이 30초 안에 이해해야 하는 것의 절반이 여기서 결정된다.**
##
## 이 게임은 튜토리얼이 없다. 그래서 제목 화면이 두 줄로 규칙을 가르친다:
##   ① 점장이 남긴 수칙대로 손님을 받아라 (= 무엇을 하는 게임인가)
##   ② 수칙 전부가 참인 것은 아니다 (= 왜 어려운가)
## 둘째 줄은 **한 박자 늦게** 뜬다. 첫 줄을 읽고 "쉽네"라고 생각한 다음에 와야 한다.
##
## 간판은 형광등처럼 깜빡인다. 이미지가 아니라 modulate 트윈이다 (CLAUDE.md 1.1).
## 실존 편의점 브랜드는 쓰지 않는다 — 「밤샘마트」는 가상 상호다 (CLAUDE.md 7절).

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const SIGN_SIZE := 58

const TWIST_DELAY := 1.9
const TWIST_FADE := 1.4
const PROMPT_DELAY := 2.9
const PROMPT_PULSE := 1.6
const PROMPT_LOW := 0.25

## 형광등이 안정되기까지. 값은 (알파, 유지시간) 쌍이다.
const SIGN_FLICKER := [
	[0.0, 0.10], [0.9, 0.05], [0.1, 0.09], [1.0, 0.04],
	[0.2, 0.12], [0.75, 0.06], [1.0, 0.0],
]

var _strings: Dictionary = {}
var _twist: Label = null
var _prompt: Label = null


func build(strings: Dictionary, save_night: int, finished: bool = false) -> void:
	_strings = strings
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_add_sign(column)
	column.add_child(_spacer(26))
	_add_centered(column, "title.premise", Palette.SIZE_HEAD, Palette.TEXT)
	_twist = _add_centered(column, "title.twist", Palette.SIZE_BODY, Palette.ACCENT)
	_twist.modulate.a = 0.0
	column.add_child(_spacer(34))
	_add_progress(column, save_night, finished)
	_prompt = _add_centered(column, "title.start", Palette.SIZE_BODY, Palette.TEXT_DIM)
	_prompt.modulate.a = 0.0
	_stretch_to_screen()


## **앵커는 자식을 다 붙인 뒤에 건다.** `_ready()`에 두면 소용이 없다 — 노드를 트리에
## 넣는 순간 `_ready()`가 먼저 돌고, 그때는 여기 자식이 하나도 없기 때문이다.
## M2에서 NightView를 분리하다 같은 모양으로 당했다. 테스트로는 절대 안 잡힌다.
func _stretch_to_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _add_sign(column: VBoxContainer) -> void:
	var sign_label := _add_centered(column, "title.store", SIGN_SIZE, Palette.TEXT)
	sign_label.modulate.a = 0.0
	_add_centered(column, "title.hours", Palette.SIZE_SMALL, Palette.ACCENT)
	var flicker := create_tween()
	for step in SIGN_FLICKER:
		flicker.tween_property(sign_label, "modulate:a", float(step[0]), 0.02)
		if float(step[1]) > 0.0:
			flicker.tween_interval(float(step[1]))


## 이어서 하는 밤이 몇 번째인지 알려준다. 세이브가 첫 밤이면 아무 말도 하지 않는다.
func _add_progress(column: VBoxContainer, save_night: int, finished: bool) -> void:
	if finished:
		column.add_child(_center(Palette.make_label(
			_t("title.finished"), Palette.SIZE_SMALL, Palette.ACCENT)))
		return
	if save_night <= SaveGame.FIRST_NIGHT:
		return
	column.add_child(_center(Palette.make_label(
		_t("title.continue_night") % save_night, Palette.SIZE_SMALL, Palette.TEXT_DIM)))


func _add_centered(column: VBoxContainer, key: String, size: int, color: Color) -> Label:
	var label := _center(Palette.make_label(_t(key), size, color))
	column.add_child(label)
	return label


## **가로로 늘려야 가운데 정렬이 의미를 가진다.** 늘리지 않으면 라벨이 글자 폭만큼만
## 잡히고, 그 안에서 가운데 정렬해 봐야 화면 왼쪽에 붙는다.
static func _center(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## 반전 문구와 시작 안내는 간판이 안정된 **뒤에** 온다.
func play_intro() -> void:
	Juice.fade_in(_twist, TWIST_FADE, TWIST_DELAY)
	var entrance := create_tween()
	entrance.tween_interval(PROMPT_DELAY)
	entrance.tween_property(_prompt, "modulate:a", 1.0, 0.6)
	entrance.tween_callback(_pulse_prompt)


## 등장 트윈과 맥박 트윈을 나눈다. 한 트윈에 set_loops를 걸면 등장 지연까지 같이 돈다.
func _pulse_prompt() -> void:
	var pulse := create_tween().set_loops()
	pulse.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_prompt, "modulate:a", PROMPT_LOW, PROMPT_PULSE)
	pulse.tween_property(_prompt, "modulate:a", 1.0, PROMPT_PULSE)
