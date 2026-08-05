class_name Rule
extends RefCounted

## 점장이 남긴 수칙 하나.
##
## 이 게임의 코어 훅은 **수칙 중 일부가 거짓이라는 것**이다.
## 거짓 수칙을 따르면 죽는다. 그래서 정답은 오직 참 수칙만으로 결정된다 (RuleEngine 참고).
##
## 공정성 불변식 2: 거짓 수칙은 반드시 사전에 반증 가능한 단서(`tell_key`)를 남긴다.
## 단서 없는 거짓 수칙은 "속았다"가 되고, 그 순간 이 게임은 불공정해진다.

const VERACITY_TRUE := "true"
const VERACITY_FALSE := "false"
const VERACITY_DECAYING := "decaying"

const NO_DECAY := -1

var id: String = ""
var text_key: String = ""
var veracity: String = VERACITY_TRUE
var conditions: Array[Condition] = []
var required_verdict: String = Verdict.SERVE
var introduced_night: int = 1
var decays_at_night: int = NO_DECAY
var conflicts_with: PackedStringArray = []
var tell_key: String = ""


static func from_dict(d: Dictionary) -> Rule:
	var r := Rule.new()
	r.id = str(d.get("id", ""))
	r.text_key = str(d.get("text_key", ""))
	r.veracity = str(d.get("veracity", VERACITY_TRUE))
	r.required_verdict = str(d.get("required_verdict", Verdict.SERVE))
	r.introduced_night = int(d.get("introduced_night", 1))
	r.decays_at_night = int(d.get("decays_at_night", NO_DECAY))
	r.tell_key = str(d.get("tell_key", ""))
	r.conflicts_with = Customer._to_string_array(d.get("conflicts_with", []))
	for raw in (d.get("conditions", []) as Array):
		r.conditions.append(Condition.from_dict(raw as Dictionary))
	return r


## 이 밤에 클립보드에 붙어 있는가.
func is_active_at(night: int) -> bool:
	return night >= introduced_night


## 이 밤 기준으로 이 수칙이 거짓인가.
## `decaying`은 특정 밤부터 거짓으로 전환된다 — 어제 맞던 수칙이 오늘 틀린다.
func is_lie_at(night: int) -> bool:
	if veracity == VERACITY_FALSE:
		return true
	if veracity == VERACITY_DECAYING:
		return decays_at_night != NO_DECAY and night >= decays_at_night
	return false


## 조건이 전부 참인가 (AND).
func matches(ctx: JudgeContext) -> bool:
	for c in conditions:
		if not c.evaluate(ctx):
			return false
	return true


func verdict() -> Verdict:
	return Verdict.from_id(required_verdict)


## 이 수칙이 참조하는 모든 필드 경로. 공정성 불변식 1 검증에 쓰인다.
func referenced_fields() -> PackedStringArray:
	var out := PackedStringArray()
	for c in conditions:
		if not out.has(c.field):
			out.append(c.field)
	return out
