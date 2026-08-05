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
## `is_active_at`에 시각을 안 넘겼다는 표시. "밤 전체" 관점을 뜻한다.
const ANY_TIME := -1

## 누가 썼는가. `veracity`와 **별개의 개념**이다.
## 지금은 거짓 수칙이 전부 `later`지만, 나중 밤에는 참 수칙을 남의 필체로 써서
## 플레이어의 학습을 배신할 수 있어야 한다. 그래서 진위와 분리해 둔다.
const HAND_MANAGER := "manager"
const HAND_LATER := "later"

var id: String = ""
var text_key: String = ""
var veracity: String = VERACITY_TRUE
var conditions: Array[Condition] = []
var required_verdict: String = Verdict.SERVE
var introduced_night: int = 1
## 근무 시작(22:00) 기준 몇 분 뒤에 클립보드에 붙는가. 0이면 밤 시작부터 있다.
## **0이 아니면 근무 중에 누군가 써넣은 줄이다.** 그 전에 판정한 손님에게는
## 존재하지 않았으므로 평가에도 들어가면 안 된다 (공정성 불변식 1).
var arrives_at_minute: int = 0
var decays_at_night: int = NO_DECAY
var conflicts_with: PackedStringArray = []
var tell_key: String = ""
var hand: String = HAND_MANAGER


static func from_dict(d: Dictionary) -> Rule:
	var r := Rule.new()
	r.id = str(d.get("id", ""))
	r.text_key = str(d.get("text_key", ""))
	r.veracity = str(d.get("veracity", VERACITY_TRUE))
	r.required_verdict = str(d.get("required_verdict", Verdict.SERVE))
	r.introduced_night = int(d.get("introduced_night", 1))
	r.arrives_at_minute = int(d.get("arrives_at_minute", 0))
	r.decays_at_night = int(d.get("decays_at_night", NO_DECAY))
	r.tell_key = str(d.get("tell_key", ""))
	r.hand = str(d.get("hand", HAND_MANAGER))
	r.conflicts_with = Customer._to_string_array(d.get("conflicts_with", []))
	for raw in (d.get("conditions", []) as Array):
		r.conditions.append(Condition.from_dict(raw as Dictionary))
	return r


## 이 밤에 클립보드에 붙어 있는가.
##
## `shift_minutes`가 음수면 **밤 전체를 통틀어** 붙어 있는지 묻는 것이다 (공정성 감사용).
## 판정할 때는 반드시 그 시점의 분을 넘겨야 한다 — 안 넘기면 아직 존재하지도 않는 줄로
## 손님을 판정하게 된다.
func is_active_at(night: int, shift_minutes: int = ANY_TIME) -> bool:
	if night < introduced_night:
		return false
	return shift_minutes < 0 or shift_minutes >= arrives_at_minute


## 근무 중에 써넣은 줄인가.
func arrives_mid_shift() -> bool:
	return arrives_at_minute > 0


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


## 점장이 아닌 누군가가 덧쓴 줄인가. 종이와 잉크가 다르다 (F-05).
func is_foreign_hand() -> bool:
	return hand != HAND_MANAGER


## 그 밤 기준의 필체. **전환된 수칙은 그 밤부터 남의 필체로 읽힌다.**
##
## 어제 맞던 수칙이 오늘 틀리는데 종이가 그대로면 그건 "속았다"가 된다.
## 누군가 고쳐 썼다는 게 화면에 보여야 공정성 불변식 2가 성립한다.
func hand_at(night: int) -> String:
	if has_decayed_by(night):
		return HAND_LATER
	return hand


## 이 밤에 전환이 이미 일어났는가. 클립보드가 고쳐 쓴 자국을 그릴지 정한다.
func has_decayed_by(night: int) -> bool:
	return veracity == VERACITY_DECAYING and decays_at_night != NO_DECAY \
		and night >= decays_at_night


func verdict() -> Verdict:
	return Verdict.from_id(required_verdict)


## 이 수칙이 참조하는 모든 필드 경로. 공정성 불변식 1 검증에 쓰인다.
func referenced_fields() -> PackedStringArray:
	var out := PackedStringArray()
	for c in conditions:
		if not out.has(c.field):
			out.append(c.field)
	return out
