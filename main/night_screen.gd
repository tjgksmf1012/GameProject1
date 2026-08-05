extends Control

## 밤 하나를 굴리는 오케스트레이터. **흐름만 맡는다.**
## 배치는 `ui/night_view.gd`, 소리는 `ui/audio_deck.gd`가 들고 있다.
## 조각끼리는 시그널로만 대화한다. 노드 경로 하드코딩 없음 (CLAUDE.md 1.2).

const Juice := preload("res://ui/juice.gd")
const ScreenEffects := preload("res://ui/screen_effects.gd")
const NightView := preload("res://ui/night_view.gd")
const AudioDeck := preload("res://ui/audio_deck.gd")
const DeathSequence := preload("res://ui/death_sequence.gd")

const ITEMS_PATH := "res://data/items.json"
const OBSERVATION_PATH := "res://data/observation.json"
const TESTER_ARG := "--tester="

var _strings: Dictionary = {}
var _balance: Dictionary = {}
var _juice: Dictionary = {}
var _session: NightSession = null
var _plan: NightPlan = null
var _save: SaveGame = null
var _log: SessionLog = null

var _view: NightView = null
var _audio: AudioDeck = null
var _effects: ScreenEffects = null
var _death: DeathSequence = null

var _judging: bool = false
var _last_result: JudgeResult = null
var _shown_at_msec: int = 0
var _night_started_msec: int = 0


func _ready() -> void:
	_strings = GameData.load_strings()
	_balance = GameData.load_balance()
	_juice = _balance.get("juice", {}) as Dictionary
	_log = SessionLog.new(_tester_id(), bool(_balance.get("grace_on_first_trap", true)))
	_plan = NightPlan.load()
	_save = SaveGame.load_or_new()
	_build()
	_start_night(_save.night)


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _j(key: String, fallback: float) -> float:
	return float(_juice.get(key, fallback))


static func _tester_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(TESTER_ARG):
			return arg.substr(TESTER_ARG.length())
	return "tester_%d" % int(Time.get_unix_time_from_system())


func _build() -> void:
	_audio = AudioDeck.new()
	add_child(_audio)
	_audio.setup(_balance.get("audio", {}) as Dictionary)

	var observation := GameData.read_json(OBSERVATION_PATH)
	_view = NightView.new()
	add_child(_view)
	_view.build(
		_strings,
		GameData.read_json(ITEMS_PATH).get("prices", {}) as Dictionary,
		Customer._to_string_array(observation.get("cctv_traits", [])))

	_view.pos.verdict_chosen.connect(_on_verdict)
	_view.pos.item_scanned.connect(_audio.play.bind("scan"))
	_view.pos.id_checked.connect(_audio.play.bind("click"))
	_view.clipboard.rule_added.connect(_audio.play.bind("paper"))
	_view.result.continued.connect(_on_continue)

	_effects = ScreenEffects.new()
	add_child(_effects)
	_death = DeathSequence.new()
	add_child(_death)
	_death.setup(_strings)


func _start_night(night: int) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	_session = NightSession.new(engine, _plan.customers_for(night), _balance, night)
	_night_started_msec = Time.get_ticks_msec()
	_judging = false
	_view.swap_to_pos()
	var visible := _session.engine.visible_rules(_session.night)
	_view.clipboard.show_rules(visible)
	_view.clipboard.apply_night(visible, _session.night)
	_present_customer()


func _present_customer() -> void:
	var customer := _session.current_customer()
	if customer == null:
		return
	_audio.play("bell")
	_view.customer_view.show_customer(customer)
	_view.cctv.show_customer(customer)
	_view.pos.present(customer)
	_shown_at_msec = Time.get_ticks_msec()
	_refresh_header()


func _refresh_header() -> void:
	_view.set_header(
		_session.current_context().time_display(),
		_t("ui.progress") % [
			_session.index + 1, _session.total_customers(),
			_session.misjudge_count, _session.misjudge_limit(),
		])
	var tension := _tension()
	_effects.set_tension(tension)
	_audio.set_tension(tension)


## 화면에 이미 보이는 것만으로 계산한다 — 남은 오판 여유와 밤의 진행도.
## 이상 손님 여부에 연동하면 셰이더가 정답을 흘리고, 그 순간 퍼즐이 죽는다.
func _tension() -> float:
	var from_misjudge := float(_session.misjudge_count) / maxf(1.0, float(_session.misjudge_limit()))
	var from_progress := float(_session.index) / maxf(1.0, float(_session.total_customers()))
	return clampf(
		from_misjudge * _j("tension_from_misjudge", 0.6)
			+ from_progress * _j("tension_from_progress", 0.4),
		0.0, 1.0)


