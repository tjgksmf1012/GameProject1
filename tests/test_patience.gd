extends RefCounted

## 인내 시계. **이 시계가 판정에 손대면 게임이 망가진다** — 그걸 검사한다.
##
## 시간으로 죽이는 설계를 버렸으므로 (`systems/night/patience_clock.gd` 주석),
## 여기서 지켜야 할 것은 두 가지다:
##   ① 압박은 손님마다 **똑같은 속도**로 온다 — 이상 손님이 다르게 굴면 기다리기로 풀린다
##   ② 긴장 기여분은 유한하다 — 가만히 있는 것만으로 화면이 최대로 조여지면 안 된다

const CUSTOMER_POOL := "res://data/customers"


func run(r: RefCounted) -> void:
	r.suite("patience")
	_test_stages_advance_in_order(r)
	_test_pressure_is_bounded(r)
	_test_restart_on_new_customer(r)
	_test_stops_after_verdict(r)
	_test_every_customer_presses_the_same(r)
	_test_tension_bonus_cannot_dominate(r)


func _clock() -> PatienceClock:
	return PatienceClock.from_balance(GameData.load_balance())


## 60초짜리 손님 하나로 세 단계를 통과시킨다.
func _test_stages_advance_in_order(r: RefCounted) -> void:
	var clock := _clock()
	clock.start(_customer_with_patience(60))
	r.equals(clock.stage(), PatienceClock.STAGE_CALM, "막 도착한 손님은 조용하다")

	var seen := PackedInt32Array([clock.stage()])
	for i in 60:
		if clock.tick(1.0):
			seen.append(clock.stage())
	r.equals(seen.size(), 3, "단계는 정확히 두 번 바뀐다 (%s)" % str(seen))
	r.equals(seen[1], PatienceClock.STAGE_URGING, "먼저 재촉한다")
	r.equals(seen[2], PatienceClock.STAGE_DEMANDING, "그다음 노골적이 된다")


## 인내가 다한 뒤에도 계속 흐른다. 1.0에서 멈추지 않으면 긴장이 무한히 오른다.
func _test_pressure_is_bounded(r: RefCounted) -> void:
	var clock := _clock()
	clock.start(_customer_with_patience(10))
	clock.tick(600.0)
	r.equals(clock.pressure(), 1.0, "압박은 1.0에서 멈춘다")
	r.equals(clock.stage(), PatienceClock.STAGE_DEMANDING, "마지막 단계에 머문다")
	# 단계가 더 바뀌면 대사가 계속 갈아 끼워진다.
	r.check(not clock.tick(600.0), "다한 뒤에는 단계가 더 바뀌지 않는다")


func _test_restart_on_new_customer(r: RefCounted) -> void:
	var clock := _clock()
	clock.start(_customer_with_patience(20))
	clock.tick(19.0)
	r.check(clock.stage() != PatienceClock.STAGE_CALM, "오래 기다린 손님은 조용하지 않다")
	clock.start(_customer_with_patience(20))
	r.equals(clock.stage(), PatienceClock.STAGE_CALM, "다음 손님은 처음부터 시작한다")
	r.equals(clock.elapsed_seconds(), 0.0, "시계가 0으로 돌아간다")


## 판정이 끝나면 시계가 선다. 안 서면 이미 떠난 손님이 결과 화면 위에서 계속 재촉한다.
## 프레임을 돌려보기 전까지 못 봤던 버그다 — 테스트로는 안 잡히고 화면에서도 조용히 틀린다.
func _test_stops_after_verdict(r: RefCounted) -> void:
	var clock := _clock()
	clock.start(_customer_with_patience(30))
	clock.tick(5.0)
	clock.stop()
	var frozen := clock.pressure()
	r.check(not clock.tick(300.0), "판정 뒤에는 단계가 바뀌지 않는다")
	r.equals(clock.pressure(), frozen, "판정 뒤에는 압박이 오르지 않는다")
	clock.start(_customer_with_patience(30))
	r.check(clock.tick(29.0), "다음 손님에서 시계가 다시 돈다")


## **이 검사가 이 파일의 존재 이유다.**
##
## 이상 손님만 다르게 굴면 플레이어는 CCTV도 클립보드도 보지 않고 기다리기만 하면 된다.
## 그래서 인내는 손님의 특성이 아니라 `patience_seconds` 하나로만 결정돼야 한다.
func _test_every_customer_presses_the_same(r: RefCounted) -> void:
	for customer in GameData.load_customers():
		var clock := _clock()
		clock.start(customer)
		var half := float(customer.patience_seconds) * 0.5
		clock.tick(half)
		var expected := PatienceClock.STAGE_CALM
		# 절반 지점의 단계는 오직 balance.json 의 임계값으로만 결정된다.
		if 0.5 >= PatienceClock.DEFAULT_DEMAND_AT:
			expected = PatienceClock.STAGE_DEMANDING
		elif 0.5 >= _urge_at():
			expected = PatienceClock.STAGE_URGING
		r.equals(clock.stage(), expected,
			"손님 %s의 절반 지점 압박이 다른 손님과 같다" % customer.id)
		r.check(is_equal_approx(clock.pressure(), 0.5),
			"손님 %s의 절반 지점 압박이 0.5다" % customer.id)


func _urge_at() -> float:
	var d := GameData.load_balance().get("patience", {}) as Dictionary
	return float(d.get("urge_at", PatienceClock.DEFAULT_URGE_AT))


## 가만히 있는 것만으로 화면이 최대로 조여지면, 오판으로 오르는 긴장이 의미를 잃는다.
func _test_tension_bonus_cannot_dominate(r: RefCounted) -> void:
	var clock := _clock()
	clock.start(_customer_with_patience(30))
	clock.tick(300.0)
	var bonus := clock.tension_bonus()
	r.check(bonus > 0.0, "기다리면 긴장이 오른다")
	r.check(bonus < 0.5,
		"기다리는 것만으로 긴장의 절반을 넘길 수 없다 (%.2f)" % bonus)


func _customer_with_patience(seconds: int) -> Customer:
	var c := Customer.new()
	c.id = "test_customer"
	c.patience_seconds = seconds
	return c
