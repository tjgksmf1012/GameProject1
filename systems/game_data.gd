class_name GameData
extends RefCounted

## JSON 로딩 전담. 밸런싱·문자열·수칙은 전부 코드 밖에 있다 (CLAUDE.md 1.3).
##
## 수칙과 손님은 **디렉터리 전체**를 읽는다 (F-01의 `data/rules/*.json`).
## 밤이 늘어날 때 파일만 추가하면 되고 코드는 손대지 않는다.

const RULES_DIR := "res://data/rules"
const CUSTOMERS_DIR := "res://data/customers"
const STRINGS_PATH := "res://data/strings_ko.json"
const BALANCE_PATH := "res://data/balance.json"
const NIGHTS_PATH := "res://data/nights.json"


static func load_rules(dir_path: String = RULES_DIR) -> Array[Rule]:
	var out: Array[Rule] = []
	for path in json_files(dir_path):
		for raw in (read_json(path).get("rules", []) as Array):
			out.append(Rule.from_dict(raw as Dictionary))
	return out


static func load_customers(dir_path: String = CUSTOMERS_DIR) -> Array[Customer]:
	var out: Array[Customer] = []
	for path in json_files(dir_path):
		for raw in (read_json(path).get("customers", []) as Array):
			out.append(Customer.from_dict(raw as Dictionary))
	return out


## 파일 이름순으로 읽는다. night_01, night_02 … 순서가 곧 도입 순서와 맞아 읽기 쉽다.
static func json_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var names := DirAccess.get_files_at(dir_path)
	names.sort()
	for name in names:
		# 내보내기 빌드에서는 .json 이 .json.remap 으로 바뀐다.
		var clean := name.trim_suffix(".remap")
		if clean.ends_with(".json"):
			out.append("%s/%s" % [dir_path, clean])
	return out


static func load_strings(path: String = STRINGS_PATH) -> Dictionary:
	return read_json(path)


static func load_balance(path: String = BALANCE_PATH) -> Dictionary:
	return read_json(path)


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("파일을 찾을 수 없다: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON 파싱 실패: %s" % path)
		return {}
	return parsed as Dictionary
