class_name SaveGame
extends RefCounted

## 자동 저장 (F-06). **밤 단위로만 저장한다.** 중간 저장은 없다.
##
## 밤 중간에 저장하면 플레이어가 판정 직전에 저장하고 틀리면 되돌리는 짓을 하게 된다.
## 그 순간 판정의 무게가 사라지고 이 게임은 끝난다.
##
## 세이브 슬롯 다중화는 명시적으로 범위 밖이다 (03-PRD.md 5절). 하나면 충분하다.

const SAVE_PATH := "user://nightshift.save.json"
const FIRST_NIGHT := 1

var night: int = FIRST_NIGHT
var cleared_nights: int = 0

## 플레이어가 거짓이라고 판단해 그어버린 수칙들. **믿음이지 사실이 아니다.**
## 판정에는 아무 영향을 주지 않는다 — 정답은 오직 참 수칙이 정한다 (RuleEngine).
## 밤을 넘어 남는다. 밤 1에서 거짓이라고 결론 낸 줄을 밤 4에서 다시 그어야 하면
## 그건 추론이 아니라 사무 작업이다.
var struck_rule_ids: PackedStringArray = []


static func load_or_new(path: String = SAVE_PATH) -> SaveGame:
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
	return save


func store(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("세이브를 쓸 수 없다: %s" % path)
		return false
	file.store_string(JSON.stringify({
		"night": night,
		"cleared_nights": cleared_nights,
		"struck_rule_ids": struck_rule_ids,
	}, "  "))
	file.close()
	return true


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


static func erase(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
