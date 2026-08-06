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


## 화면에 그려진 특성만으로 읽히는 「몸의 이상」. `anomaly` 라벨과 **별개로** 계산한다.
##
## `anomaly`는 설계자용 이름표다 (ScreenSnapshot이 유출을 금지하는 필드이기도 하다).
## 플레이어가 실제로 보는 것은 그림자 유무·머릿수·가린 얼굴이고, 이 함수는 그쪽만 센다.
## 둘이 어긋나면 이름표만 이상이고 화면은 멀쩡한 손님이 생긴다 — 불변식 1d가 그걸 막는다.
##
## `spec`은 `data/observation.json`의 `anomaly_traits`다. 코드에 박지 않는 이유는
## 이 목록이 밸런싱 대상이기 때문이다 (CLAUDE.md 1.3).
func visible_anomalies(spec: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key in spec:
		var name := str(key)
		if traits.has(name) and traits[name] == spec[key]:
			out.append(name)
	out.sort()
	return out


func looks_anomalous(spec: Dictionary) -> bool:
	return not visible_anomalies(spec).is_empty()
