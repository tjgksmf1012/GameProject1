extends RefCounted

## 스냅샷이 **정답을 흘리지 않는가.** 이 파일이 블라인드 플레이의 유일한 담보다.
##
## 수칙 데이터를 못 본 상대에게 화면만 주고 판정을 시키는 게 목적인데,
## 스냅샷에 진위가 한 글자라도 섞이면 그 상대는 블라인드가 아니고,
## 거기서 나온 "사람도 풀 수 있겠다"는 결론은 전부 무의미해진다.
##
## 그리고 반대 방향도 같이 본다: **화면에 있는데 스냅샷에 없으면** 상대는 사람보다
## 불리하게 푸는 것이고, 그 결과도 마찬가지로 못 쓴다.

## 스냅샷 어디에도 나오면 안 되는 문자열. 정답을 직접 말하거나 강하게 시사한다.
##
## `true`/`false`는 **일부러 뺐다.** 특성값이 JSON 불리언으로 들어가는데
## (「그림자: false」는 화면에 ○ 로 그려지는 것이다) 그걸 유출로 세면
## 멀쩡한 스냅샷이 떨어진다. 진위는 `veracity` 키를 막는 것으로 잡는다.
const FORBIDDEN_SUBSTRINGS := [
	"veracity", "tell_key", "required_verdict", "conflicts_with", "anomaly",
	"decays_at_night", "is_lie", "introduced_night", "arrives_at_minute",
]

## 클립보드 한 줄에 허용되는 키 **전부**. 블랙리스트보다 이쪽이 강하다 —
## 나중에 누가 필드를 하나 더 붙이면 그게 무엇이든 여기서 걸린다.
const ALLOWED_LINE_KEYS := ["id", "look", "text", "struck_by_me"]


func run(r: RefCounted) -> void:
	r.suite("snapshot")
	_test_no_answers_leak(r)
	_test_shows_everything_on_screen(r)
	_test_hides_rules_not_yet_posted(r)
	_test_shows_torn_gap(r)


func _strings() -> Dictionary:
	return GameData.load_strings("ko")


func _snapshot(night: int, index: int, struck: PackedStringArray = []) -> Dictionary:
	var engine := RuleEngine.new(GameData.load_rules())
	var customers := NightPlan.load().customers_for(night)
	var ctx := JudgeContext.new(
		night, NightSession.arrival_minutes(index, customers.size()), customers[index])
	return ScreenSnapshot.of(engine, ctx, _strings(), struck, {"customer": index + 1})


## **이 검사가 이 파일의 존재 이유다.**
func _test_no_answers_leak(r: RefCounted) -> void:
	var plan := NightPlan.load()
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var text := JSON.stringify(_snapshot(night, i))
			for banned in FORBIDDEN_SUBSTRINGS:
				r.check(not text.contains(str(banned)),
					"%d일째 밤 %d번째 손님 스냅샷에 '%s'가 새어 나갔다" % [night, i, banned])
			# 필드 화이트리스트. 새 필드가 붙으면 무엇이든 여기서 걸린다.
			for line in (_snapshot(night, i)["clipboard"] as Array):
				for key in (line as Dictionary).keys():
					r.check(ALLOWED_LINE_KEYS.has(str(key)),
						"클립보드 줄에 허용되지 않은 필드 '%s'가 붙었다 — 정답이 샐 수 있다" % key)
			# 거짓 수칙의 반증 단서는 실패한 **뒤에** 보여주는 것이다. 미리 주면 안 된다.
			for rule in GameData.load_rules():
				if rule.tell_key == "":
					continue
				r.check(not text.contains(_t(rule.tell_key)),
					"%d일째 밤 스냅샷에 %s의 반증 단서가 미리 들어 있다" % [night, rule.id])


## 화면에 그려지는 것은 빠짐없이 들어가야 한다. 빠지면 상대가 사람보다 불리해진다.
func _test_shows_everything_on_screen(r: RefCounted) -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	for night in plan.nights():
		var customers := plan.customers_for(night)
		for i in customers.size():
			var minutes := NightSession.arrival_minutes(i, customers.size())
			var snap := _snapshot(night, i)
			var shown := PackedStringArray()
			for line in (snap["clipboard"] as Array):
				if (line as Dictionary).has("id"):
					shown.append(str((line as Dictionary)["id"]))
			for rule in engine.visible_rules(night, minutes):
				r.check(shown.has(rule.id),
					"%d일째 밤 %s: 화면에 있는 수칙 %s가 스냅샷에 없다"
						% [night, ShiftClock.to_display(minutes), rule.id])

			# 손님의 모든 특성이 카운터나 CCTV 중 한쪽에는 있어야 한다.
			var counter := (snap["counter"] as Dictionary)["visible_traits"] as Dictionary
			var cctv := (snap["cctv"] as Dictionary)["visible_traits"] as Dictionary
			r.equals(counter.size() + cctv.size(), customers[i].trait_names().size(),
				"%s의 특성이 스냅샷에서 몇 개 사라졌다" % customers[i].id)


## 아직 안 붙은 줄은 화면에 없다 (밤 5). 스냅샷도 마찬가지여야 한다.
func _test_hides_rules_not_yet_posted(r: RefCounted) -> void:
	var late: Rule = null
	for rule in GameData.load_rules():
		if rule.arrives_mid_shift():
			late = rule
			break
	r.check(late != null, "근무 중에 붙는 수칙이 있어야 이 검사가 의미를 가진다")
	if late == null:
		return
	var plan := NightPlan.load()
	var customers := plan.customers_for(late.introduced_night)
	for i in customers.size():
		var minutes := NightSession.arrival_minutes(i, customers.size())
		if minutes >= late.arrives_at_minute:
			continue
		var text := JSON.stringify(_snapshot(late.introduced_night, i))
		r.check(not text.contains(late.id),
			"아직 안 붙은 수칙 %s가 %s 스냅샷에 들어 있다"
				% [late.id, ShiftClock.to_display(minutes)])


## 찢겨 나간 자리는 **자국으로** 보여야 한다 (밤 7). 그냥 사라지면 사람도 상대도 못 본다.
func _test_shows_torn_gap(r: RefCounted) -> void:
	var torn: Rule = null
	for rule in GameData.load_rules():
		if rule.removed_night != Rule.NO_REMOVAL:
			torn = rule
			break
	r.check(torn != null, "찢겨 나가는 수칙이 있어야 이 검사가 의미를 가진다")
	if torn == null:
		return
	var plan := NightPlan.load()
	var customers := plan.customers_for(torn.removed_night)
	var seen := false
	for i in customers.size():
		if NightSession.arrival_minutes(i, customers.size()) < torn.removed_at_minute:
			continue
		var snap := _snapshot(torn.removed_night, i)
		for line in (snap["clipboard"] as Array):
			if str((line as Dictionary).get("look", "")) == ScreenSnapshot.LOOK_TORN:
				seen = true
	r.check(seen, "찢긴 뒤 스냅샷에 찢긴 자국이 안 보인다")


func _t(key: String) -> String:
	return str(_strings().get(key, ""))
