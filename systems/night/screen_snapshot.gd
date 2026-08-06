class_name ScreenSnapshot
extends RefCounted

## **화면에 보이는 것만** 텍스트로 뽑는다. 눈을 대신하는 물건이다.
##
## 왜 필요한가: `tools/solver_audit.gd`의 솔버들은 전부 내가 정답을 알고 짠 전략이다.
## 정보 비대칭이 0이라 "이 게임이 풀리는가"는 검증해도 "**모르는 사람이 풀 수 있는가**"는
## 검증하지 못한다. 수칙 데이터를 한 번도 못 본 상대에게 화면만 주고 판정을 시키려면,
## 먼저 화면을 텍스트로 옮길 수 있어야 한다.
##
## **여기서 새어 나가면 안 되는 것**: veracity, tell_key, required_verdict, conflicts_with,
## anomaly, 그리고 정답 그 자체. 하나라도 새면 그 순간 블라인드 플레이가 아니게 되고,
## 그걸로 얻은 결론은 전부 무의미해진다.
## `tests/test_snapshot.gd`가 스냅샷 전문을 훑어 이 값들이 안 들어갔는지 검사한다.
##
## 반대로 **보이는 것은 빠짐없이** 넣어야 한다. 화면에 있는데 스냅샷에 없으면
## 상대는 사람보다 불리한 조건으로 푸는 것이고, 그 결과도 마찬가지로 무의미하다.

const OBSERVATION_PATH := "res://data/observation.json"

## 스냅샷을 읽는 쪽이 **얼마나 잘 보는가.** 이 값 없이 블라인드 플레이 결과를 인용하면 안 된다.
##
## `named`는 종이 색조 3.8% 차이와 잉크 번짐을 「남의 필체 · 나중에 덧쓴 종이」라는
## **문장**으로 바꿔 준다. 화면은 그 문장을 어디에도 쓰지 않는다 — 사람은 종이 두 장을
## 나란히 놓고 "다른가?"를 스스로 판단해야 한다. 즉 named로 얻은 정답률은 사람의 상한이 아니라
## **사람보다 잘 보는 관찰자의 정답률**이다. 그걸 사람 수치로 보고하면 거짓말이 된다.
##
## `raw`는 셰이더에 실제로 들어가는 숫자를 그대로 준다. 해석은 읽는 쪽 몫이다.
## 두 수준의 차이가 곧 **"이 단서를 알아보는 것"이 얼마나 어려운가**의 측정치다.
const PERCEPTION_NAMED := "named"
const PERCEPTION_RAW := "raw"

## 고쳐 쓴 줄 앞에 붙는 표식. **화면이 라벨 텍스트에 직접 찍는다** — 스냅샷도 같이 찍어야
## 사람과 같은 것을 본다. `clipboard_panel.gd`와 이 함수가 유일한 출처다.
static func line_prefix(rewritten: bool) -> String:
	return "✎ " if rewritten else "· "


## 이 줄의 종이가 **실제로 어떤 값으로 그려지는가.** UI와 스냅샷이 같은 함수를 쓴다.
##
## 예전에는 UI가 자기 상수를, 스냅샷이 자기 문자열을 따로 들고 있었다. 둘이 어긋나도
## 아무도 모르고, 어긋난 채로 나온 블라인드 플레이 결과는 통째로 무의미하다.
static func paper_values(foreign: bool, rewritten: bool, paper: Dictionary) -> Dictionary:
	var tone: float = float(paper.get("tone_later" if foreign else "tone_manager", 1.0))
	return {
		"paper_tone": float(paper.get("tone_rewritten", 1.055)) if rewritten else tone,
		"ink_bleed": float(paper.get("bleed_later" if foreign else "bleed_manager", 0.0)),
		"rewritten": 1.0 if rewritten else 0.0,
	}

## 판정 **뒤에** 화면에 뜨는 것. 결과 패널이 보여주는 것과 같아야 한다.
##
## 여기엔 반증 단서(tell)가 들어간다 — **그게 이 게임의 공정성 계약이다** (불변식 3).
## 실패한 뒤에 "알아챌 수 있었다"를 보여주지 않으면 그건 속인 것이다.
## 판정 **전에** 주면 안 되지만 **후에** 빼도 안 된다. 사람이 보는 것과 같아야 한다.
static func of_result(result: JudgeResult, strings: Dictionary) -> Dictionary:
	var out := {
		"correct": result.correct,
		"headline": _headline(result, strings),
	}
	if result.had_true_conflict and result.correct:
		out["note"] = _t(strings, "result.either_detail")
	if result.correct:
		return out
	out["right_call"] = _t(strings, "ui." + result.expected[0].id())
	var clues := PackedStringArray()
	for key in result.missed_clue_keys:
		clues.append(_t(strings, key))
	out["what_you_missed"] = clues
	return out


