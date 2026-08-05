class_name NightPlan
extends RefCounted

## 밤마다 어떤 손님이 어떤 순서로 오는가. `data/nights.json`이 정한다.
##
## 본편은 **수작업 설계 7박**이다. 절차적 무한 생성은 범위 밖이다 (03-PRD.md 5절).
## 무작위화는 나중에 조합·순서에만 적용한다 — 개별 판정의 정답은 항상 결정론적이다 (불변식 4).

var _orders: Dictionary = {}
var _by_id: Dictionary = {}


func _init(plan: Dictionary, customers: Array[Customer]) -> void:
	for customer in customers:
		_by_id[customer.id] = customer
	for raw in (plan.get("nights", []) as Array):
		var entry := raw as Dictionary
		_orders[int(entry.get("night", 0))] = Customer._to_string_array(entry.get("customers", []))


static func load() -> NightPlan:
	return NightPlan.new(GameData.read_json(GameData.NIGHTS_PATH), GameData.load_customers())


func nights() -> PackedInt32Array:
	var out := PackedInt32Array()
	for night in _orders.keys():
		out.append(int(night))
	out.sort()
	return out


func has_night(night: int) -> bool:
	return _orders.has(night)


func last_night() -> int:
	var all := nights()
	return all[all.size() - 1] if all.size() > 0 else 0


## 그 밤에 오는 손님들. 정의에 없는 id는 조용히 건너뛰지 않고 오류로 남긴다 —
## 손님이 빠지면 밤의 난이도 곡선이 통째로 어긋나기 때문이다.
func customers_for(night: int) -> Array[Customer]:
	var out: Array[Customer] = []
	for id in (_orders.get(night, PackedStringArray()) as PackedStringArray):
		if not _by_id.has(id):
			push_error("밤 %d에 정의되지 않은 손님이 있다: %s" % [night, id])
			continue
		out.append(_by_id[id])
	return out


func missing_customer_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for night in _orders:
		for id in (_orders[night] as PackedStringArray):
			if not _by_id.has(id) and not out.has(id):
				out.append(id)
	return out
