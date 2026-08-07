class_name Playthrough
extends RefCounted

## **회차 하나.** 7박을 이어서 돌리고 어디서 끝났는지 기록한다.
##
## 이 클래스가 존재하는 이유는 한 문장이다: **밤 하나만 보는 검사는 밤 사이의 결함을 못 본다.**
##
## 실제로 못 봤다. 검사 12,000개가 통과하는 동안 유예가 밤마다 새로 생기고 있었고,
## 화면은 「이번은 넘어간다 — 다음부터는 아니다」라고 써놓고 다음 밤에 또 넘어갔다.
## 밤 단위로 보면 전부 정상이다. 사람이 두 밤을 이어서 해보고서야 찾았다.
##
## 그리고 이걸 만들자마자 더 큰 것이 잡혔다 — **손님만 보고 클립보드를 한 줄도 안 읽는
## 플레이어가 7박을 전부 통과했다.** 밤마다 오판 1~2회씩만 나서 한도 3에 한 번도 안 닿았다.
## 「어느 밤에도 만점을 못 낸다」는 불변식은 통과하고 있었다. 만점이 아니라 **통과**가 문제였다.
##
## 노드에 의존하지 않는다 (CLAUDE.md 2절). 도구와 검사가 같은 것을 본다.

## 밤별 결과. `{night, correct, total, misjudges, traps, graced}`
var per_night: Array[Dictionary] = []
## 실패한 밤. 0이면 끝까지 갔다.
var died_at: int = 0
## 회차 전체에서 유예가 실제로 쓰인 횟수. **1을 넘으면 유예가 밤마다 새로 생기는 것이다.**
var graced_total: int = 0


func finished_the_run() -> bool:
	return died_at == 0


## `strategy`가 비면 매번 정답을 낸다. 아니면 `JudgeContext`를 받아 `Verdict`를 돌려주는 함수다.
static func play(
	plan: NightPlan, rules: Array[Rule], balance: Dictionary, strategy: Callable = Callable()
) -> Playthrough:
	var run := Playthrough.new()
	# **유예는 회차가 들고 있다.** 밤마다 초기화하면 이 클래스는 자기 존재 이유를 잃는다.
	var grace_spent := false
	for night in plan.nights():
		var session := NightSession.new(
			RuleEngine.new(rules), plan.customers_for(night), balance, night, grace_spent)
		var graced := run._play_night(session, strategy)
		grace_spent = grace_spent or session.grace_used
		run.graced_total += graced
		run.per_night.append({
			"night": night,
			"correct": session.correct_count,
			"total": session.total_customers(),
			"misjudges": session.misjudge_count,
			"traps": session.trap_count,
			"graced": graced,
		})
		if session.is_failed():
			run.died_at = night
			return run
	return run


func _play_night(session: NightSession, strategy: Callable) -> int:
	var graced := 0
	while not session.is_finished():
		var ctx := session.current_context()
		var chosen: Verdict = session.engine.required_verdicts(ctx)[0] \
			if strategy.is_null() else strategy.call(ctx)
		if session.judge(chosen).graced:
			graced += 1
		session.advance()
	return graced