func _on_verdict(kind: String) -> void:
	# 판정은 히트스톱·리플레이를 거치는 비동기 흐름이다. 겹쳐 들어오면 화면 상태가 어긋난다.
	if _judging or _session.is_finished():
		return
	_judging = true
	var ctx := _session.current_context()
	var result := _session.judge(Verdict.from_id(kind))
	_last_result = result
	_log.record_judgment(ctx, result, (Time.get_ticks_msec() - _shown_at_msec) / 1000.0)
	_view.pos.lock()
	_audio.play("correct" if result.correct else "wrong")
	if not result.correct:
		Juice.shake(_view.shake_target, _j("shake_wrong", 9.0), _j("shake_duration", 0.32))
	await Juice.hitstop(get_tree(),
		_j("hitstop_correct", 0.05) if result.correct else _j("hitstop_wrong", 0.12))
	_refresh_header()
	# 짚을 줄이 없으면(발동한 수칙이 하나도 없는 오판) 리플레이는 아무것도 밝히지 못한다.
	# 그 경우 결과 문구가 이미 "아무 수칙도 막지 않았다"고 말해준다.
	if not result.correct and result.missed_rule_ids.size() > 0:
		await _replay_missed_clues(result)
	_view.swap_to_result()
	_view.result.show_result(result, _t("ui.next"))
	_judging = false


## 3초 리플레이 (F-07, 공정성 불변식 3).
## "속았다"를 "알아챌 수 있었는데 놓쳤다"로 바꾸는 장치다.
## 05-prioritization.md 4절이 절대 자르지 말라고 못박은 항목이다.
func _replay_missed_clues(result: JudgeResult) -> void:
	_view.highlight_clues(result.missed_rule_ids, result.decisive_fields, _j("replay_dim", 0.3))
	await get_tree().create_timer(_j("replay_seconds", 3.0)).timeout
	_view.clear_highlights()


func _on_continue() -> void:
	# 판정 흐름이 아직 도는 중이면 무시한다. 실제 플레이에선 그 사이 버튼이 안 보이지만,
	# 가드가 없으면 결과 문구는 이전 손님 것인데 화면은 다음 손님이 되는 어긋남이 생긴다.
	if _judging:
		return
	_audio.play("click")
	_session.advance()
	if _session.is_finished():
		_finish_night()
		return
	_view.swap_to_pos()
	_present_customer()


func _finish_night() -> void:
	if _session.is_failed():
		await _play_death()
	_show_summary()


## 소리를 먼저 끈다. 굉음보다 정적이 무섭다 (F-07).
func _play_death() -> void:
	_audio.silence_ambience()
	_effects.set_tension(1.0)
	_view.pos.visible = false
	# 무엇이 죽였는지에 따라 다른 연출이 나온다. 같은 화면이 세 번 나오면 안 무섭다.
	_death.play(_death_kind(), size)
	await get_tree().create_timer(DeathSequence.SILENCE_SECONDS).timeout
	_audio.play("death")
	await _death.finished
	_death.clear()


func _death_kind() -> String:
	if _last_result == null:
		return DeathSequence.KIND_APPROACH
	return DeathSequence.kind_for(_last_result.trap_triggered, _last_result.decisive_fields)


func _show_summary() -> void:
	_log.record_night_end(_session, (Time.get_ticks_msec() - _night_started_msec) / 1000.0)
	var next_night := _session.night + 1
	var cleared := not _session.is_failed()
	# **실패한 밤은 진행이 오르지 않는다.** 같은 밤을 다시 한다 (F-06).
	if cleared:
		_save.advance_to(next_night if _plan.has_night(next_night) else _session.night)
		_save.store()
	_view.swap_to_result()
	_view.result.show_summary(
		_summary_headline(cleared, next_night),
		_summary_detail(),
		_t("ui.night_cleared_next") if cleared and _plan.has_night(next_night) else _t("ui.restart"))
	_view.result.continued.disconnect(_on_continue)
	_view.result.continued.connect(_on_restart)


func _summary_headline(cleared: bool, next_night: int) -> String:
	if not cleared:
		return _t("night.failed") % _session.misjudge_count
	if not _plan.has_night(next_night):
		return _t("night.all_cleared")
	return _t("night.cleared")


func _summary_detail() -> String:
	var lines := PackedStringArray([_t("night.summary") % [
		_session.correct_count, _session.misjudge_count, _session.trap_count,
	]])
	var saved := _log.save()
	if saved != "":
		lines.append(_t("ui.log_saved") % saved)
	return "\n".join(lines)


func _on_restart() -> void:
	_view.result.continued.disconnect(_on_restart)
	_view.result.continued.connect(_on_continue)
	_log.begin_next_attempt()
	_start_night(_save.night)
