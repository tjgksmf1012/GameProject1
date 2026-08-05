class_name NightSession
extends RefCounted

## 하룻밤 한 번의 진행. 노드에 의존하지 않으므로 헤드리스로 밤 전체를 돌려볼 수 있다.

var engine: RuleEngine = null
var customers: Array[Customer] = []
var night: int = 1

var index: int = 0
var correct_count: int = 0
var misjudge_count: int = 0
var trap_count: int = 0
var grace_used: bool = false

var _misjudge_limit: int = 3
var _grace_enabled: bool = true



func _init(p_engine: RuleEngine, p_customers: Array[Customer], balance: Dictionary, p_night: int = 1) -> void:
	engine = p_engine
	customers = p_customers
	night = p_night
	_misjudge_limit = int(balance.get("misjudge_limit", 3))
	_grace_enabled = bool(balance.get("grace_on_first_trap", true))


func current_customer() -> Customer:
	if index < 0 or index >= customers.size():
		return null
	return customers[index]


func current_context() -> JudgeContext:
	return JudgeContext.new(night, arrival_minutes(index, customers.size()), current_customer())


## 손님이 도착하는 시각. 인원 수로 근무 시간(22:00~06:00)을 균등하게 나눈다.
## 밤마다 인원이 달라도 마지막 손님이 항상 새벽에 오도록 하기 위해서다.
static func arrival_minutes(index: int, total: int) -> int:
	return int(float(index) * float(ShiftClock.SHIFT_LENGTH_MINUTES) / maxf(1.0, float(total)))


## 판정하고 결과를 돌려준다. 진행은 `advance()`로 따로 옮긴다 — 결과 화면을 보여줘야 하므로.
func judge(player_verdict: Verdict) -> JudgeResult:
	var result := engine.evaluate(current_context(), player_verdict)
	if result.correct:
		correct_count += 1
		return result
	if result.is_trap_death():
		trap_count += 1
		if _grace_enabled and not grace_used:
			# 첫 함정은 세지 않는다. 아직 "수칙이 거짓말한다"는 문법을 배우기 전이다.
			grace_used = true
			result.graced = true
			return result
	misjudge_count += 1
	return result


func advance() -> void:
	index += 1


func is_finished() -> bool:
	return index >= customers.size() or is_failed()


func is_failed() -> bool:
	return misjudge_count >= _misjudge_limit


func misjudge_limit() -> int:
	return _misjudge_limit


func total_customers() -> int:
	return customers.size()
