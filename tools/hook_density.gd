extends SceneTree

## **훅 밀도.** 손님 한 명이 판단인가 조회인가.
##   godot --headless --script res://tools/hook_density.gd
##
## H1(거짓 수칙이 재미인가)은 사람이 답해야 한다. 하지만 그 앞에 반드시 참이어야 하는 것이
## 하나 있고, 그건 잴 수 있다: **손님 대부분이 그냥 대조로 끝나면 훅은 있으나 마나다.**
##
## 블라인드 플레이가 이걸 정확히 짚어냈다. 밤 1의 여섯 판 중 반응이 있었던 것은 둘뿐이고
## (거짓 수칙에 걸린 판, 참 수칙끼리 부딪힌 판) 나머지 넷은 「규칙을 기계적으로 대조하면
## 끝나는 절차」였다. 그 말이 맞는지 밤 7개 전부에 대해 센다.
##
## 네 갈래로 센다. 배타적으로 나누지 않는다 — 한 손님이 함정이면서 모순일 수 있고,
## 그걸 한 칸에 몰아넣으면 밤 6의 참 수칙 충돌처럼 **더 무거운 사건 뒤에 숨는다.**
##   함정 — 발동 중인 거짓 수칙이 **진실과 다른 판정을 요구한다.** 따르면 틀린다.
##   무해 — 거짓 수칙이 발동은 했는데 우연히 정답과 같다. 플레이어는 아무것도 못 느낀다.
##   모순 — 참 수칙끼리 서로 다른 판정을 요구한다. 걸러내도 답이 하나로 안 좁혀진다.
##   조회 — 아무 일도 없다. 수칙 한 줄 찾아 대조하면 끝난다.
##
## 처음엔 「거짓 수칙이 발동했는가」로 셌고 73%가 나왔다. 블라인드 플레이어는 여섯 판 중
## 둘에만 반응했는데 숫자는 넷이라고 했다. **발동한 것과 무는 것은 다르다** — 밤 1의
## 셋째 수칙은 젖은 손님에게 발동하지만 그 손님의 정답도 판매라 아무 일도 일어나지 않는다.
## 사람이 느낀 쪽이 맞았고 내 첫 정의가 틀렸다.
##
## 조회가 나쁜 것은 아니다. 숨 돌릴 곳이 없으면 함정도 함정으로 안 느껴진다.
## 위험한 것은 **비율**이고, 특히 그것이 밤이 갈수록 나빠지는 것이다.

const SEPARATOR := "──────────────────────────────────────────────"


func _initialize() -> void:
	var engine := RuleEngine.new(GameData.load_rules())
	var plan := NightPlan.load()
	print("밤   손님   함정   무해   모순   조회   훅 비율   손님별")
	print(SEPARATOR)
	var totals := {"trap": 0, "inert": 0, "clash": 0, "plain": 0, "hooked": 0, "all": 0}
	for night in plan.nights():
		_report_night(engine, plan, night, totals)
	print(SEPARATOR)
	print("합계  %3d   %4d   %4d   %4d   %4d   %6.0f%%"
		% [totals["all"], totals["trap"], totals["inert"], totals["clash"], totals["plain"],
			float(totals["hooked"]) / float(maxi(totals["all"], 1)) * 100.0])
	print("\n훅 비율 = (함정 + 모순) / 손님. 이게 낮으면 손님이 많아도 게임은 조용하다.")
	quit(0)


func _report_night(engine: RuleEngine, plan: NightPlan, night: int, totals: Dictionary) -> void:
	var customers := plan.customers_for(night)
	var marks := PackedStringArray()
	var count := {"trap": 0, "inert": 0, "clash": 0, "plain": 0}
	var hooks := 0
	for i in customers.size():
		var ctx := JudgeContext.new(
			night, NightSession.arrival_minutes(i, customers.size()), customers[i])
		var kinds := _classify(engine, ctx)
		for kind in kinds:
			count[kind] += 1
			totals[kind] += 1
		if kinds.has("trap") or kinds.has("clash"):
			hooks += 1
		marks.append(_mark(kinds))
	totals["hooked"] += hooks
	totals["all"] += customers.size()
	print("%2d   %4d   %4d   %4d   %4d   %4d   %6.0f%%   %s"
		% [night, customers.size(), count["trap"], count["inert"], count["clash"],
			count["plain"], float(hooks) / float(maxi(customers.size(), 1)) * 100.0,
			" ".join(marks)])


func _mark(kinds: PackedStringArray) -> String:
	if kinds.has("trap") and kinds.has("clash"):
		return "함모"
	if kinds.has("trap"):
		return "함"
	if kinds.has("clash"):
		return "모"
	return "무" if kinds.has("inert") else "·"


## 이 손님에게 실제로 무슨 일이 일어나는가. 겹칠 수 있으므로 목록으로 돌려준다.
func _classify(engine: RuleEngine, ctx: JudgeContext) -> PackedStringArray:
	var out := PackedStringArray()
	var truth := engine.required_verdicts(ctx)
	for lie in engine.lies_in_play(ctx):
		# 발동만 하고 정답과 같은 말을 하는 거짓은 아무 일도 하지 않는다.
		var kind := "inert" if Verdict.contains(truth, lie.verdict()) else "trap"
		if not out.has(kind):
			out.append(kind)
	if truth.size() > 1 and not out.has("clash"):
		out.append("clash")
	if out.is_empty():
		out.append("plain")
	return out
