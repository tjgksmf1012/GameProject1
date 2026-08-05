class_name PatienceClock
extends RefCounted

## 손님이 카운터 앞에서 기다린 시간. **죽이지 않는다 — 조이기만 한다.**
##
## 인내가 다하면 대신 판정해 버리거나 오판으로 세는 설계를 먼저 검토했고 버렸다.
## 이 게임은 수칙 일곱 줄을 읽고 CCTV와 대조해야 한다. 시간으로 죽이면
## **꼼꼼히 읽는 행동이 처벌받는다.** 그건 코어 루프를 정면으로 거스른다
## (F-05가 클립보드에 스크롤을 준 이유가 읽는 데 시간이 걸리기 때문이다).
## 그래서 인내는 긴장도를 올리고 손님이 재촉하게 만들 뿐, 판정에 손대지 않는다.
##
## **모든 손님이 똑같이 재촉한다.** 이상 손님만 다르게 굴면 플레이어는 관찰 대신
## 기다리기로 푼다 — 그 순간 CCTV도 클립보드도 필요 없어진다.
## `ui/screen_effects.gd`가 셰이더에 대해 경고하는 것과 같은 함정이다.

const STAGE_CALM := 0
const STAGE_URGING := 1
const STAGE_DEMANDING := 2

const DEFAULT_URGE_AT := 0.55
const DEFAULT_DEMAND_AT := 0.85
const DEFAULT_TENSION_BOOST := 0.25

var _limit_seconds: float = 45.0
var _elapsed: float = 0.0
var _running: bool = false
var _urge_at: float = DEFAULT_URGE_AT
var _demand_at: float = DEFAULT_DEMAND_AT
var _tension_boost: float = DEFAULT_TENSION_BOOST


static func from_balance(balance: Dictionary) -> PatienceClock:
	var clock := PatienceClock.new()
	var d := balance.get("patience", {}) as Dictionary
	clock._urge_at = float(d.get("urge_at", DEFAULT_URGE_AT))
	clock._demand_at = float(d.get("demand_at", DEFAULT_DEMAND_AT))
	clock._tension_boost = float(d.get("tension_boost", DEFAULT_TENSION_BOOST))
	return clock


## 새 손님이 왔다. 시계를 0으로 되돌리고 다시 돌린다.
func start(customer: Customer) -> void:
	_limit_seconds = maxf(1.0, float(customer.patience_seconds))
	_elapsed = 0.0
	_running = true


## 판정이 끝났다. **여기서 세우지 않으면 이미 떠난 손님이 결과 화면 위에서 계속 재촉한다.**
func stop() -> void:
	_running = false


## 흘려보낸다. 단계가 바뀐 프레임에만 true — 호출자가 그때만 대사를 갈아 끼우면 된다.
func tick(delta: float) -> bool:
	if not _running:
		return false
	var before := stage()
	_elapsed += maxf(0.0, delta)
	return stage() != before


## 0.0 = 방금 왔다, 1.0 = 인내가 다했다. 다한 뒤에도 1.0에서 멈춘다.
func pressure() -> float:
	return clampf(_elapsed / _limit_seconds, 0.0, 1.0)


func stage() -> int:
	var p := pressure()
	if p >= _demand_at:
		return STAGE_DEMANDING
	if p >= _urge_at:
		return STAGE_URGING
	return STAGE_CALM


## 밤 진행도에서 나온 긴장도 위에 얹을 몫. 총합은 호출자가 1.0으로 자른다.
func tension_bonus() -> float:
	return pressure() * _tension_boost


func elapsed_seconds() -> float:
	return _elapsed
