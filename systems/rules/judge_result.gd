class_name JudgeResult
extends RefCounted

## 판정 한 번의 결과.
##
## 실패했을 때 `missed_clue_keys`가 비어 있으면 안 된다 — 공정성 불변식 3(3초 리플레이)은
## "무엇을 놓쳤는지"를 항상 보여줄 수 있어야 성립한다.

var correct: bool = false
var player_verdict: Verdict = null
var expected: Array[Verdict] = []
var applied_true_rules: Array[Rule] = []
var lies_in_play: Array[Rule] = []
var trap_triggered: bool = false
var had_true_conflict: bool = false
var missed_clue_keys: PackedStringArray = []

## 이 판정이 첫 함정 유예로 넘어갔는가. NightSession이 채운다.
## 세션의 `grace_used`는 한 번 켜지면 계속 켜져 있으므로, "이번 판정이 유예됐는가"는
## 결과 쪽에 따로 기록해야 두 번째 함정에 유예 문구가 잘못 뜨지 않는다.
var graced: bool = false

## 3초 리플레이(F-07)가 화면에서 짚어줄 대상.
## 문자열 키만으로는 "어느 줄을 밝힐지"를 알 수 없다.
var missed_rule_ids: PackedStringArray = []
var decisive_fields: PackedStringArray = []


func expected_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for v in expected:
		out.append(v.id())
	return out


## 거짓 수칙을 그대로 따랐다가 틀린 경우. H1(거짓 수칙이 재미인가)의 관측 지점이다.
func is_trap_death() -> bool:
	return not correct and trap_triggered
