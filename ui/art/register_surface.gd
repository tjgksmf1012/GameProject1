extends Control

## POS의 계산대 표면. 떠 있는 버튼 세 묶음을 컨베이어·스캐너·프린터·키패드에 고정한다.

const Palette := preload("res://ui/theme_factory.gd")

const BODY := Color("171d1e")
const BODY_EDGE := Color("3b4544")
const WELL := Color("090d0e")
const GLASS := Color("102226")
const GLASS_LINE := Color("365257")
const RUBBER := Color("0a0d0d")
const LED := Color("8c5a28")

var _scan_flash := 0.0
var _belt_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_belt_phase = fposmod(_belt_phase + delta * 7.0, 22.0)
	_scan_flash = maxf(0.0, _scan_flash - delta * 5.0)
	queue_redraw()


func pulse_scan() -> void:
	_scan_flash = 1.0


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BODY)
	_draw_belt()
	_draw_scanner()
	_draw_printer_bay()
	_draw_key_bed()
	_draw_edges()


func _draw_belt() -> void:
	var rect := Rect2(4.0, size.y * 0.35, size.x * 0.53, size.y * 0.57)
	draw_rect(rect, RUBBER)
	draw_rect(rect, BODY_EDGE.darkened(0.28), false, 3.0)
	for i in 14:
		var x := rect.position.x + fposmod(float(i) * 22.0 + _belt_phase, rect.size.x)
		draw_line(Vector2(x, rect.position.y + 2.0), Vector2(x - 13.0, rect.end.y - 2.0),
			Color(0.19, 0.23, 0.23, 0.34), 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y - 9.0), Vector2(rect.end.x, rect.end.y - 9.0),
		Color(0.35, 0.39, 0.38, 0.18), 2.0)


func _draw_scanner() -> void:
	var rect := Rect2(size.x * 0.33, size.y * 0.53, size.x * 0.19, size.y * 0.30)
	draw_rect(rect.grow(5.0), WELL)
	draw_rect(rect, GLASS)
	draw_rect(rect, BODY_EDGE, false, 2.0)
	for i in 5:
		var x := rect.position.x + rect.size.x * float(i + 1) / 6.0
		draw_line(Vector2(x, rect.position.y + 3.0), Vector2(x - 12.0, rect.end.y - 3.0),
			Color(GLASS_LINE, 0.36), 1.0)
	if _scan_flash > 0.0:
		var y := lerpf(rect.end.y, rect.position.y, _scan_flash)
		draw_line(Vector2(rect.position.x + 3.0, y), Vector2(rect.end.x - 3.0, y),
			Color(Palette.DANGER, 0.65 * _scan_flash), 3.0)


func _draw_printer_bay() -> void:
	var left := size.x * 0.55
	var right := size.x * 0.78
	draw_rect(Rect2(left, 4.0, right - left, size.y - 8.0), Color("121718"))
	draw_line(Vector2(left, 0.0), Vector2(left, size.y), WELL, 6.0)
	draw_line(Vector2(right, 0.0), Vector2(right, size.y), BODY_EDGE.darkened(0.32), 3.0)
	var slot := Rect2(left + 18.0, 10.0, right - left - 36.0, 9.0)
	draw_rect(slot, WELL)
	draw_line(slot.position, Vector2(slot.end.x, slot.position.y), BODY_EDGE, 2.0)
	for x in [left + 12.0, right - 12.0]:
		draw_circle(Vector2(x, size.y - 12.0), 3.0, WELL)
		draw_circle(Vector2(x, size.y - 12.0), 1.3, BODY_EDGE)


func _draw_key_bed() -> void:
	var rect := Rect2(size.x * 0.79, 5.0, size.x * 0.20, size.y - 10.0)
	draw_rect(rect, Color("111617"))
	draw_rect(rect, BODY_EDGE.darkened(0.26), false, 3.0)
	for row in 3:
		for col in 4:
			var center := Vector2(
				rect.position.x + 13.0 + float(col) * 18.0,
				rect.end.y - 20.0 - float(row) * 15.0)
			draw_rect(Rect2(center - Vector2(5.0, 4.0), Vector2(10.0, 8.0)), WELL)
	draw_circle(rect.position + Vector2(rect.size.x - 14.0, 14.0), 3.0, Color(LED, 0.72))


func _draw_edges() -> void:
	draw_line(Vector2(0.0, 2.0), Vector2(size.x, 2.0), BODY_EDGE, 4.0)
	draw_line(Vector2(0.0, size.y - 2.0), Vector2(size.x, size.y - 2.0), WELL, 4.0)
	for x in [8.0, size.x - 8.0]:
		draw_circle(Vector2(x, 10.0), 3.0, WELL)
		draw_circle(Vector2(x, 10.0), 1.2, BODY_EDGE)
