extends Control

## POS 품목 버튼의 작은 상품 그림.
## 외부 이미지나 브랜드 표식 없이, 32px 안에서 실루엣만으로 여섯 품목을 구분한다.

const OUTLINE := Color("20272a")
const HIGHLIGHT := Color("c3bdaf")
const STEAM := Color("aeb9b9")

var _item_key: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(32, 32)


func set_item_key(item_key: String) -> void:
	_item_key = item_key
	queue_redraw()


func _draw() -> void:
	match _item_key:
		"item.cup_ramen":
			_draw_cup_ramen()
		"item.energy_drink":
			_draw_energy_drink()
		"item.hot_coffee":
			_draw_hot_coffee()
		"item.cigarettes":
			_draw_cigarettes()
		"item.umbrella":
			_draw_umbrella()
		"item.soju":
			_draw_soju()
		_:
			_draw_unknown()


func _draw_cup_ramen() -> void:
	var cup := PackedVector2Array([
		Vector2(6, 12), Vector2(26, 12), Vector2(23, 27), Vector2(9, 27),
	])
	draw_colored_polygon(cup, Color("bd5c38"))
	draw_polyline(cup + PackedVector2Array([cup[0]]), OUTLINE, 1.5, true)
	draw_rect(Rect2(5, 10, 22, 4), Color("dcbc6b"), true)
	draw_line(Vector2(6, 12), Vector2(26, 12), OUTLINE, 1.5, true)
	draw_line(Vector2(10, 20), Vector2(22, 20), HIGHLIGHT, 2.0, true)
	draw_arc(Vector2(12, 8), 4, PI, TAU, 8, STEAM, 1.4, true)
	draw_arc(Vector2(20, 7), 4, PI, TAU, 8, STEAM, 1.4, true)


func _draw_energy_drink() -> void:
	draw_rect(Rect2(9, 4, 14, 24), Color("4c8e94"), true)
	draw_rect(Rect2(9, 4, 14, 24), OUTLINE, false, 1.5, true)
	draw_line(Vector2(10, 7), Vector2(22, 7), HIGHLIGHT, 1.2, true)
	draw_line(Vector2(10, 25), Vector2(22, 25), OUTLINE, 1.2, true)
	draw_arc(Vector2(16, 5), 3, PI, TAU, 8, Color("b2c1bc"), 1.2, true)
	var bolt := PackedVector2Array([
		Vector2(17, 9), Vector2(12, 17), Vector2(16, 17),
		Vector2(14, 24), Vector2(21, 14), Vector2(17, 14),
	])
	draw_colored_polygon(bolt, Color("dfbd55"))
	draw_polyline(bolt + PackedVector2Array([bolt[0]]), OUTLINE, 1.0, true)


func _draw_hot_coffee() -> void:
	draw_rect(Rect2(7, 10, 17, 17), Color("c7b28b"), true)
	draw_rect(Rect2(7, 10, 17, 17), OUTLINE, false, 1.5, true)
	draw_rect(Rect2(5, 8, 21, 4), Color("403a34"), true)
	draw_rect(Rect2(9, 17, 13, 6), Color("77513b"), true)
	draw_line(Vector2(9, 17), Vector2(22, 17), OUTLINE, 1.0, true)
	draw_line(Vector2(9, 23), Vector2(22, 23), OUTLINE, 1.0, true)
	draw_arc(Vector2(12, 6), 4, PI, TAU, 8, STEAM, 1.4, true)
	draw_arc(Vector2(20, 5), 4, PI, TAU, 8, STEAM, 1.4, true)


func _draw_cigarettes() -> void:
	draw_rect(Rect2(6, 7, 20, 21), Color("c4bdac"), true)
	draw_rect(Rect2(6, 7, 20, 21), OUTLINE, false, 1.5, true)
	draw_rect(Rect2(6, 7, 20, 7), Color("8f4841"), true)
	draw_line(Vector2(6, 14), Vector2(26, 14), OUTLINE, 1.2, true)
	draw_rect(Rect2(10, 3, 4, 9), HIGHLIGHT, true)
	draw_rect(Rect2(18, 3, 4, 9), HIGHLIGHT, true)
	draw_rect(Rect2(10, 3, 4, 3), Color("b98b58"), true)
	draw_rect(Rect2(18, 3, 4, 3), Color("b98b58"), true)
	draw_line(Vector2(10, 21), Vector2(22, 21), Color("736d62"), 1.5, true)


func _draw_umbrella() -> void:
	var canopy := PackedVector2Array([
		Vector2(3, 15), Vector2(5, 10), Vector2(10, 6), Vector2(16, 4),
		Vector2(22, 6), Vector2(27, 10), Vector2(29, 15), Vector2(3, 15),
	])
	draw_colored_polygon(canopy, Color("55768e"))
	draw_polyline(canopy, OUTLINE, 1.5, true)
	draw_arc(Vector2(9.5, 15), 6.5, PI, TAU, 10, OUTLINE, 1.2, true)
	draw_arc(Vector2(22.5, 15), 6.5, PI, TAU, 10, OUTLINE, 1.2, true)
	draw_line(Vector2(16, 5), Vector2(16, 25), OUTLINE, 1.7, true)
	draw_arc(Vector2(19, 25), 3, 0, PI, 10, OUTLINE, 1.7, true)


func _draw_soju() -> void:
	var bottle := PackedVector2Array([
		Vector2(13, 3), Vector2(19, 3), Vector2(19, 9), Vector2(22, 13),
		Vector2(22, 28), Vector2(10, 28), Vector2(10, 13), Vector2(13, 9),
	])
	draw_colored_polygon(bottle, Color("4f8b62"))
	draw_polyline(bottle + PackedVector2Array([bottle[0]]), OUTLINE, 1.5, true)
	draw_rect(Rect2(12, 2, 8, 4), Color("b4c1b2"), true)
	draw_rect(Rect2(12, 2, 8, 4), OUTLINE, false, 1.0, true)
	draw_rect(Rect2(11, 16, 10, 7), Color("bfbeaf"), true)
	draw_circle(Vector2(16, 19.5), 2.0, Color("7a9e65"))
	draw_line(Vector2(12, 26), Vector2(20, 26), Color("386c4c"), 1.0, true)


func _draw_unknown() -> void:
	draw_circle(Vector2(16, 16), 11, Color("4b5558"), false, 2.0, true)
	draw_line(Vector2(16, 9), Vector2(16, 18), HIGHLIGHT, 2.0, true)
	draw_circle(Vector2(16, 23), 1.5, HIGHLIGHT)
