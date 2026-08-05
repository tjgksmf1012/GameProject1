extends RefCounted

## POS의 게이트. **파는 것은 일이고, 거부는 즉시다.**
##
## 이 비대칭이 "그냥 다 거부해버릴까"라는 유혹을 만든다. 게이트가 무너지면 압박도 무너진다.
## UI 노드지만 로직이라 트리에 붙여서 헤드리스로 검증할 수 있다.

const PosTerminal := preload("res://ui/pos/pos_terminal.gd")

const CUST_NORMAL := "cust_office_worker"
const CUST_DRINKER := "cust_late_drinker"

var _customers: Dictionary = {}
var _tree: SceneTree = null


func run(r: RefCounted) -> void:
	r.suite("pos_gate")
	_tree = Engine.get_main_loop() as SceneTree
	if _tree == null:
		r.check(false, "SceneTree를 얻을 수 없다 — 이 스위트는 --script 실행이 필요하다")
		return
	for customer in GameData.load_customers():
		_customers[customer.id] = customer
	_test_serve_requires_scan(r)
	_test_alcohol_requires_id(r)
	_test_lock(r)


func _make() -> Node:
	var pos := PosTerminal.new()
	pos.set_data(GameData.load_strings(), GameData.read_json("res://data/items.json").get("prices", {}))
	_tree.root.add_child(pos)
	return pos


func _dispose(pos: Node) -> void:
	_tree.root.remove_child(pos)
	pos.free()


func _test_serve_requires_scan(r: RefCounted) -> void:
	var pos := _make()
	var customer: Customer = _customers[CUST_NORMAL]
	pos.present(customer)
	r.check(not pos.can_serve(), "품목을 찍기 전에는 판매할 수 없다")
	for key in customer.item_keys:
		r.check(pos.scan(key), "품목이 찍힌다: %s" % key)
	r.check(pos.can_serve(), "전부 찍으면 판매할 수 있다")
	r.check(not pos.scan(customer.item_keys[0]), "같은 품목을 두 번 찍을 수 없다")
	_dispose(pos)


func _test_alcohol_requires_id(r: RefCounted) -> void:
	var pos := _make()
	var customer: Customer = _customers[CUST_DRINKER]
	pos.present(customer)
	for key in customer.item_keys:
		pos.scan(key)
	r.check(not pos.can_serve(), "주류는 품목을 다 찍어도 신분 확인 전엔 판매 불가")
	r.check(pos.check_id(), "신분을 확인한다")
	r.check(pos.can_serve(), "신분 확인 후 판매 가능")
	r.check(not pos.check_id(), "신분 확인은 한 번뿐이다")
	_dispose(pos)


## 주류가 없는 손님에게는 신분 확인 자체가 불가능해야 한다 — 의미 없는 클릭을 만들지 않는다.
func _test_lock(r: RefCounted) -> void:
	var pos := _make()
	pos.present(_customers[CUST_NORMAL])
	r.check(not pos.check_id(), "주류가 없으면 신분 확인이 필요 없다")
	pos.lock()
	r.check(pos.is_locked(), "판정 후에는 잠긴다")
	r.check(not pos.scan("item.cup_ramen"), "잠긴 뒤에는 찍을 수 없다")
	r.check(not pos.can_serve(), "잠긴 뒤에는 판매할 수 없다")
	_dispose(pos)
