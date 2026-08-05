extends PanelContainer

## 창밖 실루엣과 카운터 앞의 손님.
##
## `보이는 것` 목록은 공정성 불변식 1을 화면으로 옮긴 부분이다 —
## 손님의 모든 특성을 빠짐없이 보여준다. 숨겨진 스탯은 존재하지 않는다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")

const SILHOUETTE_HEIGHT := 96
const RISE_DURATION := 0.3

var _strings: Dictionary = {}
var _silhouette: Control = null
var _name: Label = null
var _dialogue: Label = null
var _traits: VBoxContainer = null
var _body: VBoxContainer = null


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PANEL, Palette.PANEL_EDGE))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _build() -> void:
	if _body != null:
		return
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	add_child(_body)

	_silhouette = _make_silhouette()
	_body.add_child(_silhouette)
	_name = Palette.make_label("", Palette.SIZE_HEAD, Palette.TEXT)
	_body.add_child(_name)
	_dialogue = Palette.make_label("", Palette.SIZE_BODY, Palette.TEXT_DIM)
	_body.add_child(_dialogue)
	_body.add_child(Palette.make_label(_t("ui.observation_header"), Palette.SIZE_SMALL, Palette.ACCENT))
	_traits = VBoxContainer.new()
	_traits.add_theme_constant_override("separation", 4)
	_body.add_child(_traits)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


## 창밖 실루엣. 이미지가 아니라 절차적 도형이다 (CLAUDE.md 1.1).
func _make_silhouette() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, SILHOUETTE_HEIGHT)
	var polygon := Polygon2D.new()
	polygon.color = Color(0.0, 0.0, 0.0, 0.85)
	polygon.polygon = PackedVector2Array([
		Vector2(28, 96), Vector2(28, 44), Vector2(36, 30),
		Vector2(34, 18), Vector2(46, 8), Vector2(58, 18),
		Vector2(56, 30), Vector2(64, 44), Vector2(64, 96),
	])
	holder.add_child(polygon)
	return holder


func show_customer(customer: Customer) -> void:
	_name.text = _t(customer.name_key)
	_dialogue.text = _dialogue_text(customer)
	_fill_traits(customer)
	Juice.fade_in(_body, RISE_DURATION)


func _dialogue_text(customer: Customer) -> String:
	var lines := PackedStringArray()
	for key in customer.dialogue_keys:
		lines.append("\"%s\"" % _t(key))
	return "\n".join(lines)


func _fill_traits(customer: Customer) -> void:
	for child in _traits.get_children():
		child.queue_free()
	for name in customer.trait_names():
		var present := bool(customer.get_trait(name))
		var mark := "●" if present else "○"
		var color := Palette.TEXT if present else Palette.TEXT_DIM
		_traits.add_child(Palette.make_label(
			"%s  %s" % [mark, _t("trait." + name)], Palette.SIZE_BODY, color))
