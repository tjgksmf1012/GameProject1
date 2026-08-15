extends RefCounted

const Palette := preload("res://ui/theme_factory.gd")

## **종이가 화면에서 가장 밝다.** 이 게임의 시각 규칙 한 줄이고, 지금까지 아무도 안 재고 있었다.
##
## 실제로 깨졌다. 손님 도형에 살구색 얼굴(`#625850`)과 황토색 가방(`#8b7b57`)이 들어오고
## 품목 아이콘에 `#e7e0cf`(밝기 224)가 들어오자, 실제 프레임에서 손님 패널의 가장 밝은
## 픽셀이 **종이가 아니라 에너지드링크 글리프**가 됐다. 종이는 210이다.
##
## 눈으로는 「좀 밝네」로 넘어간다. 그래서 숫자로 잰다.
##
## **소스를 직접 읽어서 센다.** 색 목록을 손으로 적어 두면 조용히 낡는다 —
## `tests/test_sfx_bank.gd`에서 같은 실수를 했고, 소스를 파싱하도록 고친 다음 커밋 하나
## 만에 빠진 소리를 잡았다. 새 색을 하나 넣으면 그게 무엇이든 여기서 걸린다.

## 클립보드와 **같은 화면에** 그려지는 것들. 제목 화면 배경(`store_backdrop.gd`)은
## 뺀다 — 거기엔 종이가 없고, 천장 형광등은 밝은 것이 맞다.
const CANVASES := [
	"res://ui/art/customer_figure.gd",
	"res://ui/art/product_glyph.gd",
]

## 종이 밝기의 몇 할까지 봐주는가. **1.0에 두지 않는다** — 물어야 할 것은
## 「모든 색이 완벽한가」가 아니라 **「종이가 여전히 확실히 이기는가」**다.
## 작성 목표는 0.90이고 이 문턱은 반올림 여유를 둔 0.92다.
const BRIGHTNESS_GATE := 0.92


func run(r: RefCounted) -> void:
	r.suite("art_palette")
	_test_nothing_outshines_the_paper(r)
	_test_the_customer_has_no_face(r)


static func _luminance(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


func _test_nothing_outshines_the_paper(r: RefCounted) -> void:
	var paper := _luminance(Palette.PAPER)
	var limit := paper * BRIGHTNESS_GATE
	var counted := 0
	for path in CANVASES:
		var colors := _colors_in(str(path))
		r.check(colors.size() > 0, "%s에서 색을 하나도 못 읽었다 — 검사가 아무것도 안 했다" % path)
		for hex in colors:
			counted += 1
			var value := _luminance(Color(str(hex)))
			# 사람이 읽는 단위로 낸다. 0~1 로 찍으면 「0.9 > 0.8」이 되어 얼마나 밝은지 안 와닿는다.
			r.check(value <= limit,
				"%s의 #%s가 종이보다 밝다 (밝기 %.0f > 한계 %.0f, 종이 %.0f) — 화면에서 가장 밝은 것은 종이여야 한다"
					% [path.get_file(), hex, value * 255.0, limit * 255.0, paper * 255.0])
	r.check(counted >= 20, "센 색이 %d개뿐이다 — 파싱이 깨졌을 수 있다" % counted)


## 손님은 실루엣이다. **얼굴이 보이면 판단이 아니라 인상이 된다** (`docs/art/GPT-BRIEF.md`).
## 살구색이 다시 들어오는 것을 막는다 — 스토어 캡슐 다섯 장도 전부 얼굴 없는 실루엣이다.
func _test_the_customer_has_no_face(r: RefCounted) -> void:
	for hex in _colors_in("res://ui/art/customer_figure.gd"):
		var color := Color(str(hex))
		var warmth := color.r - color.b
		r.check(warmth <= 0.06,
			"손님 도형의 #%s가 따뜻하다 (R-B %.3f) — 살색이 돌면 실루엣이 아니다" % [hex, warmth])


## 소스에서 `Color("rrggbb")` 리터럴을 전부 뽑는다.
static func _colors_in(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(path):
		return out
	var regex := RegEx.new()
	regex.compile('Color\\("([0-9a-fA-F]{6})"\\)')
	for found in regex.search_all(FileAccess.get_file_as_string(path)):
		out.append(found.get_string(1))
	return out
