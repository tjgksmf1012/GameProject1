extends SceneTree

## 화면을 텍스트로 뽑는다. **블라인드 플레이의 입력**이다.
##
##   godot --headless --script res://tools/observe.gd -- --night=3 --index=4
##   godot --headless --script res://tools/observe.gd -- --night=3 --all
##   godot --headless --script res://tools/observe.gd -- --night=3 --all --perception=raw
##
## `tools/solver_audit.gd`의 솔버들은 내가 정답을 알고 짠 전략이라 정보 비대칭이 0이다.
## 이건 다르다 — 수칙 데이터를 한 번도 못 본 상대에게 이 출력만 주고 판정을 받으면,
## 그때 나오는 결과는 **모르는 사람이 풀 수 있는가**에 대한 실제 증거가 된다.
##
## 출력에 정답이 섞이지 않는다는 보장은 `tests/test_snapshot.gd`가 한다.
## 그 검사가 깨진 채로 여기서 나온 결론은 전부 버려야 한다.
##
## `--perception=raw`는 종이 차이를 문장 대신 **셰이더가 받는 숫자**로 준다.
## 기본값(named)은 사람이 눈으로 판단해야 할 것을 대신 판단해 주므로, 그 정답률은
## 사람의 상한이 아니다. 두 수준을 모두 돌려 차이를 함께 보고할 것.
##
## `--misjudge=`는 지금까지 낸 오판 수다. 화면 오른쪽 위에 「오판 2 / 3」으로 늘 떠 있다 —
## 안 넘기면 상대는 사람보다 불리한 조건에서 푸는 것이고, 그 결과도 무의미해진다.

const STRUCK_ARG := "--struck="


func _initialize() -> void:
	var night := int(_arg("--night=", "1"))
	var plan := NightPlan.load()
	if not plan.has_night(night):
		push_error("그런 밤이 없다: %d" % night)
		quit(1)
		return

	var engine := RuleEngine.new(GameData.load_rules())
	var strings := GameData.load_strings(GameData.resolve_locale())
	var customers := plan.customers_for(night)
	var struck := _arg(STRUCK_ARG, "").split(",", false)
	var perception := _arg("--perception=", ScreenSnapshot.PERCEPTION_NAMED)

	var wants_all := OS.get_cmdline_user_args().has("--all")
	var out := []
	for i in customers.size():
		if not wants_all and i != int(_arg("--index=", "0")):
			continue
		var ctx := JudgeContext.new(
			night, NightSession.arrival_minutes(i, customers.size()), customers[i])
		out.append(ScreenSnapshot.of(engine, ctx, strings, struck, {
			"customer": i + 1,
			"total": customers.size(),
			"misjudge": int(_arg("--misjudge=", "0")),
			"misjudge_limit": int(GameData.load_balance().get("misjudge_limit", 3)),
		}, perception))
	print(JSON.stringify(out if wants_all else out[0], "  "))
	quit(0)


static func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
