extends Control

## 밤 하나를 굴리는 오케스트레이터. 화면 조각들을 붙이고 시그널로만 대화한다.
## 노드 경로 하드코딩 없음 (CLAUDE.md 1.2).

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")
const ScreenEffects := preload("res://ui/screen_effects.gd")
const ClipboardPanel := preload("res://ui/clipboard/clipboard_panel.gd")
const CustomerView := preload("res://ui/customer_view.gd")
const PosTerminal := preload("res://ui/pos/pos_terminal.gd")
const ResultPanel := preload("res://ui/result_panel.gd")

const MARGIN := 44
const POS_MIN_HEIGHT := 200
const GAP := 16
const TESTER_ARG := "--tester="

var _strings: Dictionary = {}
var _balance: Dictionary = {}
var _juice: Dictionary = {}
var _session: NightSession = null
var _log: SessionLog = null

var _effects: ScreenEffects = null
var _clipboard: ClipboardPanel = null
var _customer_view: CustomerView = null
var _pos: PosTerminal = null
var _result: ResultPanel = null
var _clock: Label = null
var _status: Label = null
var _frame: VBoxContainer = null

var _sfx: Dictionary = {}
var _shown_at_msec: int = 0
var _night_started_msec: int = 0


func _ready() -> void:
	_strings = GameData.load_strings()
	_balance = GameData.load_balance()
	_juice = _balance.get("juice", {}) as Dictionary
	_log = SessionLog.new(_tester_id(), bool(_balance.get("grace_on_first_trap", true)))
	_build_audio()
	_build_ui()
	_start_night()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _j(key: String, fallback: float) -> float:
	return float(_juice.get(key, fallback))


static func _tester_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(TESTER_ARG):
			return arg.substr(TESTER_ARG.length())
	return "tester_%d" % int(Time.get_unix_time_from_system())


func _build_audio() -> void:
	var makers := {
		"click": SfxBank.click, "scan": SfxBank.scan, "correct": SfxBank.correct,
		"wrong": SfxBank.wrong, "paper": SfxBank.paper,
	}
	for name in makers:
		var player := AudioStreamPlayer.new()
		player.stream = (makers[name] as Callable).call()
		add_child(player)
		_sfx[name] = player


func _play(name: String) -> void:
	var player: AudioStreamPlayer = _sfx.get(name)
	if player != null:
		player.play()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Palette.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_frame = VBoxContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = MARGIN
	_frame.offset_top = MARGIN
	_frame.offset_right = -MARGIN
	_frame.offset_bottom = -MARGIN
	_frame.add_theme_constant_override("separation", GAP)
	add_child(_frame)

	_frame.add_child(_build_header())
	_frame.add_child(_build_main_row())
	_result = ResultPanel.new()
	_result.set_strings(_strings)
	_result.continued.connect(_on_continue)
	_frame.add_child(_result)
	_frame.add_child(_build_pos())

	_effects = ScreenEffects.new()
	add_child(_effects)


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


func _build_main_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_clipboard = ClipboardPanel.new()
	_clipboard.set_strings(_strings)
	_clipboard.rule_added.connect(_play.bind("paper"))
	_customer_view = CustomerView.new()
	_customer_view.set_strings(_strings)

	row.add_child(_clipboard)
	row.add_child(_customer_view)
	return row


func _build_pos() -> Control:
	_pos = PosTerminal.new()
	_pos.custom_minimum_size = Vector2(0, POS_MIN_HEIGHT)
	_pos.set_data(_strings, GameData.read_json("res://data/items.json").get("prices", {}))
	_pos.verdict_chosen.connect(_on_verdict)
	_pos.item_scanned.connect(_play.bind("scan"))
	_pos.id_checked.connect(_play.bind("click"))
	return _pos


func _start_night() -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	_session = NightSession.new(engine, GameData.load_customers(), _balance)
	_night_started_msec = Time.get_ticks_msec()
	_result.hide_panel()
	_clipboard.show_rules(_session.engine.visible_rules(_session.night))
	_present_customer()


func _present_customer() -> void:
	var customer := _session.current_customer()
	if customer == null:
		return
	_customer_view.show_customer(customer)
	_pos.present(customer)
	_shown_at_msec = Time.get_ticks_msec()
	_refresh_header()


func _refresh_header() -> void:
	_clock.text = _session.current_context().time_display()
	_status.text = _t("ui.progress") % [
		_session.index + 1, _session.total_customers(),
		_session.misjudge_count, _session.misjudge_limit(),
	]
	_effects.set_tension(_tension())


## 화면에 이미 보이는 것만으로 계산한다 — 남은 오판 여유와 밤의 진행도.
func _tension() -> float:
	var from_misjudge := float(_session.misjudge_count) / maxf(1.0, float(_session.misjudge_limit()))
	var from_progress := float(_session.index) / maxf(1.0, float(_session.total_customers()))
	return clampf(
		from_misjudge * _j("tension_from_misjudge", 0.6)
			+ from_progress * _j("tension_from_progress", 0.4),
		0.0, 1.0)


func _on_verdict(kind: String) -> void:
	var ctx := _session.current_context()
	var result := _session.judge(Verdict.from_id(kind))
	_log.record_judgment(ctx, result, (Time.get_ticks_msec() - _shown_at_msec) / 1000.0)
	_pos.lock()
	_play("correct" if result.correct else "wrong")
	if not result.correct:
		Juice.shake(_frame, _j("shake_wrong", 9.0), _j("shake_duration", 0.32))
	await Juice.hitstop(get_tree(),
		_j("hitstop_correct", 0.05) if result.correct else _j("hitstop_wrong", 0.12))
	_refresh_header()
	_show_result_instead_of_pos(result)


## 결과는 POS 자리에 뜬다. 클립보드와 손님은 계속 보여야 한다 —
## 놓친 단서를 읽으면서 수칙을 다시 대조할 수 있어야 하기 때문이다.
func _show_result_instead_of_pos(result: JudgeResult) -> void:
	_pos.visible = false
	_result.custom_minimum_size = Vector2(0, POS_MIN_HEIGHT)
	_result.show_result(result, _t("ui.next"))


func _on_continue() -> void:
	_play("click")
	_session.advance()
	if _session.is_finished():
		_finish_night()
		return
	_result.hide_panel()
	_pos.visible = true
	_present_customer()


func _finish_night() -> void:
	_log.record_night_end(_session, (Time.get_ticks_msec() - _night_started_msec) / 1000.0)
	var headline := _t("night.failed") % _session.misjudge_count if _session.is_failed() \
		else _t("night.cleared")
	var lines := PackedStringArray([_t("night.summary") % [
		_session.correct_count, _session.misjudge_count, _session.trap_count,
	]])
	var saved := _log.save()
	if saved != "":
		lines.append(_t("ui.log_saved") % saved)
	_pos.visible = false
	_result.custom_minimum_size = Vector2(0, POS_MIN_HEIGHT)
	_result.show_summary(headline, "\n".join(lines), _t("ui.restart"))
	_result.continued.disconnect(_on_continue)
	_result.continued.connect(_on_restart)


func _on_restart() -> void:
	_result.continued.disconnect(_on_restart)
	_result.continued.connect(_on_continue)
	_log.begin_next_attempt()
	_start_night()
