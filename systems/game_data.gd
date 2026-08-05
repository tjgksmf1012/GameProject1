class_name GameData
extends RefCounted

## JSON 로딩 전담. 밸런싱·문자열·수칙은 전부 코드 밖에 있다 (CLAUDE.md 1.3).

const RULES_PATH := "res://data/rules/night_01.json"
const CUSTOMERS_PATH := "res://data/customers/pool_01.json"
const STRINGS_PATH := "res://data/strings_ko.json"
const BALANCE_PATH := "res://data/balance.json"


static func load_rules(path: String = RULES_PATH) -> Array[Rule]:
	var out: Array[Rule] = []
	var root := read_json(path)
	for raw in (root.get("rules", []) as Array):
		out.append(Rule.from_dict(raw as Dictionary))
	return out


static func load_customers(path: String = CUSTOMERS_PATH) -> Array[Customer]:
	var out: Array[Customer] = []
	var root := read_json(path)
	for raw in (root.get("customers", []) as Array):
		out.append(Customer.from_dict(raw as Dictionary))
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
