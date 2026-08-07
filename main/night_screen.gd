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
const TITLE_SCENE := "res://main/title_screen.tscn"

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

var _patience: PatienceClock = null
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
	_patience = PatienceClock.from_balance(_balance)
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
	_view.clipboard.strike_toggled.connect(_on_strike_toggled)
	_view.result.continued.connect(_on_continue)

	_effects = ScreenEffects.new()
	add_child(_effects)
	# 클립보드 자리를 셰이더에 알려준다. **매끄러운 휘도 효과가 종이 단서와 경쟁하기 때문이다**
	# (crt.gdshader 주석 참고). 수칙이 붙거나 찢기면 높이가 바뀌므로 그때마다 다시 넘긴다.
	_view.clipboard.resized.connect(_update_safe_rect)
	_update_safe_rect.call_deferred()
	_death = DeathSequence.new()
	add_child(_death)
	_death.setup(_strings)


## 클립보드가 지금 화면 어디에 있는가. 레이아웃이 정해진 뒤에만 의미가 있다.
func _update_safe_rect() -> void:
	if _effects == null or _view == null or _view.clipboard == null:
		return
	_effects.protect_rect(_view.clipboard.get_global_rect(), get_viewport_rect().size)


func _start_night(night: int) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	# 유예는 세이브가 들고 있다. 밤마다 새로 주면 「다음부터는 아니다」가 거짓말이 된다.
	_session = NightSession.new(
		engine, _plan.customers_for(night), _balance, night, _save.grace_used)
	_night_started_msec = Time.get_ticks_msec()
	_judging = false
	_view.swap_to_pos()
	_view.clipboard.clear_torn()
	_present_customer()


## 플레이어가 수칙을 그었다. **판정에는 아무 영향이 없다** — 정답은 참 수칙이 정한다.
## 표시를 세이브에 남기는 이유: 밤 1에서 거짓이라고 결론 낸 줄을 밤 4에서 다시 긋게 하면
## 그건 추론이 아니라 사무 작업이다.
func _on_strike_toggled(rule_id: String) -> void:
	_save.toggle_strike(rule_id)
	_save.store()
	_view.clipboard.set_struck(_save.struck_rule_ids, rule_id)
	_audio.play("pen")


func _present_customer() -> void:
	var customer := _session.current_customer()
	if customer == null:
		return
	_audio.play("bell")
	_view.refresh_clipboard(
		_session.engine, _session.night,
		_session.current_context().shift_minutes,
		_session.index > 0, _save.struck_rule_ids)
	_view.customer_view.show_customer(customer)
	_view.cctv.show_customer(customer)
	_view.pos.present(customer)
	_patience.start(customer)
	_shown_at_msec = Time.get_ticks_msec()
	_refresh_header()


## 손님이 기다린다. **판정에는 손대지 않는다** — 긴장도만 올리고 재촉하게 둔다
## (왜 죽이지 않는지는 `PatienceClock` 주석).
## 판정 흐름이 도는 동안과 결과 화면에서는 멈춘다. 히트스톱은 delta가 0이라 저절로 선다.
func _process(delta: float) -> void:
	if _judging or _session == null or _session.is_finished():
		return
	if _patience.tick(delta):
		_view.customer_view.set_pressure_stage(_patience.stage())
		_audio.play("tap")
	_apply_tension()


func _refresh_header() -> void:
	_view.set_header(
		_session.current_context().time_display(),
		_t("ui.progress") % [
			_session.index + 1, _session.total_customers(),
			_session.misjudge_count, _session.misjudge_limit(),
		],
		float(_session.misjudge_count) / maxf(1.0, float(_session.misjudge_limit())))
	_apply_tension()


func _apply_tension() -> void:
	var tension := _tension()
	_effects.set_tension(tension)
	_view.set_tension(tension)
	_audio.set_tension(tension)


## 화면에 이미 보이는 것만으로 계산한다 — 남은 오판 여유, 밤의 진행도, 손님이 기다린 시간.
## 이상 손님 여부에 연동하면 셰이더가 정답을 흘리고, 그 순간 퍼즐이 죽는다.
## 인내도 마찬가지다. **모든 손님이 똑같은 속도로 조인다.**
func _tension() -> float:
	var from_misjudge := float(_session.misjudge_count) / maxf(1.0, float(_session.misjudge_limit()))
	var from_progress := float(_session.index) / maxf(1.0, float(_session.total_customers()))
	return clampf(
		from_misjudge * _j("tension_from_misjudge", 0.6)
			+ from_progress * _j("tension_from_progress", 0.4)
			+ _patience.tension_bonus(),
		0.0, 1.0)


func _on_verdict(kind: String) -> void:
	# 판정은 히트스톱·리플레이를 거치는 비동기 흐름이다. 겹쳐 들어오면 화면 상태가 어긋난다.
	if _judging or _session.is_finished():
		return
	_judging = true
	_patience.stop()
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
	_view.clipboard.clear_torn()
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
	var has_next := _plan.has_night(next_night)
	var cleared := not _session.is_failed()
	var grace_spent := _save.spend_grace(_session.grace_used)
	# **실패한 밤은 진행이 오르지 않는다.** 같은 밤을 다시 한다 (F-06).
	if cleared:
		_save.advance_to(next_night if has_next else _session.night)
	if cleared or grace_spent:
		_save.store()

	var report := NightReport.new(_strings)
	var detail := report.ending_detail(_save.struck_rule_ids.size()) \
		if NightReport.is_ending(cleared, has_next) \
		else report.night_detail(
			_session.correct_count, _session.misjudge_count,
			_session.trap_count, _log.save())
	_view.swap_to_result()
	_view.result.show_summary(
		report.headline(cleared, has_next, _session.misjudge_count),
		detail,
		report.continue_label(cleared, has_next))
	_view.result.continued.disconnect(_on_continue)
	_view.result.continued.connect(
		_on_leave_store if NightReport.is_ending(cleared, has_next) else _on_restart)


## 엔딩에서 「가게를 나선다」. **같은 밤을 다시 시작하면 끝난 게 아니게 된다.**
## 제목 화면으로 돌아간다 — 세이브는 마지막 밤을 가리키고 있으므로 다시 들어올 수 있다.
func _on_leave_store() -> void:
	_audio.play("click")
	_audio.silence_ambience()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_restart() -> void:
	_view.result.continued.disconnect(_on_restart)
	_view.result.continued.connect(_on_continue)
	_log.begin_next_attempt()
	_start_night(_save.night)
