class_name BuildCheck
extends RefCounted

## 내보낸 빌드가 멀쩡한지 스스로 검사한다.
##   godot -- --selftest              (에디터/소스에서)
##   ./nightshift.x86_64 --selftest   (내보낸 빌드에서)
##
## **이건 테스트 스위트가 대신해 줄 수 없다.** `tests/`는 소스 트리에서 돌고,
## 여기서 잡으려는 사고는 전부 **패킹된 뒤에만** 일어난다:
##
##   · JSON은 Godot의 임포트 대상이 아니라서 include_filter에 안 넣으면 PCK에서 빠진다.
##     수칙 0개짜리 게임이 그대로 나간다. 화면은 멀쩡히 뜬다
##   · `DirAccess`로 res:// 하위를 훑는 로더는 PCK에서 다르게 동작할 수 있다
##   · `SystemFont`는 OS에 깔린 폰트를 실행 시점에 찾는다. 한글 폰트가 없는 기계에서는
##     **전부 네모로 나온다.** 개발 기계에는 늘 깔려 있으니 절대 눈치채지 못한다
##
## 마지막 항목은 **합격/불합격으로 판정하지 않는다.** 아래 `_report_font` 주석 참고 —
## Godot이 글리프 유무를 믿을 만하게 알려주지 않는다. 대신 측정값을 찍어서 사람이 본다.

const ARG := "--selftest"

## 제목과 클립보드에 실제로 쓰는 글자로 잰다.
const FONT_PROBE := "밤샘마트 수칙"
const FONT_PROBE_SIZE := 24

## 출시 빌드에 있으면 안 되는 파일. `tools/solver_audit.gd` 에는 **어느 수칙이 거짓인지
## 전부 적혀 있다** — 퍼즐 게임에서 그건 정답지를 같이 파는 것이다.
##
## 바이너리를 문자열로 뒤져서는 확인할 수 없다. PCK가 압축돼 있어서 같은 파일의
## 어떤 문자열은 찾아지고 어떤 문자열은 안 찾아진다. 실제로 그 착시에 두 번 속았다.
## **빌드 자신에게 물어야 한다.**
const DEV_ONLY_PATHS := [
	"res://tests/run_tests.gd", "res://tests/test_fairness.gd",
	"res://tools/solver_audit.gd", "res://tools/playthrough.gd",
	"res://tools/shoot_states.gd",
]

const SHADER_PATHS := [
	"res://shaders/crt.gdshader", "res://shaders/grain.gdshader",
	"res://shaders/paper.gdshader", "res://shaders/cctv.gdshader",
]

var failures: PackedStringArray = []
var lines: PackedStringArray = []


static func requested() -> bool:
	return OS.get_cmdline_user_args().has(ARG)


## 0이면 정상. 셸에서 바로 쓸 수 있게 종료 코드로 돌려준다.
## `font`은 호출자가 넘긴다. `systems/`는 `ui/`를 알아서는 안 되기 때문이다 (CLAUDE.md 2절).
func run(font: Font) -> int:
	_check_data()
	_check_locales()
	_check_shaders()
	_check_no_dev_files()
	_report_font(font)
	for line in lines:
		print(line)
	if failures.is_empty():
		print("빌드 검사 통과")
		return 0
	print("빌드 검사 실패: %d건" % failures.size())
	for f in failures:
		print("  ✗ ", f)
	return 1


