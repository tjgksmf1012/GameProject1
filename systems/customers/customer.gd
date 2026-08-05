class_name Customer
extends RefCounted

## 손님 하나. **traits는 전부 관찰 가능해야 한다.**
##
## 공정성 불변식 1(판정에 필요한 모든 단서는 판정 시점에 화면에 존재한다)을 지키려면
## 숨겨진 스탯이 있어서는 안 된다. UI는 traits 전체를 그대로 표시하고,
## `tests/test_fairness.gd`가 수칙이 참조하는 필드가 전부 여기 있는지 검사한다.

var id: String = ""
var name_key: String = ""
var traits: Dictionary = {}
var item_keys: PackedStringArray = []
var dialogue_keys: PackedStringArray = []
var patience_seconds: int = 45
var anomaly: String = ""


static func from_dict(d: Dictionary) -> Customer:
	var c := Customer.new()
	c.id = str(d.get("id", ""))
	c.name_key = str(d.get("name_key", ""))
	c.traits = d.get("traits", {}) as Dictionary
	c.item_keys = _to_string_array(d.get("items", []))
	c.dialogue_keys = _to_string_array(d.get("dialogue", []))
	c.patience_seconds = int(d.get("patience_seconds", 45))
	c.anomaly = str(d.get("anomaly", ""))
	return c


static func _to_string_array(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(v) != TYPE_ARRAY:
		return out
	for item in (v as Array):
		out.append(str(item))
	return out


func has_trait(key: String) -> bool:
	return traits.has(key)


func get_trait(key: String) -> Variant:
	return traits.get(key)


func trait_names() -> PackedStringArray:
	var out := PackedStringArray()
	for key in traits.keys():
		out.append(str(key))
	out.sort()
	return out


func is_anomaly() -> bool:
	return anomaly != ""
