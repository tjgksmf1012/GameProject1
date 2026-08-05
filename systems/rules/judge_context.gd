class_name JudgeContext
extends RefCounted

## 판정 한 번이 일어나는 시점의 상황 전체.
## 여기 없는 정보로는 어떤 수칙도 판정할 수 없다 — 그게 공정성 불변식 1이다.

const FIELD_TIME := "time"
const FIELD_NIGHT := "night"
const CUSTOMER_PREFIX := "customer."

var night: int = 1
var shift_minutes: int = 0
var customer: Customer = null


func _init(p_night: int = 1, p_shift_minutes: int = 0, p_customer: Customer = null) -> void:
	night = p_night
	shift_minutes = p_shift_minutes
	customer = p_customer


func has_field(path: String) -> bool:
	if path == FIELD_TIME or path == FIELD_NIGHT:
		return true
	if path.begins_with(CUSTOMER_PREFIX):
		if customer == null:
			return false
		return customer.has_trait(_trait_key(path))
	return false


func get_field(path: String) -> Variant:
	if path == FIELD_TIME:
		return shift_minutes
	if path == FIELD_NIGHT:
		return night
	if path.begins_with(CUSTOMER_PREFIX) and customer != null:
		return customer.get_trait(_trait_key(path))
	return null


## 이 시점에 화면에 존재하는(=수칙이 참조해도 되는) 필드 전체.
func observable_field_names() -> PackedStringArray:
	var out := PackedStringArray([FIELD_TIME, FIELD_NIGHT])
	if customer != null:
		for name in customer.trait_names():
			out.append(CUSTOMER_PREFIX + name)
	return out


func time_display() -> String:
	return ShiftClock.to_display(shift_minutes)


static func _trait_key(path: String) -> String:
	return path.substr(CUSTOMER_PREFIX.length())
