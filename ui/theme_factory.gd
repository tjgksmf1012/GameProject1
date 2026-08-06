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
## **강조는 드물어야 강조다.** 예전에는 이 색이 여섯 파일 열 곳에 있었고 —
## 시계·CCTV·보이는 것·품목 스캔·영수증·재촉·결과 — 그러면 그건 강조가 아니라 테마색이다.
## 지금 남은 자리는 셋뿐이다: 시계, 손님의 재촉, 결과 문구. 늘리지 말 것.
const ACCENT := Color("e8a33d")
## 구획 이름표. 읽히되 눈을 끌지 않는다.
const SECTION := Color("6f7a7d")
const DANGER := Color("c0392b")
const OK := Color("7fa650")

## OS에 이 이름이 있으면 쓴다. **번들 폰트가 없을 때만 여기까지 온다.**
const FONT_CANDIDATES := [
	"Malgun Gothic", "Noto Sans CJK KR", "NanumGothic", "AppleGothic", "sans-serif",
]

## 동봉한 폰트. 있으면 무조건 이걸 쓴다 — OS가 뭘 갖고 있든 화면이 같아야 한다.
const BUNDLED_FONT_PATHS := ["res://fonts/ui.ttf", "res://fonts/ui.otf"]

## 그림자. 위에서 비추는 형광등이므로 아래로 떨어진다.
const SHADOW_SIZE := 14
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const SHADOW_OFFSET := Vector2(3, 8)

const SIZE_SMALL := 14
const SIZE_BODY := 17
const SIZE_HEAD := 21
const SIZE_CLOCK := 34


## 화면에 글자를 내는 물건.
##
## **왜 폰트는 동봉하는가 (CLAUDE.md 1.1의 예외).** 1.1은 외부 에셋을 오디오로 한정한다.
## 그 조항이 막으려는 것은 **그려진 이미지**다 — 스프라이트, 픽셀 아트, 손그림 텍스처.
## 폰트는 그림이 아니라 글자를 화면에 내는 장치이고, 1.1 자신이 타이포그래피를 허용
## 수단으로 명시한다 ("폰트가 아트의 절반이다"). 화면에 나오는 모든 글자는 여전히
## `data/strings_*.json`에서 온다 — 코드 밖에 있고, 내가 다 읽을 수 있다.
##
## 결정적인 이유는 실행 가능성이다. 한글 11,172자를 절차적으로 만들 수는 없고,
## Proton/Linux에는 CJK 폰트가 **없는 것이 기본**이다. 동봉하지 않으면 그 환경에서
## 화면 전체가 두부(□)가 된다. 게임이 안 돌아가게 만드는 제약은 자기 목적을 배반한다.
##
## 대신 오디오와 **같은 절차**를 그대로 진다: OFL/CC0만, 라이선스 원문을 `docs/licenses/`에
## 원문 보관, `credits.md`에 즉시 기록. 그 절차가 이 예외의 값이다.
##
## 파일이 없으면 지금까지대로 OS 폰트로 물러선다 — 폰트를 넣기 전에도 빌드가 돌아간다.
static func font() -> Font:
	for path in BUNDLED_FONT_PATHS:
		if ResourceLoader.exists(path):
			return load(path) as Font
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FONT_CANDIDATES)
	return f


## 동봉 폰트를 실제로 쓰고 있는가. 빌드 검사가 이걸 보고 무엇을 보고할지 정한다.
static func has_bundled_font() -> bool:
	for path in BUNDLED_FONT_PATHS:
		if ResourceLoader.exists(path):
			return true
	return false


## 패널 하나. **그림자가 물건과 div 를 가른다.**
## 그림자 없는 사각형은 화면에 그려진 영역이고, 그림자가 있으면 무언가가 놓여 있는 것이다.
## 세 줄로 살 수 있는 것 중 이만한 게 없다.
static func panel_style(fill: Color, edge: Color, radius: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_size = SHADOW_SIZE
	box.shadow_color = SHADOW_COLOR
	box.shadow_offset = SHADOW_OFFSET
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
