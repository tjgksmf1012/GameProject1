class_name RuleEngine
extends RefCounted

## 이 게임의 심장. Godot 노드를 상속하지 않으므로 헤드리스 테스트가 가능하다 (CLAUDE.md 2절).
##
## 가장 중요한 규칙 하나:
##   **정답은 오직 참 수칙만으로 결정된다.**
## 거짓 수칙은 정답에 한 표도 행사하지 못한다. 그래서 거짓 수칙을 그대로 따르면 틀린다.
## 이게 "규칙을 지켰는가"가 아니라 "어떤 규칙을 믿을 것인가"를 묻는 게임이 되는 지점이다.

## 적용되는 참 수칙이 하나도 없을 때의 기본 판정. 평범한 손님은 그냥 응대하면 된다.
const DEFAULT_VERDICT := Verdict.SERVE

## 발동한 참 수칙이 하나도 없는데 플레이어가 틀린 경우의 단서.
## "아무 수칙도 이 손님을 막지 않았다"는 사실 자체가 단서다. 이 경로가 없으면
## 멀쩡한 손님을 거부했을 때 게임이 이유를 대지 못하고 공정성 불변식 3이 깨진다.
const CLUE_NO_RULE_APPLIED := "clue.no_rule_applied"

var _rules: Array[Rule] = []


func _init(p_rules: Array[Rule] = []) -> void:
	_rules = p_rules


func rules() -> Array[Rule]:
	return _rules


## 이 밤에 클립보드에 붙어 있는 수칙 전부 (조건 일치 여부와 무관).
func visible_rules(night: int) -> Array[Rule]:
	var out: Array[Rule] = []
	for r in _rules:
		if r.is_active_at(night):
			out.append(r)
	return out


## 지금 이 손님에게 실제로 발동하는 수칙 전부. 참·거짓을 가리지 않는다.
func applicable_rules(ctx: JudgeContext) -> Array[Rule]:
	var out: Array[Rule] = []
	for r in _rules:
		if r.is_active_at(ctx.night) and r.matches(ctx):
			out.append(r)
	return out


## 발동한 수칙 중 거짓인 것들. 플레이어를 죽이려고 기다리는 것들이다.
func lies_in_play(ctx: JudgeContext) -> Array[Rule]:
	var out: Array[Rule] = []
	for r in applicable_rules(ctx):
		if r.is_lie_at(ctx.night):
			out.append(r)
	return out


## 발동한 수칙 중 참인 것들. 정답은 여기서만 나온다.
func truths_in_play(ctx: JudgeContext) -> Array[Rule]:
	var out: Array[Rule] = []
	for r in applicable_rules(ctx):
		if not r.is_lie_at(ctx.night):
			out.append(r)
	return out


## 허용되는 판정 목록. 참 수칙끼리 충돌하면 복수 반환한다 (밤 3의 "수칙 간 모순").
func required_verdicts(ctx: JudgeContext) -> Array[Verdict]:
	var out: Array[Verdict] = []
	for r in truths_in_play(ctx):
		var v := r.verdict()
		if not Verdict.contains(out, v):
			out.append(v)
	if out.is_empty():
		out.append(Verdict.from_id(DEFAULT_VERDICT))
	return out


func evaluate(ctx: JudgeContext, player_verdict: Verdict) -> JudgeResult:
	var result := JudgeResult.new()
	result.player_verdict = player_verdict
	result.applied_true_rules = truths_in_play(ctx)
	result.lies_in_play = lies_in_play(ctx)
	result.expected = required_verdicts(ctx)
	result.had_true_conflict = result.expected.size() > 1
	result.correct = Verdict.contains(result.expected, player_verdict)
	if not result.correct:
		result.trap_triggered = _followed_a_lie(result.lies_in_play, player_verdict)
		result.missed_clue_keys = _clues_for_failure(result)
		_mark_replay_targets(result)
	return result


## 플레이어의 판정이 발동 중인 거짓 수칙 중 하나와 정확히 일치하는가.
static func _followed_a_lie(lies: Array[Rule], player_verdict: Verdict) -> bool:
	for lie in lies:
		if lie.verdict().equals(player_verdict):
			return true
	return false


## 3초 리플레이가 밝힐 줄과 특성을 고른다 (F-07).
## 함정에 걸렸으면 나를 속인 거짓 수칙을, 아니면 내가 어긴 참 수칙을 짚는다.
static func _mark_replay_targets(result: JudgeResult) -> void:
	var rules: Array[Rule] = []
	if result.trap_triggered:
		for lie in result.lies_in_play:
			if lie.verdict().equals(result.player_verdict):
				rules.append(lie)
	for r in result.applied_true_rules:
		if not r.verdict().equals(result.player_verdict):
			rules.append(r)
	for rule in rules:
		if not result.missed_rule_ids.has(rule.id):
			result.missed_rule_ids.append(rule.id)
		for field in rule.referenced_fields():
			if not result.decisive_fields.has(field):
				result.decisive_fields.append(field)


## 공정성 불변식 3: 실패했다면 무엇을 놓쳤는지 항상 말해줄 수 있어야 한다.
static func _clues_for_failure(result: JudgeResult) -> PackedStringArray:
	var out := PackedStringArray()
	if result.trap_triggered:
		for lie in result.lies_in_play:
			if lie.verdict().equals(result.player_verdict) and lie.tell_key != "":
				out.append(lie.tell_key)
	for r in result.applied_true_rules:
		if not r.verdict().equals(result.player_verdict) and not out.has(r.text_key):
			out.append(r.text_key)
	if out.is_empty():
		out.append(CLUE_NO_RULE_APPLIED)
	return out
