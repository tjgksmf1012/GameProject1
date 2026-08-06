extends RefCounted

## 공정성 불변식 중 **채널 불변식**만 모았다 (2c · 2d · 2e · 2f).
##
## 이 게임에서 거짓 수칙을 사전에 알아내는 경로는 넷이다:
##   (a) 다른 수칙과의 모순    — 유일하게 결정적이다. 불변식 2b가 본다.
##   (b) 필체와 종이           — 언제 쓰였는지만 말한다.        2c · 2d
##   (c) 문체                  — 이유를 대는가.                  2e
##   (d) 손님의 몸             — 이상이 있는가.                  2f
##   (e) 손님이 기다리는 시간   — 얼마나 참는가.                  2g
##
## (b)(c)(d)는 전부 **용의자를 좁힐 뿐 진위를 결정하지 못해야 한다.** 하나라도
## 1:1이 되는 순간 이 게임은 그 채널 하나로 풀린다 — 추론이 아니라 색깔 맞추기가 된다.
## 세 파일에 흩어 놓으면 다음에 새 채널을 만들 때 이 규칙을 잊는다. 그래서 한자리에 둔다.
##
## 실제로 두 번 뚫렸다. 필체를 진위와 묶어 놨다가 2c로 끊었고, 그 다음 문체가
## 그 자리를 대신 차지해 정규식 한 줄이 수칙 11개를 11/11 맞혔다 (2e).
## **채널을 하나 끊으면 다음 채널이 그 일을 넘겨받는다.** 그게 이 파일의 존재 이유다.

## 한 채널에 1~2줄뿐이면 "이쪽은 전부 참"이 학습 가능한 규칙이 되지 않는다.
## 임계는 밸런싱 값이 아니라 이 판단이다 — 그래서 balance.json이 아니라 여기 있다.
const PATTERN_THRESHOLD := 3

var _rules: Array[Rule] = []


func run(r: RefCounted) -> void:
	r.suite("fairness_channels")
	_rules = GameData.load_rules()
	for night in NightPlan.load().nights():
		_invariant_2c_hand_must_not_solve_it(r, night)
		_invariant_2d_manager_hand_must_not_be_free(r, night)
		_invariant_2e_voice_must_not_solve_it(r, night)
	_invariant_2f_body_must_not_solve_it(r)
	_invariant_2g_patience_must_not_solve_it(r)


## 그 밤에 클립보드에 붙어 있는 수칙.
func _active(night: int) -> Array[Rule]:
	var out: Array[Rule] = []
	for rule in _rules:
		if rule.is_active_at(night):
			out.append(rule)
	return out


## 채널을 참/거짓으로 갈라 센다. `on_channel`은 수칙 하나를 받아 이쪽 편인지 답한다.
func _split(night: int, on_channel: Callable) -> Dictionary:
	var truths := 0
	var lies := 0
	for rule in _active(night):
		if not on_channel.call(rule):
			continue
		if rule.is_lie_at(night):
			lies += 1
		else:
			truths += 1
	return {"truths": truths, "lies": lies}


## 한쪽 편이 **순수하면** 그 방향으로 완전 분류가 성립한다.
## `needed`가 0인데 표본이 임계 이상이면 실패다. 임계 미만은 패턴을 가르치지 못하므로 봐준다.
func _require_counterexample(r: RefCounted, split: Dictionary, needed: String, message: String) -> void:
	var total: int = split["truths"] + split["lies"]
	var trigger: String = "lies" if needed == "truths" else "truths"
	if split[trigger] == 0 or total < PATTERN_THRESHOLD:
		return
	r.check(split[needed] > 0, message % split[trigger])


