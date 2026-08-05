extends RefCounted

## 최소 테스트 리포터. GUT 같은 외부 의존을 들이지 않고 `--headless --script`로 바로 돈다.
## `class_name`은 systems/ 와 data/ 에서만 선언한다 (CLAUDE.md 4절) — 그래서 preload로 쓴다.

var failures: PackedStringArray = []
var notices: PackedStringArray = []
var check_count: int = 0
var _suite: String = ""


func suite(name: String) -> void:
	_suite = name


func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append("[%s] %s" % [_suite, message])


## 지금 데이터로는 한 번도 발동하지 않은 검사를 기록한다.
##
## **통과 개수만 보면 "검사했다"로 읽힌다.** 아직 조건이 성립하지 않아 잠자는 불변식은
## 커버리지가 아니라 예약이다. 그 차이를 리포트에 드러내지 않으면 나중에 내가 속는다.
func note(message: String) -> void:
	notices.append("[%s] %s" % [_suite, message])


func equals(actual: Variant, expected: Variant, message: String) -> void:
	check_count += 1
	if actual != expected:
		failures.append("[%s] %s — 기대 %s, 실제 %s" % [_suite, message, str(expected), str(actual)])


func print_report() -> int:
	print("")
	for n in notices:
		print("  · 잠자는 검사 — ", n)
	if failures.is_empty():
		print("통과: %d개 검사 전부 성공" % check_count)
		return 0
	print("실패: %d개 검사 중 %d개 실패" % [check_count, failures.size()])
	for f in failures:
		print("  ✗ ", f)
	return 1
