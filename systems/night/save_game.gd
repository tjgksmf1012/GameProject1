class_name SaveGame
extends RefCounted

## 자동 저장 (F-06). **밤 단위로만 저장한다.** 중간 저장은 없다.
##
## 밤 중간에 저장하면 플레이어가 판정 직전에 저장하고 틀리면 되돌리는 짓을 하게 된다.
## 그 순간 판정의 무게가 사라지고 이 게임은 끝난다.
##
## 세이브 슬롯 다중화는 명시적으로 범위 밖이다 (03-PRD.md 5절). 하나면 충분하다.

const SAVE_PATH := "user://nightshift.save.json"

## **도구가 진짜 세이브를 밟지 않게 하는 우회로.**
##
## 촬영 도구는 특정 밤 화면을 찍으려고 세이브를 써야 한다 — 게임이 세이브가 가리키는
## 밤부터 시작하기 때문이다. 그런데 그게 **진짜 세이브**였다. 스크린샷 한 장 찍을 때마다
## 플레이 중인 회차가 날아갔다. 감사 에이전트들이 실제로 이걸 당했다 — 도구를 몇 번
## 돌린 뒤 night 이 1에서 5로 바뀌어 있었다.
##
## 도구와 게임 장면이 **같은 프로세스**에서 도므로 정적 값 하나면 둘 다 따라온다.
static var _override_path: String = ""


## 도구가 자기 전용 세이브를 쓰겠다고 선언한다. 게임 코드는 아무것도 안 바꿔도 된다.
static func use_path(new_path: String) -> void:
	_override_path = new_path


static func path() -> String:
	return _override_path if not _override_path.is_empty() else SAVE_PATH
const FIRST_NIGHT := 1

var night: int = FIRST_NIGHT
var cleared_nights: int = 0

## 플레이어가 거짓이라고 판단해 그어버린 수칙들. **믿음이지 사실이 아니다.**
## 판정에는 아무 영향을 주지 않는다 — 정답은 오직 참 수칙이 정한다 (RuleEngine).
## 밤을 넘어 남는다. 밤 1에서 거짓이라고 결론 낸 줄을 밤 4에서 다시 그어야 하면
## 그건 추론이 아니라 사무 작업이다.
var struck_rule_ids: PackedStringArray = []

## **첫 함정 유예를 이미 썼는가.** 밤이 아니라 회차 단위다.
##
## 예전에는 `NightSession`이 밤마다 새로 생기면서 유예도 같이 새로 생겼다. 그래서 화면은
## 「이번은 넘어간다 — 다음부터는 아니다」라고 말해놓고 다음 밤에 또 넘어갔다.
## 게임이 플레이어에게 직접 건네는 유일한 약속이 매일 밤 깨지고 있었다.
##
## 밤 하나만 도는 검사로는 안 잡힌다. 검사도 감사 도구도 전부 밤 단위였고,
## **밤을 이어서 해봐야만 보이는 결함**이었다.
##
## 유예의 근거는 밸런싱이 아니라 학습이다 (balance.json `_comment_grace`):
## 「수칙이 거짓말할 수 있다」는 문법을 아직 모르니 봐준다. 그 문법은 한 번 배우면 끝이다.
var grace_used: bool = false


static func load_or_new(from: String = "") -> SaveGame:
	var path := from if not from.is_empty() else SaveGame.path()
	var save := SaveGame.new()
	if not FileAccess.file_exists(path):
		return save
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("세이브가 손상됐다. 처음부터 시작한다: %s" % path)
		return save
	var data := parsed as Dictionary
	save.night = maxi(FIRST_NIGHT, int(data.get("night", FIRST_NIGHT)))
	save.cleared_nights = int(data.get("cleared_nights", 0))
	save.struck_rule_ids = Customer._to_string_array(data.get("struck_rule_ids", []))
	save.grace_used = bool(data.get("grace_used", false))
	return save


func store(to: String = "") -> bool:
	var path := to if not to.is_empty() else SaveGame.path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("세이브를 쓸 수 없다: %s" % path)
		return false
	file.store_string(JSON.stringify({
		"night": night,
		"cleared_nights": cleared_nights,
		"struck_rule_ids": struck_rule_ids,
		"grace_used": grace_used,
	}, "  "))
	file.close()
	return true


## 이번 밤에 유예를 썼다면 회차 기록에 남긴다. **실제로 새로 쓴 것이면** true.
##
## 밤을 실패해도 돌려주지 않는다. 유예의 근거는 밸런싱이 아니라 학습이고,
## 다시 하는 밤에도 「수칙이 거짓말한다」는 문법은 이미 배운 상태이기 때문이다.
func spend_grace(used_tonight: bool) -> bool:
	if not used_tonight or grace_used:
		return false
	grace_used = true
	return true


## **일곱 밤을 다 넘겼는가.** `night`만으로는 알 수 없다 — 마지막 밤을 넘겨도
## 진행은 그 자리에 머문다. 그래서 완주한 사람과 마지막 밤을 하다 만 사람이 구분되지 않았고,
## 제목 화면이 둘에게 똑같이 「7일째 밤부터」라고 말했다.
func has_finished(last_night: int) -> bool:
	return cleared_nights >= last_night


## **다음 사람이 된다.** 밤과 유예는 처음으로 돌리되 **그어둔 줄은 남긴다.**
##
## 엔딩이 이미 그렇게 약속했다 — 「당신이 그어둔 줄이 그대로 남아 있다.
## 그는 그것부터 읽을 것이다.」 다시 시작하는 사람이 바로 그 사람이다.
func begin_new_run() -> void:
	night = FIRST_NIGHT
	cleared_nights = 0
	grace_used = false


## 그었다 / 지웠다. 그은 상태를 돌려준다.
func toggle_strike(rule_id: String) -> bool:
	var at := struck_rule_ids.find(rule_id)
	if at >= 0:
		struck_rule_ids.remove_at(at)
		return false
	struck_rule_ids.append(rule_id)
	return true


## 밤을 넘겼다. 실패한 밤은 진행이 오르지 않는다 — 같은 밤을 다시 한다.
func advance_to(next_night: int) -> void:
	cleared_nights = maxi(cleared_nights, night)
	night = next_night


static func erase(target: String = "") -> void:
	var path := target if not target.is_empty() else SaveGame.path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
