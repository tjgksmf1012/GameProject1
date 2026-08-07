extends RefCounted

## **회차 불변식.** 밤 하나가 아니라 7박을 이어서 본다.
##
## 이 파일이 생긴 이유는 여기 있는 검사들이 전부, 밤 단위 검사 12,000개가 통과하는 동안
## 깨져 있던 것들이기 때문이다. 밤 하나만 보면 전부 정상으로 보인다.
##
## 유예가 밤마다 새로 생기던 것도, 몸만 보는 플레이어가 7박을 전부 통과하던 것도
## **회차로 봐야만 보였다.** 도구(`tools/run_audit.gd`)로만 두면 아무도 안 돌린다.
## 유예 결함이 살아남은 방식이 정확히 그거였다 — 볼 수 있는 도구가 없었다.

var _plan: NightPlan = null
var _rules: Array[Rule] = []
var _balance: Dictionary = {}


func run(r: RefCounted) -> void:
	r.suite("playthrough")
	_plan = NightPlan.load()
	_rules = GameData.load_rules()
	_balance = GameData.load_balance()
	_test_correct_play_finishes(r)
	_test_no_fixed_reading_finishes(r)
	_test_grace_is_once_per_run(r)


## 게임이 클리어 가능한가. 이걸 안 물으면 나머지는 전부 의미가 없다.
func _test_correct_play_finishes(r: RefCounted) -> void:
	var run := Playthrough.play(_plan, _rules, _balance)
	r.check(run.finished_the_run(),
		"정답만 내는데도 밤 %d에서 실패한다 — 클리어 불가능한 밤이 있다" % run.died_at)
	r.equals(run.per_night.size(), _plan.nights().size(), "7박을 전부 돈다")


## **어떤 고정 독법도 회차를 끝내면 안 된다.**
##
## 밤 단위 감시는 「만점」을 봤다. 그런데 만점이 아니어도 이긴다 — 한도가 오판 3회이므로
## 밤마다 1~2개씩만 틀리면 통과다. 몸만 보는 플레이어가 정확히 그렇게 7박을 전부 지나갔고,
## 그 회차에서 클립보드는 **한 줄도 읽히지 않았다.** 이 게임의 전부가 클립보드인데.
func _test_no_fixed_reading_finishes(r: RefCounted) -> void:
	for label in _readings().all():
		var run := Playthrough.play(_plan, _rules, _balance, _readings().all()[label])
		r.check(not run.finished_the_run(),
			"「%s」 하나로 %d박 전부를 통과할 수 있다 — 이 독법이 게임을 푼다"
				% [label, _plan.nights().size()])


## 유예의 근거는 학습이고, 학습은 한 번이다 (balance.json `_comment_grace`).
## 밤마다 새로 주면 화면의 「다음부터는 아니다」가 매일 밤 거짓말이 된다.
func _test_grace_is_once_per_run(r: RefCounted) -> void:
	for label in _readings().all():
		var run := Playthrough.play(_plan, _rules, _balance, _readings().all()[label])
		r.check(run.graced_total <= 1,
			"「%s」 회차에서 유예가 %d번 쓰였다 — 밤마다 새로 생긴다" % [label, run.graced_total])


func _readings() -> Readings:
	return Readings.new(RuleEngine.new(_rules),
		GameData.read_json("res://data/observation.json").get("anomaly_traits", {}))
