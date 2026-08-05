extends RefCounted

## 테마를 코드로 만든다. 에디터에서만 존재하는 설정을 만들지 않는다 (CLAUDE.md 1.2).
## `class_name`은 systems/ 와 data/ 에서만 선언하므로 preload로 쓴다 (CLAUDE.md 4절).

# 팔레트 — 차가운 형광등 아래의 편의점, 그리고 따뜻한 종이 한 장.
const BG := Color("0d0f10")
const PANEL := Color("16191b")
const PANEL_EDGE := Color("272c2f")
const TEXT := Color("c8cdd0")
const TEXT_DIM := Color("6b7275")
const PAPER := Color("d8d2c4")
const PAPER_TEXT := Color("23201c")
const PAPER_EDGE := Color("b3ac9c")

# 잉크 두 종. 점장의 펜과, 나중에 누군가 덧쓴 펜.
# 차이가 크면 퍼즐이 죽고 작으면 불공정해진다 — 스크린샷으로 조정할 것 (F-05).
const INK_MANAGER := Color("23201c")
const INK_LATER := Color("2b2a33")
const ACCENT := Color("e8a33d")
const DANGER := Color("c0392b")
const OK := Color("7fa650")

const FONT_CANDIDATES := [
	"Malgun Gothic", "Noto Sans CJK KR", "NanumGothic", "AppleGothic", "sans-serif",
]

const SIZE_SMALL := 14
const SIZE_BODY := 17
const SIZE_HEAD := 21
const SIZE_CLOCK := 34


static func font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FONT_CANDIDATES)
	return f


static func panel_style(fill: Color, edge: Color, radius: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


## 버튼 하나를 통째로 스타일링한다. 상태별 스타일박스를 전부 넣어야 눌린 느낌이 산다.
static func style_button(button: Button, tint: Color, text_color: Color) -> void:
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", SIZE_BODY)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.25))
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.2))
	button.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.3))
	button.add_theme_stylebox_override("normal", panel_style(tint, tint.lightened(0.18)))
	button.add_theme_stylebox_override("hover", panel_style(tint.lightened(0.12), tint.lightened(0.35)))
	button.add_theme_stylebox_override("pressed", panel_style(tint.darkened(0.25), tint))
	button.add_theme_stylebox_override("disabled", panel_style(PANEL, PANEL_EDGE))


static func make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
