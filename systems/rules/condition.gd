class_name Condition
extends RefCounted

## 수칙 하나가 언제 적용되는지를 나타내는 단일 조건.
## 여러 조건은 항상 AND로 결합한다. OR이 필요하면 수칙을 분리한다 (04-functional-spec F-01).

const OP_EQ := "eq"
const OP_NEQ := "neq"
const OP_AFTER := "after"
const OP_BEFORE := "before"

var field: String = ""
var op: String = OP_EQ
var value: Variant = null


static func from_dict(d: Dictionary) -> Condition:
	var c := Condition.new()
	c.field = str(d.get("field", ""))
	c.op = str(d.get("op", OP_EQ))
	c.value = d.get("value")
	return c


func evaluate(ctx: JudgeContext) -> bool:
	if not ctx.has_field(field):
		# 존재하지 않는 필드를 참조하는 수칙은 절대 발동하지 않는다.
		# 공정성 불변식 1을 테스트가 잡아내므로 여기서는 조용히 false를 돌려준다.
		return false
	var actual: Variant = ctx.get_field(field)
	match op:
		OP_EQ:
			return _loose_equals(actual, value)
		OP_NEQ:
			return not _loose_equals(actual, value)
		OP_AFTER:
			return _as_number(actual) > _as_number(_normalized_value())
		OP_BEFORE:
			return _as_number(actual) < _as_number(_normalized_value())
		_:
			push_error("알 수 없는 연산자: %s" % op)
			return false


## `time` 필드의 비교값은 "HH:MM" 문자열이므로 근무 경과 분으로 환산한다.
func _normalized_value() -> Variant:
	if field == JudgeContext.FIELD_TIME and typeof(value) == TYPE_STRING:
		return ShiftClock.parse(value)
	return value


static func _as_number(v: Variant) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_BOOL:
			return 1.0 if v else 0.0
		_:
			return 0.0


## JSON은 정수와 실수를 구분하지 않으므로 숫자는 값으로 비교한다.
static func _loose_equals(a: Variant, b: Variant) -> bool:
	var a_num := typeof(a) in [TYPE_INT, TYPE_FLOAT]
	var b_num := typeof(b) in [TYPE_INT, TYPE_FLOAT]
	if a_num and b_num:
		return is_equal_approx(float(a), float(b))
	return a == b