## 2c — **필체가 진위를 1:1로 결정하면 안 된다.**
##
## 남의 필체가 곧 거짓이면 플레이어는 한 번 학습한 뒤 종이 색만 보고 전부 푼다.
## 코어 훅이 추론에서 색깔 맞추기로 전락한다 (F-05가 경고한 "너무 명확하면 퍼즐이 죽는다").
## 역할 분담을 강제한다: 필체는 **용의자를 좁히고**, 진위는 다른 단서가 정한다.
##
## 여기만 임계가 없다. 남의 필체로 쓴 거짓이 하나라도 있으면 참도 하나는 있어야 한다 —
## 이 채널은 종이 색이라 한눈에 보이고, 두 줄만으로도 즉시 학습된다.
func _invariant_2c_hand_must_not_solve_it(r: RefCounted, night: int) -> void:
	var split := _split(night, func(rule: Rule) -> bool:
		return rule.hand_at(night) != Rule.HAND_MANAGER)
	if split["lies"] == 0:
		return  # 남의 필체로 쓴 거짓이 없으면 이 위험 자체가 없다
	r.check(split["truths"] > 0,
		"불변식2c: %d일째 밤은 남의 필체가 전부 거짓이다 — 종이 색만 보면 다 풀린다" % night)


## 2c의 뒷면. **점장 필체가 곧 참이면 그 줄들은 공짜가 된다.**
##
## 2c는 "남의 필체 = 거짓"만 막는다. 반대쪽이 뚫려 있으면 플레이어는
## "점장이 쓴 줄은 그냥 믿는다"는 완벽한 지름길을 얻는다. 클립보드의 절반이 퍼즐에서 빠진다.
## 밤 3에서 둘째 수칙이 전환돼 점장 필체가 1줄만 남았을 때 이게 드러났다.
## 본편에서 이 구멍을 막는 방법은 정해져 있다: **점장 필체로 쓰인 거짓 수칙** (03-PRD.md 3.4).
func _invariant_2d_manager_hand_must_not_be_free(r: RefCounted, night: int) -> void:
	_require_counterexample(r, _split(night, func(rule: Rule) -> bool:
		return rule.hand_at(night) == Rule.HAND_MANAGER),
		"lies",
		"불변식2d: " + str(night) + "일째 밤은 점장 필체 %d줄이 전부 참이다 — 그 줄들은 읽지 않고 믿어도 된다")


## 2e — **「이유를 대면 거짓」이 성립하면 이 게임은 정규식으로 풀린다.**
##
## 실제로 그랬다. 문체 규약을 `veracity`에서 파생시켰더니 한국어 인과 연결어미
## 하나(`니[\s,]`)가 수칙 11개의 진위를 **11/11 맞혔다.** 필체 상관은 2c로 끊어놓고
## 문체 상관은 만들어 놓은 것이고, `tests/test_rule_voice.gd`가 그걸 강제하고 있었다.
##
## 양방향으로 본다: 이유를 대는 줄 중에 참이 하나는 있어야 하고,
## 명령만 하는 줄 중에 거짓이 하나는 있어야 한다.
func _invariant_2e_voice_must_not_solve_it(r: RefCounted, night: int) -> void:
	var pleading := _split(night, func(rule: Rule) -> bool: return rule.gives_reason)
	var bare := _split(night, func(rule: Rule) -> bool: return not rule.gives_reason)
	_require_counterexample(r, pleading, "truths",
		"불변식2e: " + str(night) + "일째 밤은 이유를 대는 줄 %d개가 전부 거짓이다 — 문체만 보면 다 풀린다")
	_require_counterexample(r, bare, "lies",
		"불변식2e: " + str(night) + "일째 밤은 명령만 하는 줄 %d개가 전부 참이다 — 문체만 보면 다 풀린다")


