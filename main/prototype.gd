extends Control

## M0 프로토타입 화면. **예쁘게 만들지 않는다** (CLAUDE.md 3원칙).
##
## 목적은 단 하나 — 텍스트만으로 H1(거짓 수칙이 짜증이 아니라 재미인가)과
## H2(고정 시점이 답답함이 아니라 압박감인가)를 검증하는 것이다.
## 셰이더·트윈·사운드는 M1 이후다. 여기서 예쁘게 만들면 되돌릴 수 없다.
##
## 씬 파일은 이 Control 하나뿐이고 레이아웃은 전부 코드다 (CLAUDE.md 1.2).

const UI_MARGIN := 24
const COLUMN_SEPARATION := 40
const FONT_SIZE_BODY := 16
const FONT_SIZE_HEADER := 20

## 한글 폰트는 OS에서 가져온다. 폰트 파일을 저장소에 넣지 않기 위해서다.
## M2에서 아트 디렉션을 확정할 때 번들 폰트로 교체한다.
const FONT_CANDIDATES := ["Malgun Gothic", "Noto Sans CJK KR", "NanumGothic", "AppleGothic", "sans-serif"]

## 플레이테스트 식별자. `godot -- --tester=A1` 로 넘긴다. 없으면 타임스탬프를 쓴다.
const TESTER_ARG := "--tester="

var _strings: Dictionary = {}
var _session: NightSession = null
var _awaiting_next: bool = false
var _log: SessionLog = null
var _shown_at_msec: int = 0
var _night_started_msec: int = 0

var _header: Label = null
var _clipboard: Label = null
var _customer_info: Label = null
var _observation: Label = null
var _result: Label = null
var _serve_button: Button = null
var _refuse_button: Button = null
var _next_button: Button = null


func _ready() -> void:
	_strings = GameData.load_strings()
	_log = SessionLog.new(_tester_id(), bool(GameData.load_balance().get("grace_on_first_trap", true)))
	_build_ui()
	_start_night()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


static func _tester_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(TESTER_ARG):
			return arg.substr(TESTER_ARG.length())
	return "tester_%d" % int(Time.get_unix_time_from_system())


func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_CANDIDATES)
	add_theme_font_override("font", font)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = UI_MARGIN
	box.offset_top = UI_MARGIN
	box.offset_right = -UI_MARGIN
	box.offset_bottom = -UI_MARGIN
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	_header = _make_label(font, FONT_SIZE_HEADER)
	box.add_child(_header)
	box.add_child(_build_columns(font))
	_result = _make_label(font, FONT_SIZE_BODY)
	_result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_result)
	box.add_child(_build_buttons(font))


func _build_columns(font: SystemFont) -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_SEPARATION)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_make_label(font, FONT_SIZE_HEADER, _t("ui.clipboard_header")))
	_clipboard = _make_label(font, FONT_SIZE_BODY)
	left.add_child(_clipboard)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_make_label(font, FONT_SIZE_HEADER, _t("ui.customer_header")))
	_customer_info = _make_label(font, FONT_SIZE_BODY)
	right.add_child(_customer_info)
	right.add_child(_make_label(font, FONT_SIZE_HEADER, _t("ui.observation_header")))
	_observation = _make_label(font, FONT_SIZE_BODY)
	right.add_child(_observation)

	columns.add_child(left)
	columns.add_child(right)
	return columns


func _build_buttons(font: SystemFont) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_serve_button = _make_button(font, _t("ui.serve"))
	_refuse_button = _make_button(font, _t("ui.refuse"))
	_next_button = _make_button(font, _t("ui.next"))
	_serve_button.pressed.connect(_on_verdict.bind(Verdict.SERVE))
	_refuse_button.pressed.connect(_on_verdict.bind(Verdict.REFUSE))
	_next_button.pressed.connect(_on_next)
	row.add_child(_serve_button)
	row.add_child(_refuse_button)
	row.add_child(_next_button)
	return row