func _ok(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _check_data() -> void:
	var rules := GameData.load_rules()
	var customers := GameData.load_customers()
	var plan := NightPlan.load()
	lines.append("수칙 %d · 손님 %d · 밤 %d" % [rules.size(), customers.size(), plan.nights().size()])
	# 0이면 JSON이 PCK에서 빠진 것이다. 화면은 뜨는데 게임이 없다.
	_ok(rules.size() > 0, "수칙을 하나도 못 읽었다 — JSON이 빌드에 안 들어갔다")
	_ok(customers.size() > 0, "손님을 하나도 못 읽었다 — JSON이 빌드에 안 들어갔다")
	_ok(plan.nights().size() > 0, "밤 구성을 못 읽었다")
	_ok(plan.missing_customer_ids().is_empty(),
		"정의되지 않은 손님을 참조한다: %s" % str(plan.missing_customer_ids()))
	_ok(not GameData.load_balance().is_empty(), "balance.json 을 못 읽었다")


func _check_locales() -> void:
	for locale in GameData.locales():
		var strings := GameData.load_strings(locale)
		lines.append("'%s' 문자열 %d개" % [locale, strings.size()])
		_ok(strings.size() > 0, "'%s' 문자열을 못 읽었다" % locale)
		for rule in GameData.load_rules():
			_ok(strings.has(rule.text_key),
				"'%s'에 수칙 문구가 없다: %s" % [locale, rule.text_key])


func _check_shaders() -> void:
	for path in SHADER_PATHS:
		_ok(ResourceLoader.exists(path), "셰이더가 빌드에 없다: %s" % path)
		if ResourceLoader.exists(path):
			_ok(load(path) != null, "셰이더를 못 읽었다: %s" % path)


## 소스 트리에서는 당연히 다 있으므로 **내보낸 빌드에서만** 본다.
func _check_no_dev_files() -> void:
	if not OS.has_feature("template"):
		lines.append("개발 파일 검사: 소스에서 실행 중이라 건너뜀")
		return
	var leaked := PackedStringArray()
	for path in DEV_ONLY_PATHS:
		if FileAccess.file_exists(str(path)) or ResourceLoader.exists(str(path)):
			leaked.append(str(path))
	lines.append("개발 파일 유출 %d개" % leaked.size())
	_ok(leaked.is_empty(), "개발 파일이 빌드에 들어 있다: %s" % ", ".join(leaked))


## 한글이 어떻게 측정되는지 **찍어만 준다. 판정하지 않는다.**
##
## 처음엔 `font.has_char()`로 검사했는데 한글 전부 false가 나왔다 — 스크린샷에는
## 멀쩡히 그려지고 있는데도. `SystemFont.has_char()`는 **주 서체만** 보고,
## 실제로 한글을 그리는 OS 폴백 체인은 보지 못한다.
##
## 폭으로도 구분할 수 없다. 없는 폰트 이름만 주고 폴백까지 꺼도 한글 4글자가
## 폭 96으로 측정된다(네모를 같은 폭으로 그린다). 높이는 서체마다 다를 뿐이고.
##
## **작동하는 빌드를 떨어뜨리는 검사는 없느니만 못하다.** 그래서 측정값만 남긴다.
##
## 진짜 해법은 동봉이고, 그건 정해졌다 (`ui/theme_factory.gd`의 `font()` 주석).
## 파일이 아직 없을 뿐이다. 그래서 여기서는 **동봉 여부를 말한다** — 없으면 이 빌드가
## 남의 OS 폰트에 기대고 있다는 뜻이고, Proton/Linux에서는 그게 없을 수 있다.
func _report_font(font: Font) -> void:
	if font == null:
		failures.append("폰트를 만들지 못했다")
		return
	var korean := font.get_string_size(FONT_PROBE, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PROBE_SIZE)
	lines.append("한글 측정 「%s」 → %.0f x %.0f (0이면 아예 안 그려진다)"
		% [FONT_PROBE, korean.x, korean.y])
	if Palette.has_bundled_font():
		lines.append("폰트: 동봉분을 쓴다")
	else:
		lines.append("폰트: **동봉분이 없다** — OS 폰트에 기대고 있다. "
			+ "Proton/Linux에 CJK가 없으면 전부 두부(□)가 된다. res://fonts/ui.ttf 를 넣을 것")
	# 폭이 0이면 글자가 하나도 안 나가는 것이다. 그건 확실한 고장이다.
	_ok(korean.x > 0.0, "한글이 폭 0으로 측정된다 — 화면에 아무것도 안 나온다")
