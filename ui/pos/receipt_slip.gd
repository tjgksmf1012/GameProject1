extends Control

## 영수증. **화면에서 두 번째로 밝은 종이다.**
##
## 예전에는 이 자리가 라벨 두 개였다 — 「영수증 / — / Total ₩0」. 화면 아래 3분의 1을
## 차지하면서 거의 비어 있었고, 품목을 찍어도 글자 한 줄이 늘 뿐이라 **아무 일도 일어나지
## 않는 것처럼** 보였다. 스캔은 이 게임에서 「파는 것은 일이다」를 만드는 유일한 노동인데
## 그 노동에 결과가 없었다.
##
## 이제 종이다. 슬롯에서 올라오고, 아래 끝이 톱니로 잘려 있고, 찍을 때마다 한 줄씩 길어진다.
## 전부 절차적 도형과 타이포그래피다 — 이미지 파일 0개 (CLAUDE.md 1.1).
##
## **클립보드와 헷갈리면 안 된다.** 저쪽은 손으로 쓴 수칙이고 이쪽은 기계가 뽑은 영수증이다.
## 그래서 색을 살짝 차갑게, 글자를 작게, 줄 간격을 좁게 둔다.

const Palette := preload("res://ui/theme_factory.gd")

const PAPER := Color("e6e3da")
const INK := Color("2a2724")
const INK_DIM := Color("6b665e")
## 아래 끝의 톱니. 자른 자국이 없으면 그냥 흰 사각형이다.
const TOOTH_COUNT := 22
const TOOTH_HEIGHT := 7.0
const SLIP_WIDTH := 228.0
## 슬롯에서 올라오는 거리와 시간.
const RISE_PIXELS := 26.0
const RISE_SECONDS := 0.26

var _strings: Dictionary = {}
## 컨테이너 **안에 넣지 않는다.** 넣으면 배치가 위치를 관리해서 「올라오는」 트윈이
## 매 프레임 되돌려진다. 대신 PanelContainer 를 손으로 놓고 크기만 내용에서 받아온다.
var _paper: PanelContainer = null
var _lines: VBoxContainer = null
var _teeth: Polygon2D = null
var _tween: Tween = null


func _init() -> void:
	# 슬롯. 종이가 이 밖으로 나가면 잘린다 — 그래서 「올라온다」로 읽힌다.
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(strings: Dictionary) -> void:
	_strings = strings
	if _paper != null:
		return
	_paper = PanelContainer.new()
	_paper.add_theme_stylebox_override("panel", _paper_style())
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)

	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 2)
	_paper.add_child(_lines)

	_teeth = Polygon2D.new()
	# **뒤에 실제로 있는 색**이어야 판 자국으로 보인다. 계산대 상판 위에 놓인 종이다.
	_teeth.color = Palette.COUNTER
	_paper.add_child(_teeth)
	_paper.resized.connect(_cut_teeth)


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


## 종이 자체. 클립보드와 달리 테두리가 없다 — 잘려 나온 띠라 가장자리가 종이의 끝이다.
static func _paper_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	# 아래는 톱니가 파먹을 만큼 더 준다. 안 그러면 합계 줄이 잘린 자국에 물린다.
	box.content_margin_bottom = 10.0 + TOOTH_HEIGHT
	box.shadow_size = 10
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_offset = Vector2(2, 4)
	return box


## 아래 끝을 톱니로 판다. 배경색으로 덮어 **잘린 자국**을 만든다.
func _cut_teeth() -> void:
	if _teeth == null or _paper.size.x <= 0.0:
		return
	# 지그재그 선과 **종이 아래 끝 사이**를 덮는다. 아래로 더 내려가면 종이 바깥을
	# 칠하게 되고, 그건 잘린 자국이 아니라 그냥 안 보이는 도형이다 — 처음에 그랬다.
	var points := PackedVector2Array()
	var step := _paper.size.x / float(TOOTH_COUNT)
	var notch := _paper.size.y - TOOTH_HEIGHT
	points.append(Vector2(0.0, _paper.size.y))
	for i in TOOTH_COUNT + 1:
		points.append(Vector2(float(i) * step, notch if i % 2 == 0 else _paper.size.y))
	points.append(Vector2(_paper.size.x, _paper.size.y))
	_teeth.polygon = points


## 찍힌 품목과 합계를 다시 인쇄한다. 줄이 늘면 종이가 한 번 더 올라온다.
func print_lines(items: Array, total_text: String, grew: bool) -> void:
	if _lines == null:
		return
	for child in _lines.get_children():
		child.queue_free()
	_head()
	for item in items:
		_row(str((item as Dictionary)["name"]), str((item as Dictionary)["price"]), INK)
	_rule()
	_row(_t("receipt.total"), total_text, INK)
	_place.call_deferred(grew)


## 종이를 슬롯 가운데에 놓고 **내용 높이만큼** 키운다.
## 컨테이너를 안 쓰므로 이 계산을 손으로 한다 — 대신 트윈이 안 밟힌다.
func _place(grew: bool) -> void:
	if _paper == null:
		return
	var wanted := _paper.get_combined_minimum_size().y
	_paper.size = Vector2(SLIP_WIDTH, wanted)
	_paper.position = Vector2((size.x - SLIP_WIDTH) * 0.5, 0.0)
	_cut_teeth()
	if grew:
		_rise()


func _head() -> void:
	_center(_t("receipt.store"), Palette.SIZE_BODY, INK)
	_center(_t("receipt.biz"), Palette.SIZE_SMALL, INK_DIM)
	_center(_t("receipt.register"), Palette.SIZE_SMALL, INK_DIM)
	_rule()


func _center(text: String, size: int, color: Color) -> void:
	var label := Palette.make_label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.add_child(label)


## 품목 한 줄. 이름은 왼쪽, 값은 오른쪽 — 영수증은 값이 한 줄로 서 있어야 영수증이다.
func _row(name: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var left := Palette.make_label(name, Palette.SIZE_SMALL, color)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := Palette.make_label(value, Palette.SIZE_SMALL, color)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# **값은 절대 줄바꿈하지 않는다.** 「₩」와 「0」이 두 줄로 갈라지면 영수증이 아니다.
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(left)
	row.add_child(right)
	_lines.add_child(row)


func _rule() -> void:
	var line := ColorRect.new()
	line.color = Color(INK.r, INK.g, INK.b, 0.28)
	line.custom_minimum_size = Vector2(0, 1)
	_lines.add_child(line)


## 슬롯에서 한 뼘 올라온다. 스캔에 **물리적 결과**를 붙이는 것이 이 연출의 전부다.
func _rise() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_paper.position.y += RISE_PIXELS
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_paper, "position:y", 0.0, RISE_SECONDS)
