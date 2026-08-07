class_name Readings
extends RefCounted

## **플레이어가 클립보드를 읽는 방식들.** 하나하나가 「이렇게 읽으면 어떻게 되는가」다.
##
## 원래 `tools/solver_audit.gd` 안에 있었다. 거기서 꺼낸 이유가 둘이다.
##
## 하나. **밤 하나만 보는 감사는 밤 사이의 결함을 못 본다.** 유예가 밤마다 새로 생기던
## 결함이 그랬다 — 밤 단위 검사 12,000개가 전부 통과하는 동안 회차로 보면 게임이
## 자기가 한 약속을 매일 밤 어기고 있었다. 회차 감사(`tools/run_audit.gd`)가 필요했고,
## 그러려면 독법이 두 도구에서 같아야 한다. 복사하면 반드시 갈라진다.
##
## 둘. 독법은 노드가 필요 없는 **순수 판단**이라 `systems/`에 있어야 맞다 (CLAUDE.md 2절).
## 여기 있으면 헤드리스로 검증할 수 있고, `solver_audit.gd`는 300줄 상한 아래로 돌아온다.
##
## 각 독법은 `JudgeContext`를 받아 `Verdict`를 돌려준다. **정답을 참조하지 않는다** —
## 화면에 보이는 것(클립보드·손님)만으로 판단한다. 그게 이 독법들의 존재 이유다.

const NAIVE := "클립보드를 전부 믿는 플레이어"
const SKEPTICAL := "모순된 수칙을 전부 버리는 플레이어"
const OVERRIDE := "나중 수칙이 앞 수칙을 덮는다고 보는 플레이어"
const VOICE := "이유를 대는 줄은 거짓이라고 보는 플레이어"
const BODY := "클립보드를 안 읽고 손님만 보는 플레이어"
const BODY_CLOCK := "몸과 시계만 보는 플레이어"

var _engine: RuleEngine = null
var _anomaly_spec: Dictionary = {}


func _init(engine: RuleEngine, anomaly_spec: Dictionary) -> void:
	_engine = engine
	_anomaly_spec = anomaly_spec


## 이름 → 판정 함수. 도구들이 이걸 돌면서 밤을 채점한다.
func all() -> Dictionary:
	return {
		NAIVE: _naive,
		SKEPTICAL: _skeptical,
		OVERRIDE: _override,
		VOICE: _voice,
		BODY: _body,
		BODY_CLOCK: _body_clock,
	}


## 그 시점에 **플레이어가 실제로 읽을 수 있는** 줄. 아직 안 붙었거나 찢긴 줄은 빠진다.
func _readable(ctx: JudgeContext) -> Array[Rule]:
	return _engine.visible_rules(ctx.night, ctx.shift_minutes)


func _conflicts(a: Rule, b: Rule) -> bool:
	return a.conflicts_with.has(b.id) or b.conflicts_with.has(a.id)


func _has_conflicting_partner(ctx: JudgeContext, target: Rule) -> bool:
	for other in _readable(ctx):
		if other.id != target.id and _conflicts(target, other):
			return true
	return false


## 클립보드를 전부 참으로 믿고, 모순이 나면 위에 적힌 수칙을 따른다.
func _naive(ctx: JudgeContext) -> Verdict:
	for rule in _readable(ctx):
		if rule.matches(ctx):
			return rule.verdict()
	return Verdict.serve()


## 모순에 연루된 수칙은 믿을 수 없다고 보고 전부 버린다.
func _skeptical(ctx: JudgeContext) -> Verdict:
	for rule in _readable(ctx):
		if rule.matches(ctx) and not _has_conflicting_partner(ctx, rule):
			return rule.verdict()
	return Verdict.serve()


## 가장 자연스러운 오독. "단골에게는 다른 수칙을 적용하지 마시오" 같은 예외 조항은
## 법조문처럼 **뒤에 온 것이 앞을 덮는다**고 읽힌다. 그게 이 게임의 진짜 함정이다.
## 첫 매칭만 따르는 플레이어는 참 수칙이 앞에 나열돼 있어서 우연히 잘 맞는다 —
## 이 독법이 그 착시를 걷어낸다.
func _override(ctx: JudgeContext) -> Verdict:
	var chosen: Verdict = Verdict.serve()
	for rule in _readable(ctx):
		if rule.matches(ctx):
			chosen = rule.verdict()
	return chosen


## **문체만 보고 푸는 플레이어.** 「이유를 대면 거짓」이라 믿고 그 줄들을 버린다.
##
## 이 독법이 만점을 내면 게임이 정규식 한 줄로 풀린다는 뜻이다. 실제로 그런 적이 있다 —
## 문체를 veracity에서 파생시켰더니 수칙 11개를 11/11 분류하는 완전 분류기가 됐다.
func _voice(ctx: JudgeContext) -> Verdict:
	for rule in _readable(ctx):
		if rule.gives_reason:
			continue  # 변명하는 줄은 거짓이라고 보고 버린다
		if rule.matches(ctx):
			return rule.verdict()
	return Verdict.serve()


## **클립보드를 아예 안 읽는 플레이어.** 손님의 몸만 보고, 이상이 있으면 돌려보낸다.
##
## 이 게임의 세계관을 그대로 정책으로 만든 것이다 — 사람이 아닌 것은 몸에서 드러난다.
## 넷째 수칙(가방)처럼 **모순이 없는 거짓**을 잡는 유일한 경로이므로 강할 수밖에 없다.
## 그래서 감시가 필요하다: 이 독법이 만점을 내면 수칙을 읽을 이유가 사라진다.
func _body(ctx: JudgeContext) -> Verdict:
	return Verdict.refuse() if ctx.customer.looks_anomalous(_anomaly_spec) else Verdict.serve()


## **몸 + 시계.** 실제 플레이어가 가장 먼저 찾을 지름길이다.
##
## 몸만 보는 독법을 밤 2에서 죽이고 나서 든 의문에서 나왔다: 몸만 보는 사람이 지던
## 손님이 거의 전부 **시간 수칙**이었다. 「평범한데 거부가 정답」인 이유가 시계 말고는
## 거의 없다는 뜻이고, 그러면 **시계 두 줄만 더 읽으면** 그 패배가 사라진다.
##
## 클립보드 11줄 중 두 줄만 읽는 셈이라 「안 읽는다」와 다를 게 없다.
## 이게 회차를 통과하면 나머지 아홉 줄이 장식이 된다.
func _body_clock(ctx: JudgeContext) -> Verdict:
	if ctx.customer.looks_anomalous(_anomaly_spec):
		return Verdict.refuse()
	# 시간 조건이 붙은 참 수칙만 읽는다. 어느 밤에 무엇이 붙어 있는지는 화면에서 온다.
	for rule in _readable(ctx):
		if rule.matches(ctx) and _is_clock_rule(rule):
			return rule.verdict()
	return Verdict.serve()


static func _is_clock_rule(rule: Rule) -> bool:
	return rule.referenced_fields().has(JudgeContext.FIELD_TIME)
