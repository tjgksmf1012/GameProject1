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

## 클립보드에 붙지만 **판정에 참여하지 않는 줄.**
##
## 이야기를 나르려고 새 화면이나 새 시스템을 만들지 않는다. 종이가 이미
## 필체·전환·도착·찢김을 전부 말할 줄 알기 때문에, 이야기도 같은 문법으로 말한다.
## 메모는 `veracity`가 없으므로 채널 불변식(2c·2d·2e)에서 자동으로 빠지고,
## 정답에는 한 표도 행사하지 않는다 — `RuleEngine`이 아예 다른 목록에 넣는다.
##
## **메모는 명령하지 않는다.** 조건도 지시도 없는 문장만 쓴다. 명령형이 하나라도
## 섞이면 플레이어는 그걸 지키려 들고, 지킬 수 없는 줄을 지키려는 순간 게임이 불공정해진다.
const KIND_RULE := "rule"
const KIND_NOTE := "note"

const NO_DECAY := -1
const NO_REMOVAL := -1
## `is_active_at`에 시각을 안 넘겼다는 표시. "밤 전체" 관점을 뜻한다.
const ANY_TIME := -1

## 누가 썼는가. `veracity`와 **별개의 개념**이다.
## 지금은 거짓 수칙이 전부 `later`지만, 나중 밤에는 참 수칙을 남의 필체로 써서
## 플레이어의 학습을 배신할 수 있어야 한다. 그래서 진위와 분리해 둔다.
const HAND_MANAGER := "manager"
const HAND_LATER := "later"

var id: String = ""
var text_key: String = ""
var kind: String = KIND_RULE
var veracity: String = VERACITY_TRUE
var conditions: Array[Condition] = []
var required_verdict: String = Verdict.SERVE
var introduced_night: int = 1
## 근무 시작(22:00) 기준 몇 분 뒤에 클립보드에 붙는가. 0이면 밤 시작부터 있다.
## **0이 아니면 근무 중에 누군가 써넣은 줄이다.** 그 전에 판정한 손님에게는
## 존재하지 않았으므로 평가에도 들어가면 안 된다 (공정성 불변식 1).
var arrives_at_minute: int = 0
## 어느 밤 몇 분에 **찢겨 나가는가.** `NO_REMOVAL`이면 끝까지 남는다.
## 찢긴 뒤에는 그 줄로 판정하지 않는다 — 클립보드에 없는 줄로 죽이면 불변식 1이 깨진다.
var removed_night: int = NO_REMOVAL
var removed_at_minute: int = 0
var decays_at_night: int = NO_DECAY
var conflicts_with: PackedStringArray = []
var tell_key: String = ""
var hand: String = HAND_MANAGER
## 문구가 **이유를 대는가**(변명하는가). `veracity`에서 파생하지 않는 authored 속성이다.
##
## 파생시켰더니 「이유를 대면 거짓」이 수칙 11개를 11/11 맞히는 완전 분류기가 됐다 —
## 필체 상관을 끊어놓고(불변식 2c) 문체 상관을 대신 만든 셈이다.
## 불변식 2e 가 이 상관을 감시한다.
var gives_reason: bool = false


static func from_dict(d: Dictionary) -> Rule:
	var r := Rule.new()
	r.id = str(d.get("id", ""))
	r.text_key = str(d.get("text_key", ""))
	r.kind = str(d.get("kind", KIND_RULE))
	r.veracity = str(d.get("veracity", VERACITY_TRUE))
	r.required_verdict = str(d.get("required_verdict", Verdict.SERVE))
	r.introduced_night = int(d.get("introduced_night", 1))
	r.arrives_at_minute = int(d.get("arrives_at_minute", 0))
	r.removed_night = int(d.get("removed_night", NO_REMOVAL))
	r.removed_at_minute = int(d.get("removed_at_minute", 0))
	r.decays_at_night = int(d.get("decays_at_night", NO_DECAY))
	r.tell_key = str(d.get("tell_key", ""))
	r.hand = str(d.get("hand", HAND_MANAGER))
	r.gives_reason = bool(d.get("gives_reason", false))
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
	if was_removed_by(night, shift_minutes):
		return false
	return shift_minutes < 0 or shift_minutes >= arrives_at_minute


## 이 시점에 이미 찢겨 나갔는가.
##
## `shift_minutes`가 음수(밤 전체 관점)면 **찢긴 밤에도 아직 있는 것으로 본다** —
## 그 밤의 앞부분에는 실제로 붙어 있었고, 공정성 감사는 밤 단위로 세기 때문이다.
func was_removed_by(night: int, shift_minutes: int = ANY_TIME) -> bool:
	if removed_night == NO_REMOVAL:
		return false
	if night > removed_night:
		return true
	if night < removed_night or shift_minutes < 0:
		return false
	return shift_minutes >= removed_at_minute


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


## 판정에 참여하지 않는 메모인가.
func is_note() -> bool:
	return kind == KIND_NOTE


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
