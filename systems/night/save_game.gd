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
	return save


func store(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("세이브를 쓸 수 없다: %s" % path)
		return false
	file.store_string(JSON.stringify({
		"night": night,
		"cleared_nights": cleared_nights,
	}, "  "))
	file.close()
	return true


## 밤을 넘겼다. 실패한 밤은 진행이 오르지 않는다 — 같은 밤을 다시 한다.
func advance_to(next_night: int) -> void:
	cleared_nights = maxi(cleared_nights, night)
	night = next_night


static func erase(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