## 2f — **어느 밤에도 클립보드를 안 읽고 만점을 낼 수 없어야 한다.**
##
## 이 채널은 다른 셋과 성질이 다르다. 클립보드가 아니라 **손님**에 붙어 있고,
## 넷째 수칙(가방)처럼 모순이 없는 거짓을 잡는 유일한 경로다. 이 게임의 세계관 자체이기도 하다 —
## 사람이 아닌 것은 언제나 몸에서 드러난다. 그래서 "이상 없는 사람을 돌려보내라"는 줄은 의심스럽다.
##
## 그래서 강할 수밖에 없고, 그래서 감시가 필요하다. 이 정책이 어느 밤에 만점을 내면
## 그 밤은 수칙을 한 줄도 안 읽고 통과할 수 있다. 그 밤의 내용은 장식이 된다.
##
## 수칙을 세는 게 아니라 **실제로 점수를 매긴다.** 처음에는 "평범한 사람을 돌려보내는
## 참 수칙이 하나라도 있는가"로 셌는데, 그건 통과하면서 밤 3이 9/9로 뚫려 있었다 —
## 그 참 수칙(새벽 두 시 이후 술)이 하필 밤 3에 전환돼 거짓이 되기 때문이다.
## 수칙 목록으로는 안 보이고 점수로는 보인다. 물어야 할 것을 직접 물어야 한다.
func _invariant_2f_body_must_not_solve_it(r: RefCounted) -> void:
	var spec: Dictionary = GameData.read_json("res://data/observation.json").get("anomaly_traits", {})
	r.check(not spec.is_empty(),
		"불변식2f: observation.json에 anomaly_traits가 없다 — 몸 채널이 통째로 검사되지 않는다")
	var engine := RuleEngine.new(_rules)
	var plan := NightPlan.load()
	for night in plan.nights():
		var customers := plan.customers_for(night)
		var wrong := 0
		for i in customers.size():
			var ctx := JudgeContext.new(night, NightSession.arrival_minutes(i, customers.size()),
				customers[i])
			var chosen := Verdict.refuse() if customers[i].looks_anomalous(spec) else Verdict.serve()
			if not engine.evaluate(ctx, chosen).correct:
				wrong += 1
		r.check(wrong > 0,
			"불변식2f: %d일째 밤은 몸만 보고 %d명 전원을 맞힐 수 있다 — 클립보드를 안 읽어도 되는 밤이다"
				% [night, customers.size()])


## 2g — **손님이 얼마나 참는가가 이상 여부를 흘리면 안 된다.**
##
## 이건 클립보드도 몸도 아니고 **시간**에 붙은 채널이다. 그래서 다른 검사가 전부 못 봤다.
##
## 실제로 뚫려 있었다. 평범한 손님 평균 42.8초, 이상 손님 54.3초 — 50초 넘게 기다리는
## 손님 32명 중 29명이 이상이었다. 「오래 기다리면 이상」이 91% 분류기다.
## `patience_clock.gd`와 `customer_view.gd` 주석이 둘 다 이걸 금지한다고 적어놨는데
## 데이터가 어기고 있었고 아무도 검사하지 않았다.
##
## 이게 특히 위험한 이유: 기다리는 데에는 **아무 관찰도 필요 없다.** 이 채널이 살아 있으면
## CCTV도 클립보드도 안 보고 초만 세면 된다 — 게임이 통째로 우회된다.
const PATIENCE_MEAN_TOLERANCE := 3.0


func _invariant_2g_patience_must_not_solve_it(r: RefCounted) -> void:
	var spec: Dictionary = GameData.read_json("res://data/observation.json").get("anomaly_traits", {})
	var odd := []
	var plain := []
	for customer in GameData.load_customers():
		if customer.looks_anomalous(spec):
			odd.append(customer.patience_seconds)
		else:
			plain.append(customer.patience_seconds)
	r.check(odd.size() > 0 and plain.size() > 0,
		"불변식2g: 두 무리가 다 있어야 이 검사가 의미를 가진다")
	if odd.is_empty() or plain.is_empty():
		return
	r.check(absf(_mean(odd) - _mean(plain)) <= PATIENCE_MEAN_TOLERANCE,
		"불변식2g: 이상 손님은 평균 %.1f초, 평범한 손님은 %.1f초 참는다 — 초만 세면 풀린다"
			% [_mean(odd), _mean(plain)])
	# 평균이 같아도 **한쪽 전용 값**이 있으면 그 값이 곧 답이다.
	_require_shared(r, plain, odd, "평범한 손님에게만 나온다 — 그 초를 세면 이상이 아님을 안다")
	_require_shared(r, odd, plain, "이상 손님에게만 나온다 — 그 초를 세면 이상임을 안다")


func _require_shared(r: RefCounted, mine: Array, theirs: Array, why: String) -> void:
	var seen := []
	for value in mine:
		if seen.has(value):
			continue
		seen.append(value)
		r.check(theirs.has(value), "불변식2g: %d초는 %s" % [value, why])


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0
	for value in values:
		total += int(value)
	return float(total) / float(values.size())