func _make_label(font: SystemFont, size: int, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	return label


func _make_button(font: SystemFont, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 44)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	return button


func _start_night() -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	_session = NightSession.new(engine, GameData.load_customers(), GameData.load_balance())
	_awaiting_next = false
	_night_started_msec = Time.get_ticks_msec()
	_result.text = ""
	_refresh()


func _refresh() -> void:
	var customer := _session.current_customer()
	if customer == null:
		return
	var ctx := _session.current_context()
	_header.text = "%s   ·   %s %s   ·   %s" % [
		_t("ui.night") % _session.night,
		_t("ui.time"),
		ctx.time_display(),
		_t("ui.progress") % [
			_session.index + 1, _session.total_customers(),
			_session.misjudge_count, _session.misjudge_limit(),
		],
	]
	_clipboard.text = _clipboard_text()
	_customer_info.text = _customer_text(customer)
	_observation.text = _observation_text(customer)
	_shown_at_msec = Time.get_ticks_msec()
	_set_buttons(true)


func _clipboard_text() -> String:
	var lines := PackedStringArray()
	for rule in _session.engine.visible_rules(_session.night):
		lines.append("· " + _t(rule.text_key))
	return "\n\n".join(lines)


func _customer_text(customer: Customer) -> String:
	var lines := PackedStringArray([_t(customer.name_key)])
	for key in customer.dialogue_keys:
		lines.append("\"%s\"" % _t(key))
	var items := PackedStringArray()
	for key in customer.item_keys:
		items.append(_t(key))
	lines.append("[ %s ]" % ", ".join(items))
	return "\n".join(lines)


## 공정성 불변식 1을 화면으로 옮긴 부분. 손님의 모든 특성을 빠짐없이 보여준다.
func _observation_text(customer: Customer) -> String:
	var lines := PackedStringArray()
	for name in customer.trait_names():
		var value: Variant = customer.get_trait(name)
		var shown := _t("ui.yes") if bool(value) else _t("ui.no")
		lines.append("%s : %s" % [_t("trait." + name), shown])
	return "\n".join(lines)


func _on_verdict(kind: String) -> void:
	if _awaiting_next or _session.is_finished():
		return
	var ctx := _session.current_context()
	var result := _session.judge(Verdict.from_id(kind))
	_log.record_judgment(ctx, result, _seconds_since(_shown_at_msec))
	_result.text = _result_text(result)
	_awaiting_next = true
	_set_buttons(false)


static func _seconds_since(msec: int) -> float:
	return (Time.get_ticks_msec() - msec) / 1000.0


func _result_text(result: JudgeResult) -> String:
	if result.correct:
		return _t("result.correct")
	var lines := PackedStringArray()
	if result.is_trap_death():
		lines.append(_t("result.trap_grace") if result.graced else _t("result.trap"))
	else:
		lines.append(_t("result.wrong"))
	lines.append(_t("result.expected") % _t("ui." + result.expected[0].id()))
	lines.append("")
	lines.append(_t("result.missed_header"))
	for key in result.missed_clue_keys:
		lines.append("· " + _t(key))
	return "\n".join(lines)


func _on_next() -> void:
	if not _awaiting_next:
		return
	_awaiting_next = false
	_session.advance()
	if _session.is_finished():
		_finish_night()
		return
	_result.text = ""
	_refresh()


func _finish_night() -> void:
	_log.record_night_end(_session, _seconds_since(_night_started_msec))
	var lines := PackedStringArray()
	lines.append(_t("night.failed") % _session.misjudge_count if _session.is_failed() else _t("night.cleared"))
	lines.append(_t("night.summary") % [
		_session.correct_count, _session.misjudge_count, _session.trap_count,
	])
	var saved := _log.save()
	if saved != "":
		lines.append(_t("ui.log_saved") % saved)
	_result.text = "\n".join(lines)
	_set_buttons(false)
	_next_button.text = _t("ui.restart")
	_next_button.disabled = false
	if not _next_button.pressed.is_connected(_restart):
		_next_button.pressed.disconnect(_on_next)
		_next_button.pressed.connect(_restart)


func _restart() -> void:
	_next_button.pressed.disconnect(_restart)
	_next_button.pressed.connect(_on_next)
	_next_button.text = _t("ui.next")
	# 재시작 횟수가 곧 "첫 실패 후 다시 하고 싶어했는가"(C-2)의 대리 지표다.
	_log.begin_next_attempt()
	_start_night()


func _set_buttons(judging: bool) -> void:
	_serve_button.disabled = not judging
	_refuse_button.disabled = not judging
	_next_button.disabled = judging
