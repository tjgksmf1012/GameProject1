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

## 클립보드 한 줄이 화면에서 어떻게 보이는가. **진위는 여기 없다.**
## 종이·잉크·표식은 사람 눈에 보이는 것이므로 그대로 넘긴다 (F-05).
const LOOK_MANAGER := "점장 필체 · 원래 종이"
const LOOK_LATER := "남의 필체 · 나중에 덧쓴 종이"
const LOOK_REWRITTEN := "고쳐 쓴 자국(✎) · 덧댄 새 종이"
const LOOK_TORN := "찢겨 나간 자리"


## 지금 이 손님을 판정하는 시점에 화면에 있는 것 전부.
static func of(
	engine: RuleEngine, ctx: JudgeContext, strings: Dictionary,
	struck: PackedStringArray, progress: Dictionary
) -> Dictionary:
	return {
		"night": ctx.night,
		"time": ctx.time_display(),
		"progress": progress,
		"clipboard": _clipboard(engine, ctx.night, ctx.shift_minutes, strings, struck),
		"counter": _counter(ctx.customer, strings),
		"cctv": _cctv(ctx.customer, strings),
	}


## 클립보드. 지금 이 시점에 실제로 붙어 있는 줄 + 찢겨 나간 자리.
static func _clipboard(
	engine: RuleEngine, night: int, minutes: int,
	strings: Dictionary, struck: PackedStringArray
) -> Array:
	var out := []
	for rule in engine.rules():
		if rule.introduced_night > night:
			continue
		if rule.was_removed_by(night, minutes):
			out.append({"look": LOOK_TORN, "text": _t(strings, "clipboard.torn")})
			continue
		if not rule.is_active_at(night, minutes):
			continue  # 아직 안 붙은 줄 — 화면에 없다
		out.append({
			"id": rule.id,  # 상대가 "셋째 줄을 그어라"라고 말할 수 있어야 한다
			"look": _look(rule, night),
			"text": _t(strings, rule.text_key),
			"struck_by_me": struck.has(rule.id),
		})
	return out


## 종이가 어떻게 보이는가. 진위가 아니라 **생김새**다.
static func _look(rule: Rule, night: int) -> String:
	if rule.has_decayed_by(night):
		return LOOK_REWRITTEN
	return LOOK_LATER if rule.hand_at(night) != Rule.HAND_MANAGER else LOOK_MANAGER


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
