class_name Verdict
extends RefCounted

## 플레이어가 내릴 수 있는 판정. `serve` / `refuse` / `special:<id>`.

const SERVE := "serve"
const REFUSE := "refuse"
const SPECIAL_PREFIX := "special:"

var kind: String = SERVE
var special_id: String = ""


func _init(p_kind: String = SERVE, p_special_id: String = "") -> void:
	kind = p_kind
	special_id = p_special_id


static func serve() -> Verdict:
	return Verdict.new(SERVE)


static func refuse() -> Verdict:
	return Verdict.new(REFUSE)


static func from_id(raw: String) -> Verdict:
	if raw.begins_with(SPECIAL_PREFIX):
		return Verdict.new(SPECIAL_PREFIX, raw.substr(SPECIAL_PREFIX.length()))
	return Verdict.new(raw)


## 직렬화용 식별자. `_to_string()`은 Object가 이미 쓰고 있어 이름을 피한다.
func id() -> String:
	if kind == SPECIAL_PREFIX:
		return SPECIAL_PREFIX + special_id
	return kind


func equals(other: Verdict) -> bool:
	if other == null:
		return false
	return kind == other.kind and special_id == other.special_id


static func contains(list: Array[Verdict], target: Verdict) -> bool:
	for v in list:
		if v.equals(target):
			return true
	return false
