extends RefCounted

## 밤이 끝났을 때 뭐라고 쓰는가. **엔딩이 실제로 엔딩으로 보이는지**가 핵심이다.
##
## 마지막 밤을 넘겼는데 「밤이 끝났다. 아침이 왔다」로 끝나면 게임이 끝난 줄 모른다.
## 실패했는데 엔딩이 뜨면 더 나쁘다 — 못 깬 밤을 깬 것으로 읽는다.

const KO := "ko"


func run(r: RefCounted) -> void:
	r.suite("night_report")
	_test_ending_only_on_cleared_last_night(r)
	_test_ending_reflects_player_marks(r)
	_test_every_branch_has_real_text(r)


func _report() -> NightReport:
	return NightReport.new(GameData.load_strings(KO))


## **실패는 마지막 밤이어도 엔딩이 아니다.** 이걸 뒤집으면 못 깬 밤이 완주로 읽힌다.
func _test_ending_only_on_cleared_last_night(r: RefCounted) -> void:
	r.check(NightReport.is_ending(true, false), "마지막 밤을 넘기면 엔딩이다")
	r.check(not NightReport.is_ending(false, false), "실패하면 마지막 밤이어도 엔딩이 아니다")
	r.check(not NightReport.is_ending(true, true), "다음 밤이 남았으면 엔딩이 아니다")
	r.check(not NightReport.is_ending(false, true), "실패했고 다음 밤도 남았으면 엔딩이 아니다")

	var report := _report()
	var strings := GameData.load_strings(KO)
	r.equals(report.headline(true, false, 0), str(strings["ending.headline"]),
		"마지막 밤을 넘기면 엔딩 문구가 나온다")
	r.equals(report.headline(true, true, 0), str(strings["night.cleared"]),
		"중간 밤은 평소 문구다")
	r.check(report.headline(false, false, 2).contains("2"),
		"실패 문구에 오판 횟수가 들어간다")


## 취소선은 판정에 영향이 없다. **유일하게 남는 곳이 엔딩이다.**
func _test_ending_reflects_player_marks(r: RefCounted) -> void:
	var report := _report()
	var strings := GameData.load_strings(KO)
	var none := report.ending_detail(0)
	var some := report.ending_detail(3)
	r.check(none.contains(str(strings["ending.no_marks"])),
		"아무것도 안 그었으면 그렇게 말한다")
	r.check(some.contains("3"), "그은 줄 수가 엔딩에 들어간다")
	r.check(none != some, "그었는지 여부로 엔딩 문구가 달라진다")


## 모든 갈래가 실제 문자열을 찾아야 한다. `<key>` 가 화면에 뜨면 그걸로 끝이다.
func _test_every_branch_has_real_text(r: RefCounted) -> void:
	var report := _report()
	var produced := PackedStringArray([
		report.headline(true, false, 0), report.headline(true, true, 0),
		report.headline(false, true, 1),
		report.continue_label(true, false), report.continue_label(true, true),
		report.continue_label(false, true),
		report.ending_detail(0), report.ending_detail(2),
		report.night_detail(5, 1, 0, ""), report.night_detail(5, 1, 0, "user://x.json"),
	])
	for text in produced:
		r.check(not str(text).contains("<"),
			"문자열 키가 화면에 그대로 뜬다: %s" % text)
		r.check(str(text) != "", "빈 문구가 나온다")
