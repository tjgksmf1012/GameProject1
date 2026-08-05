extends SceneTree

## 밤 하나를 헤드리스로 끝까지 돌려 대본을 찍는다.
##   godot --headless --script res://tools/playthrough.gd
##
## AI는 화면을 볼 수 없다 (CLAUDE.md 3절). M0는 텍스트 게임이므로 이 대본이 곧 화면이다.
## 손으로 플레이하기 전에 밤이 실제로 성립하는지, 문구가 말이 되는지 여기서 먼저 본다.

const SEPARATOR := "─────────────────────────────"

## 일부러 두 번 함정에 빠지는 각본. 첫 함정은 유예되고 두 번째는 오판으로 잡혀야 한다.
const SCRIPTED_VERDICTS := [
	Verdict.SERVE,   # 넥타이를 푼 남자 — 정답
	Verdict.REFUSE,  # 가방을 멘 학생 — 거짓 수칙을 따라 거부 (함정 1, 유예)
	Verdict.SERVE,   # 비에 젖은 여자 — 거짓 수칙이 우연히 맞음
	Verdict.SERVE,   # 웃고 있는 사람 — 그림자가 없다. 오판
	Verdict.SERVE,   # 젖은 채 서 있는 것 — 거짓 수칙을 따라 판매 (함정 2)
	Verdict.REFUSE,  # 얼굴이 붉은 남자 — 04:40 주류. 정답
]

var _strings: Dictionary = {}


func _initialize() -> void:
	_strings = GameData.load_strings()
	var engine := RuleEngine.new(GameData.load_rules())
	var session := NightSession.new(engine, GameData.load_customers(), GameData.load_balance())
	_print_clipboard(session)
	var step := 0
	while not session.is_finished() and step < SCRIPTED_VERDICTS.size():
		_play_one(session, Verdict.from_id(SCRIPTED_VERDICTS[step]))
		session.advance()
		step += 1
	_print_summary(session)
	quit(0)


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _print_clipboard(session: NightSession) -> void:
	print("\n%s\n%s\n%s" % [SEPARATOR, _t("ui.clipboard_header"), SEPARATOR])
	for rule in session.engine.visible_rules(session.night):
		print("  · ", _t(rule.text_key))


func _play_one(session: NightSession, verdict: Verdict) -> void:
	var ctx := session.current_context()
	var customer := session.current_customer()
	print("\n%s\n[%s]  %s" % [SEPARATOR, ctx.time_display(), _t(customer.name_key)])
	print("  보이는 것: ", _traits_line(customer))
	print("  판정: ", _t("ui." + verdict.id()))
	var result := session.judge(verdict)
	if result.correct:
		print("  → ", _t("result.correct"))
		return
	var headline := _t("result.trap") if result.is_trap_death() else _t("result.wrong")
	if result.graced:
		headline = _t("result.trap_grace")
	print("  → ", headline)
	print("     ", _t("result.expected") % _t("ui." + result.expected[0].id()))
	for key in result.missed_clue_keys:
		print("     · ", _t(key))


func _traits_line(customer: Customer) -> String:
	var parts := PackedStringArray()
	for name in customer.trait_names():
		var shown := _t("ui.yes") if bool(customer.get_trait(name)) else _t("ui.no")
		parts.append("%s %s" % [_t("trait." + name), shown])
	return " / ".join(parts)


func _print_summary(session: NightSession) -> void:
	print("\n%s" % SEPARATOR)
	print(_t("night.failed") % session.misjudge_count if session.is_failed() else _t("night.cleared"))
	print(_t("night.summary") % [session.correct_count, session.misjudge_count, session.trap_count])
	print(SEPARATOR)