static func _headline(result: JudgeResult, strings: Dictionary) -> String:
	if result.correct and result.had_true_conflict:
		return _t(strings, "result.either")
	if result.correct:
		return _t(strings, "result.correct")
	if result.is_trap_death():
		return _t(strings, "result.trap_grace" if result.graced else "result.trap")
	return _t(strings, "result.wrong")


## 지금 이 손님을 판정하는 시점에 화면에 있는 것 전부.
static func of(
	engine: RuleEngine, ctx: JudgeContext, strings: Dictionary,
	struck: PackedStringArray, progress: Dictionary,
	perception: String = PERCEPTION_NAMED
) -> Dictionary:
	return {
		"night": ctx.night,
		"time": ctx.time_display(),
		"perception": perception,
		"progress": progress,
		"clipboard": _clipboard(engine, ctx, strings, struck, perception),
		"counter": _counter(ctx.customer, strings),
		"cctv": _cctv(ctx.customer, strings),
	}


## 클립보드. 지금 이 시점에 실제로 붙어 있는 줄 + 찢겨 나간 자리.
static func _clipboard(
	engine: RuleEngine, ctx: JudgeContext,
	strings: Dictionary, struck: PackedStringArray, perception: String
) -> Array:
	var paper: Dictionary = GameData.load_balance().get("clipboard_paper", {})
	var out := []
	for rule in engine.rules():
		if rule.introduced_night > ctx.night:
			continue
		if rule.was_removed_by(ctx.night, ctx.shift_minutes):
			out.append({
				"look": _look(true, false, strings, perception, paper, true),
				"text": _t(strings, "clipboard.torn"),
			})
			continue
		if not rule.is_active_at(ctx.night, ctx.shift_minutes):
			continue  # 아직 안 붙은 줄 — 화면에 없다
		var rewritten := rule.has_decayed_by(ctx.night)
		out.append({
			"id": rule.id,  # 상대가 "셋째 줄을 그어라"라고 말할 수 있어야 한다
			"look": _look(rule.hand_at(ctx.night) != Rule.HAND_MANAGER, rewritten,
				strings, perception, paper, false),
			"text": line_prefix(rewritten) + _t(strings, rule.text_key),
			"struck_by_me": struck.has(rule.id),
		})
	return out


## 종이가 어떻게 보이는가. 진위가 아니라 **생김새**다.
## `named`는 문장으로, `raw`는 셰이더가 받는 숫자 그대로. 왜 나누는지는 PERCEPTION_* 주석에 있다.
static func _look(
	foreign: bool, rewritten: bool, strings: Dictionary,
	perception: String, paper: Dictionary, torn: bool
) -> Variant:
	if perception == PERCEPTION_RAW:
		return {"torn": true} if torn else paper_values(foreign, rewritten, paper)
	if torn:
		return _t(strings, "look.torn")
	if rewritten:
		return _t(strings, "look.rewritten")
	return _t(strings, "look.later" if foreign else "look.manager")


## 카운터 앞. 손님 패널이 그리는 것과 같아야 한다 — CCTV 담당 특성은 빼고.
static func _counter(customer: Customer, strings: Dictionary) -> Dictionary:
	var lines := PackedStringArray()
	for key in customer.dialogue_keys:
		lines.append(_t(strings, key))
	var items := PackedStringArray()
	for key in customer.item_keys:
		items.append(_t(strings, key))
	return {
		"name": _t(strings, customer.name_key),
		"says": lines,
		"items": items,
		"visible_traits": _traits(customer, strings, false),
	}


## CCTV 모니터. 그림자는 여기서만 보인다 (F-04).
static func _cctv(customer: Customer, strings: Dictionary) -> Dictionary:
	return {"visible_traits": _traits(customer, strings, true)}


## 특성 표시. 있고 없음을 **둘 다** 넘긴다 — 화면이 ●/○ 로 둘 다 그리기 때문이다.
## 없는 것을 빼면 "그림자 없음" 같은 가장 중요한 단서가 통째로 사라진다.
static func _traits(customer: Customer, strings: Dictionary, want_cctv: bool) -> Dictionary:
	var on_cctv := Customer._to_string_array(
		GameData.read_json(OBSERVATION_PATH).get("cctv_traits", []))
	var out := {}
	for name in customer.trait_names():
		if on_cctv.has(name) != want_cctv:
			continue
		out[_t(strings, "trait." + name)] = bool(customer.get_trait(name))
	return out


static func _t(strings: Dictionary, key: String) -> String:
	return str(strings.get(key, "<%s>" % key))
