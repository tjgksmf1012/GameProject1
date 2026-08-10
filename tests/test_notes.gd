extends RefCounted

## 클립보드 메모가 **이야기만 나르고 판정은 건드리지 않는가.**
##
## 이 파일이 막는 사고는 하나다: 메모가 수칙이 되는 것. 메모에는 조건이 없고,
## 조건이 빈 규칙은 `matches()`가 공허참이라 **모든 손님에게 발동한다.** 판정 경로 어딘가에
## 메모가 새어 들어가면 그 밤의 모든 손님이 메모대로 판정된다 — 가장 조용한 실패다.
##
## 그래서 「빠졌는지」를 묻지 않고 **「넣으면 물어뜯는 메모」를 실제로 만들어 먹여 본다.**
## 검사가 무엇을 잡는지 모르면 그건 검사가 아니라 장식이다.

const ClipboardPanel := preload("res://ui/clipboard/clipboard_panel.gd")

## 한국어 메모는 **평서문으로만** 쓴다. 명령형·청유형·의문형이 하나도 없어야 한다.
## 종결어미를 직접 보는 쪽이 금칙어 목록보다 강하다 — 목록은 새 표현을 못 잡는다.
const KO_SENTENCE_END := "다"
const EN_CONDITIONALS := [" if ", " when ", " unless ", " whenever ", " while you must"]


func run(r: RefCounted) -> void:
	r.suite("notes")
	_test_notes_never_reach_a_verdict(r)
	_test_a_leaking_note_would_bite(r)
	_test_notes_are_statements_not_orders(r)
	_test_snapshot_shows_notes_but_they_cannot_be_struck(r)
	_test_the_hand_changes_partway(r)
	_test_clipboard_draws_them_without_calling_them_rules(r)


func _notes() -> Array[Rule]:
	var out: Array[Rule] = []
	for rule in GameData.load_rules():
		if rule.is_note():
			out.append(rule)
	return out


## 메모가 있든 없든 정답이 **한 글자도** 달라지지 않는다.
func _test_notes_never_reach_a_verdict(r: RefCounted) -> void:
	var without: Array[Rule] = []
	for rule in GameData.load_rules():
		if not rule.is_note():
			without.append(rule)
	r.check(_notes().size() > 0, "메모가 하나도 없으면 이 검사가 아무것도 안 한다")
	var with_notes := RuleEngine.new(GameData.load_rules())
	var plain := RuleEngine.new(without)
	for rule in with_notes.rules():
		r.check(not rule.is_note(), "메모 %s가 판정용 목록에 들어갔다" % rule.id)
	var plan := NightPlan.load()
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var ctx := JudgeContext.new(
				night, NightSession.arrival_minutes(i, customers.size()), customers[i])
			r.equals(_verdict_ids(with_notes, ctx), _verdict_ids(plain, ctx),
				"%d일째 밤 %s의 정답이 메모 때문에 달라졌다" % [night, customers[i].id])


static func _verdict_ids(engine: RuleEngine, ctx: JudgeContext) -> String:
	var out := PackedStringArray()
	for verdict in engine.required_verdicts(ctx):
		out.append(verdict.id())
	out.sort()
	return "+".join(out)


## **이 검사가 이 파일의 존재 이유다.** 조건이 빈 메모를 하나 만들어 넣는다.
## 판정 경로로 새면 이 메모는 모든 손님을 거부시킨다 — 그러면 여기서 떨어진다.
func _test_a_leaking_note_would_bite(r: RefCounted) -> void:
	var poisoned := GameData.load_rules()
	poisoned.append(Rule.from_dict({
		"id": "note_probe_refuse_everyone",
		"kind": "note",
		"text_key": "note.handover",
		"required_verdict": Verdict.REFUSE,
		"introduced_night": 1,
	}))
	var engine := RuleEngine.new(poisoned)
	var plan := NightPlan.load()
	var served := 0
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var ctx := JudgeContext.new(
				night, NightSession.arrival_minutes(i, customers.size()), customers[i])
			for verdict in engine.required_verdicts(ctx):
				if verdict.id() == Verdict.SERVE:
					served += 1
	r.check(served > 0,
		"조건 없는 메모가 손님 전원을 거부시켰다 — 메모가 판정 경로로 새고 있다")


