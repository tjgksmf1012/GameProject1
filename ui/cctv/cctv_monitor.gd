extends PanelContainer

## CCTV 4분할 모니터 (F-04).
##
## **채널 전환이 없다.** 네 화면이 항상 동시에 보인다 — 전환은 FNAF의 문법이고
## 이 게임은 위협을 막는 게임이 아니라 판단하는 게임이다 (00-competitive-analysis 2.4).
##
## 계산대 채널은 **증거 도구**다. 그림자는 카운터에서 눈으로 볼 수 없고 여기서만 확인된다.

const Palette := preload("res://ui/theme_factory.gd")
const CctvChannel := preload("res://ui/cctv/cctv_channel.gd")

## CCTV가 **실제로 그릴 수 있는** 특성. 여기 없는 걸 observation.json 이 CCTV로 넘기면
## 그 단서는 화면 어디에도 안 나온다 — 공정성 불변식 1이 소리없이 깨진다.
## tests/test_fairness.gd 가 이 목록과 데이터를 대조한다.
const RENDERABLE_TRAITS := ["has_shadow", "has_extra_shadow"]

const COUNTER_CHANNEL := 0
const CHANNEL_KEYS := ["cctv.counter", "cctv.aisle", "cctv.storage", "cctv.entrance"]
const GRID_COLUMNS := 2
const GRID_GAP := 6
const CHASSIS := Color("0a0e0f")
const CHASSIS_EDGE := Color("465052")
const STATUS_LED := Color("815529")

var _strings: Dictionary = {}
var _channels: Array[Control] = []
var _grid: GridContainer = null
var _time := 0.0


func _init() -> void:
	var style := Palette.panel_style(CHASSIS, CHASSIS_EDGE)
	style.set_border_width_all(4)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	# 세로를 채운다. 예전에는 SHRINK_BEGIN이라 패널이 243px에서 멈추고 형제는 404px여서
	# **161px가 죽은 공간으로 남았다.** 화면에서 가장 큰 빈자리가 하필 증거 도구 아래였다.
	# 채널 도형은 이제 패널 크기를 따라간다(cctv_channel.gd `_fit_stage`).
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_process(true)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 10.0)
	queue_redraw()


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	for point in [
		Vector2(8.0, 8.0), Vector2(size.x - 8.0, 8.0),
		Vector2(8.0, size.y - 8.0), Vector2(size.x - 8.0, size.y - 8.0),
	]:
		draw_circle(point, 3.3, Palette.BG)
		draw_circle(point, 1.4, CHASSIS_EDGE)
	var led_alpha := 0.62 + sin(_time * 2.2) * 0.08
	draw_circle(Vector2(size.x - 19.0, 18.0), 3.2, Color(STATUS_LED, led_alpha))
	for i in 9:
		var x := size.x * 0.5 - 48.0 + float(i) * 12.0
		draw_line(Vector2(x, size.y - 8.0), Vector2(x + 6.0, size.y - 8.0),
			CHASSIS_EDGE.darkened(0.35), 2.0)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _build() -> void:
	if _grid != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(Palette.make_label(
		_t("ui.cctv_header"), Palette.SIZE_SMALL, Palette.SECTION, Palette.ROLE_MACHINE))

	_grid = GridContainer.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	box.add_child(_grid)

	for i in CHANNEL_KEYS.size():
		var channel := CctvChannel.new()
		channel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		channel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(channel)
		channel.setup(i, CHANNEL_KEYS[i], _strings)
		_channels.append(channel)


## 카운터 앞에 선 손님을 계산대 채널에 비춘다.
func show_customer(customer: Customer) -> void:
	_channels[COUNTER_CHANNEL].show_figure(
		true,
		bool(customer.get_trait("has_shadow")),
		bool(customer.get_trait("has_extra_shadow")))


func clear_customer() -> void:
	_channels[COUNTER_CHANNEL].show_figure(false, false, false)


## 3초 리플레이(F-07)에서 그림자가 결정적이었을 때 계산대 채널만 남긴다.
func highlight_counter(dim: float) -> void:
	for i in _channels.size():
		_channels[i].modulate = Color.WHITE if i == COUNTER_CHANNEL \
			else Color(1.0, 1.0, 1.0, dim)


func clear_highlight() -> void:
	for channel in _channels:
		channel.modulate = Color.WHITE
