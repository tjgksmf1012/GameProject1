extends SceneTree

## **H2(압박인가)를 측정 가능한 부분까지 밀어붙인다.**
##   godot --headless --script res://tools/reading_load.gd -- --locale=ko
##
## 「무섭게 압박이 오는가」는 사람이 필요하다. 하지만 그 밑에 깔린 것은 사람 없이도 잰다:
## **판정 한 번에 읽고 대조해야 하는 양이, 손님이 기다려 주는 시간에 비해 얼마나 되는가.**
##
## 읽기 속도는 사람마다 다르고 나는 그걸 모른다. 그래서 절대 초를 단정하지 않고
## **범위**로 내고, 진짜 결론은 밤 사이 **비율**에서 뽑는다 — 읽기량이 인내보다 빨리
## 늘어나면 압박은 설계로 보장된다. 비율은 읽기 속도 상수가 약분돼 사라지므로
## 내가 모르는 값에 결론이 매달리지 않는다.
##
## 한 숫자로는 거짓말이 된다. 그래서 **두 줄로 낸다**:
##   처음 — 클립보드를 통째로 읽는다. 첫 밤의 사람이고, 상한선이다.
##   익힘 — 어젯밤 읽은 줄은 안 다시 읽는다. 새 줄·고쳐 쓴 줄·찢긴 자리와 손님만 읽는다.
## 진실은 그 사이 어딘가에 있고, **두 줄이 모두 인내를 넘으면 그건 설계 문제**다.

## 한국어 묵독 속도. 쉬운 산문은 분당 600음절도 나오지만 이건 **대조하며 읽는 글**이다.
## 그래서 느린 쪽으로 잡고, 하나로 단정하지 않고 범위로 둔다.
const SYLLABLES_PER_MINUTE_FAST := 400.0
const SYLLABLES_PER_MINUTE_SLOW := 220.0
## 특성 하나를 화면에서 찾아 수칙과 맞춰 보는 데 드는 시간. 눈이 두 화면을 오간다.
const SECONDS_PER_TRAIT_CHECK := 1.2
## data/balance.json 의 patience.urge_at. 여기를 넘으면 손님이 재촉하기 시작한다.
const URGE_AT := 0.55

var _strings: Dictionary = {}


func _initialize() -> void:
	_strings = GameData.load_strings(GameData.resolve_locale())
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	print("밤  수칙  누구   글자  대조   추정 초(느림~빠름)  인내 초  인내 대비  재촉 전  읽기량 배수")
	print("──  ────  ────   ────  ────   ─────────────────  ───────  ────────  ──────  ──────────")
	var base := {}
	for night in plan.nights():
		for learned in ([false] if night == plan.nights()[0] else [false, true]):
			var row := _measure_night(engine, plan, night, learned)
			if base.is_empty():
				base = row
			_print_row(night, row, base, learned)
		print("")
	print("\n인내 대비 1.0을 넘으면 **다 읽기 전에 손님이 떠난다.**")
	print("재촉 전 1.0을 넘으면 다 읽기도 전에 재촉이 시작된다 (urge_at).")
	quit(0)


## 이 밤의 손님 하나당 평균 부하. 손님마다 다르지만 밤끼리 비교하려면 대표값이 필요하다.
func _measure_night(
	engine: RuleEngine, plan: NightPlan, night: int, learned: bool
) -> Dictionary:
	var customers := plan.customers_for(night)
	var syllables := 0
	var checks := 0
	var patience := 0
	for i in customers.size():
		var minutes := NightSession.arrival_minutes(i, customers.size())
		for rule in engine.visible_rules(night, minutes):
			if learned and not _is_new_tonight(rule, night):
				continue  # 어젯밤에 읽었고 종이도 그대로다
			syllables += _t(rule.text_key).length()
			# 수칙마다 참조하는 특성을 화면에서 찾아 맞춰 봐야 한다.
			checks += rule.referenced_fields().size()
		# 손님은 매번 처음 본다. 익힌 플레이어도 이건 못 건너뛴다.
		syllables += _t(customers[i].name_key).length()
		for key in customers[i].dialogue_keys:
			syllables += _t(key).length()
		checks += customers[i].trait_names().size()
		patience += customers[i].patience_seconds
	var n := maxi(customers.size(), 1)
	return {
		"rules": engine.visible_rules(night).size(),
		"syllables": syllables / n,
		"checks": checks / n,
		"patience": float(patience) / float(n),
	}


## 오늘 처음 보거나 오늘 달라진 줄인가. 익힌 플레이어가 다시 읽어야 하는 것은 이것뿐이다.
func _is_new_tonight(rule: Rule, night: int) -> bool:
	return rule.introduced_night == night or rule.has_decayed_by(night) \
		and rule.decays_at_night == night


func _seconds(row: Dictionary, per_minute: float) -> float:
	return float(row["syllables"]) / per_minute * 60.0 + float(row["checks"]) * SECONDS_PER_TRAIT_CHECK


func _print_row(night: int, row: Dictionary, base: Dictionary, learned: bool) -> void:
	var slow := _seconds(row, SYLLABLES_PER_MINUTE_SLOW)
	var fast := _seconds(row, SYLLABLES_PER_MINUTE_FAST)
	var patience: float = row["patience"]
	print("%2d  %4d  %s   %4d  %4d   %6.1f ~ %5.1f     %6.1f  %7.2f  %6.2f  %8.2f"
		% [night, row["rules"], "익힘" if learned else "처음",
			row["syllables"], row["checks"], slow, fast, patience,
			slow / patience, slow / (patience * URGE_AT),
			slow / _seconds(base, SYLLABLES_PER_MINUTE_SLOW)])


func _t(key: String) -> String:
	return str(_strings.get(key, ""))