## 메모는 **명령하지 않는다.** 지킬 수 있는 문장처럼 읽히면 그건 수칙이고,
## 판정에 참여하지 않는 수칙은 함정이다.
func _test_notes_are_statements_not_orders(r: RefCounted) -> void:
	for note in _notes():
		var ko := str(GameData.load_strings("ko").get(note.text_key, ""))
		r.check(ko != "", "메모 %s의 한국어 문구가 없다" % note.id)
		for sentence in ko.split(".", false):
			var trimmed := str(sentence).strip_edges()
			if trimmed.is_empty():
				continue
			r.check(trimmed.ends_with(KO_SENTENCE_END),
				"메모 %s에 평서문이 아닌 문장이 있다 — 수칙으로 읽힌다: 「%s」"
					% [note.id, trimmed])
		var en := str(GameData.load_strings("en").get(note.text_key, "")).to_lower()
		r.check(not en.contains("?"), "메모 %s(en)가 묻고 있다" % note.id)
		for marker in EN_CONDITIONALS:
			r.check(not en.contains(str(marker)),
				"메모 %s(en)에 조건절이 있다 — 판정 가능한 줄로 읽힌다: 「%s」"
					% [note.id, en])


## 화면에 보이므로 스냅샷에도 있어야 한다. 다만 **그을 수는 없다** —
## 긋는다는 것은 「이 줄은 거짓이라고 본다」인데 메모에는 진위가 없다.
func _test_snapshot_shows_notes_but_they_cannot_be_struck(r: RefCounted) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var strings := GameData.load_strings("ko")
	var plan := NightPlan.load()
	var seen := 0
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var minutes := NightSession.arrival_minutes(i, customers.size())
			var ctx := JudgeContext.new(night, minutes, customers[i])
			var snap := ScreenSnapshot.of(engine, ctx, strings, [], {"customer": i + 1})
			var marked := 0
			for line in (snap["clipboard"] as Array):
				var row := line as Dictionary
				if not str(row.get("text", "")).begins_with(ScreenSnapshot.note_prefix()):
					continue
				marked += 1
				r.check(not row.has("struck_by_me"),
					"%d일째 밤 메모에 그은 표시가 붙었다 — 메모는 그을 수 없다" % night)
				r.check(not row.has("id"), "%d일째 밤 메모에 id가 붙었다" % night)
			r.equals(marked, engine.visible_notes(night, minutes).size(),
				"%d일째 밤 %s: 화면의 메모 수와 스냅샷이 다르다"
					% [night, ShiftClock.to_display(minutes)])
			seen += marked
	r.check(seen > 0, "스냅샷에서 메모를 한 번도 못 봤다")


## 회수하려는 사실은 하나다 — **나중 수칙을 누가 쓰는가.**
## 점장 필체로 시작해 남의 필체로 넘어가지 않으면 메모는 그냥 잡담이다.
func _test_the_hand_changes_partway(r: RefCounted) -> void:
	var last_manager := 0
	var first_later := 99
	for note in _notes():
		if note.hand == Rule.HAND_MANAGER:
			last_manager = maxi(last_manager, note.introduced_night)
		else:
			first_later = mini(first_later, note.introduced_night)
	r.check(last_manager > 0, "점장 필체 메모가 없다 — 넘어갈 대상이 없다")
	r.check(first_later < 99, "남의 필체 메모가 없다 — 필체가 안 넘어간다")
	r.check(last_manager < first_later,
		"필체가 오갔다 — 점장 필체가 %d일째 밤까지인데 남의 필체가 %d일째 밤에 있다"
			% [last_manager, first_later])


## 클립보드가 메모를 실제로 그리되, **수칙 목록에는 넣지 않는가.**
## `_shown_ids`는 「지금 유효한 수칙」이고 test_clipboard.gd의 기준이다.
## 메모가 거기 들어가면 그 검사가 조용히 무의미해진다.
func _test_clipboard_draws_them_without_calling_them_rules(r: RefCounted) -> void:
	var panel := ClipboardPanel.new()
	panel.set_strings(GameData.load_strings())
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	for night in plan.nights():
		var minutes := NightSession.arrival_minutes(0, plan.customers_for(night).size())
		var notes := engine.visible_notes(night, minutes)
		panel.show_notes(notes, night)
		r.equals(panel._notes.size(), notes.size(),
			"%d일째 밤 클립보드의 메모 수가 엔진과 다르다" % night)
		for note in notes:
			r.check(not panel._shown_ids.has(note.id),
				"메모 %s가 수칙 목록에 들어갔다" % note.id)
	panel.queue_free()
