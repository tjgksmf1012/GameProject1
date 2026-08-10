extends RefCounted

## 클립보드에 붙는 **종이 한 줄**. 수칙·찢긴 자국·메모가 전부 이걸로 만들어진다.
##
## `clipboard_panel.gd`에서 떼어냈다. 종이를 만드는 방법이 세 군데로 갈라지면 셋이
## 조용히 달라지고, 그러면 「같은 클립보드에 적힌 것」이라는 인상이 먼저 무너진다.
## 그 인상이 이 게임의 코어 훅이다 — 같은 종이인데 어떤 줄은 종이가 다르다는 것.

const Palette := preload("res://ui/theme_factory.gd")
const PAPER_SHADER := preload("res://shaders/paper.gdshader")


static func style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func material(foreign: bool, rewritten: bool, index: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PAPER_SHADER
	# 종이 값은 data/balance.json에 있고 **ScreenSnapshot과 같은 함수로** 뽑는다.
	# 화면과 스냅샷이 어긋나면 블라인드 플레이 결과가 통째로 무의미해진다.
	var values := ScreenSnapshot.paper_values(
		foreign, rewritten, GameData.load_balance().get("clipboard_paper", {}))
	for name in values:
		mat.set_shader_parameter(str(name), values[name])
	# 줄마다 섬유가 달라야 종이 두 장이 똑같아 보이지 않는다.
	mat.set_shader_parameter("fiber_seed", float(index) * 37.0 + 11.0)
	return mat


## 종이 위의 한 줄. 라벨은 항상 첫 자식이므로 부르는 쪽이 `get_child(0)`으로 잡는다.
static func make(
	text: String, size: int, ink: Color, foreign: bool, rewritten: bool, index: int
) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", style())
	row.material = material(foreign, rewritten, index)
	# 수칙은 **사람이 손으로 쓴 것**이다. 영수증·시계와 같은 목소리로 말하면 안 된다.
	row.add_child(Palette.make_label(text, size, ink, Palette.ROLE_RULES))
	return row


static func label_of(row: PanelContainer) -> Label:
	return row.get_child(0) as Label
