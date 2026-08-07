extends SceneTree

## **회차 감사.** 7박을 이어서 돌린다.
##   godot --headless --script res://tools/run_audit.gd
##
## 이 프로젝트의 검사는 전부 밤 하나만 봤다. 12,201개가 통과하는 동안 게임은
## 자기가 한 유일한 약속을 매일 밤 어기고 있었다 — 「이번은 넘어간다, 다음부터는 아니다」라고
## 써놓고 다음 밤에 또 넘어갔다. `NightSession`이 밤마다 새로 생기니 유예도 같이
## 새로 생겼고, **밤 하나만 보는 눈에는 그게 정상으로 보인다.**
##
## 사람이 두 밤을 이어서 해보고서야 찾았다. 그 눈을 도구로 옮긴 것이 이 파일이다.
##
## 세 가지를 묻는다. 전부 **회차 단위로만 대답이 되는 질문**이다:
##   1. 유예는 회차 전체에서 한 번만 쓰이는가
##   2. 어떤 고정 독법도 7박을 끝까지 가지 못하는가
##   3. 정답만 내면 7박을 끝까지 갈 수 있는가 (게임이 클리어 가능한가)
##
## 실패하면 0이 아닌 코드로 끝난다.

const SEPARATOR := "──────────────────────────────────────────────────────────"

var _failures: PackedStringArray = []


func _initialize() -> void:
	var rules := GameData.load_rules()
	var plan := NightPlan.load()
	var balance := GameData.load_balance()
	var spec: Dictionary = GameData.read_json("res://data/observation.json").get(
		"anomaly_traits", {})
	var readings := Readings.new(RuleEngine.new(rules), spec)

	print("회차 감사 — %d박을 이어서 돌린다\n" % plan.nights().size())
	_run("정답만 내는 플레이어", plan, rules, balance, Callable(), true)
	for label in readings.all():
		_run(label, plan, rules, balance, readings.all()[label], false)
	_report()
	quit(1 if _failures.size() > 0 else 0)


## 한 독법으로 회차를 끝까지 돌리고 표로 찍는다. 실제 진행은 `systems/night/playthrough.gd`.
func _run(
	label: String, plan: NightPlan, rules: Array[Rule], balance: Dictionary,
	strategy: Callable, must_finish: bool
) -> void:
	print("%s\n%s\n%s" % [SEPARATOR, label, SEPARATOR])
	var run := Playthrough.play(plan, rules, balance, strategy)
	for row in run.per_night:
		print("  밤 %d   정답 %2d/%2d   오판 %d   속음 %d%s"
			% [row["night"], row["correct"], row["total"], row["misjudges"], row["traps"],
				"   ← 유예" if int(row["graced"]) > 0 else ""])
	if run.died_at > 0:
		print("  밤 %d 에서 실패." % run.died_at)
	_judge_run(label, plan, run.graced_total, run.died_at, must_finish)


func _judge_run(
	label: String, plan: NightPlan, graced_total: int, died_at: int, must_finish: bool
) -> void:
	# 1. 유예는 회차에 한 번이다. 밤마다 새로 생기면 여기가 7까지 올라간다.
	if graced_total > 1:
		_failures.append(
			"「%s」 회차에서 유예가 %d번 쓰였다 — 밤마다 새로 생긴다" % [label, graced_total])
	if must_finish:
		# 3. 정답을 내면 반드시 끝까지 간다. 아니면 게임이 클리어 불가능하다.
		if died_at > 0:
			_failures.append("정답만 내는데도 밤 %d에서 실패했다 — 클리어 불가능한 밤이다" % died_at)
		else:
			print("  → 완주.")
		return
	# 2. 고정 독법은 어딘가에서 죽어야 한다.
	if died_at == 0:
		_failures.append(
			"「%s」 하나로 %d박 전부를 통과했다 — 이 독법이 게임을 푼다" % [label, plan.nights().size()])
	else:
		print("  → 밤 %d에서 끝. 유예 %d회." % [died_at, graced_total])


func _report() -> void:
	print("\n%s\n회차 불변식\n%s" % [SEPARATOR, SEPARATOR])
	if _failures.is_empty():
		print("  통과 — 유예는 회차당 1회, 고정 독법은 전부 도중에 죽고, 정답 경로는 완주한다")
		return
	for line in _failures:
		print("  ✗ %s" % line)
