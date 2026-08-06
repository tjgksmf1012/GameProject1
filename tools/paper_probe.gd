extends SceneTree

## **종이 단서가 화면에서 살아남는지 잰다.**
##   xvfb-run -a godot --script res://tools/paper_probe.gd
##
## 이 게임의 핵심 시각 단서는 종이 두 종의 밝기 차이 **3.8%** 다 (F-05).
## 그런데 `tests/`도 `ScreenSnapshot`도 그게 화면에서 보이는지 알지 못한다 —
## 둘 다 `balance.json`에 적힌 **의도된** 숫자를 읽을 뿐이다. 셰이더가 그 위에 무엇을
## 덮든 구조적으로 못 본다. 블라인드 플레이 결과도 같은 이유로 이 문제에 눈이 멀어 있다.
##
## 그래서 실제 프레임버퍼를 읽는다. 재는 것은 둘:
##
##   ① **위치 편차** — 같은 종이인데 클립보드 위/아래에 있다는 이유만으로 밝기가 다른가.
##      이게 단서보다 크면 플레이어는 단서 대신 위치를 보고 있는 것이다.
##   ② **단서 대비** — 종이 두 종이 실제로 얼마나 벌어져 보이는가.
##
## 실제로 잡아낸 것: 비네트가 종횡비 보정 없이 돌아 위치 편차가 **8.6%** 였다.
## 단서 3.8%의 2.3배. 즉 단서가 자기 위에 얹힌 잡음보다 작았다.
##
## 주사선은 고주파라 넓은 영역 평균에는 영향이 없다. 그래서 세로로 **주사선 여러 주기**를
## 평균내어 상쇄한다 — 안 그러면 주사선 위상만 재고 끝난다. 실제로 한 번 그랬다.
##
## **실제 클립보드를 그대로 재면 안 된다.** 밤 7의 클립보드에는 점장 종이·나중 종이·
## 고쳐 쓴 종이가 섞여 있어서, 위치 편차를 재려던 것이 종이 종류 차이를 재고 만다.
## 처음에 그렇게 짜서 13%가 나왔고 그건 버그가 아니라 정상이었다.
## 그래서 **같은 색 견본을 클립보드 자리에 덮어놓고** 잰다 — 자리는 진짜, 내용은 통제.

const SCENE := "res://main/night_screen.tscn"
## 견본을 덮는 층. UI(0)보다 위, CRT(100)·그레인(101)보다 **아래**여야
## 재려는 효과가 견본 위에 그대로 얹힌다.
const SWATCH_LAYER := 50
## data/balance.json 의 clipboard_paper.tone_manager 가 곱해지기 전의 종이색.
const PAPER := Color("d8d2c4")
const SETTLE_FRAMES := 45
## 세로 평균 창. 주사선 주기(4px 목표)의 여러 배수여야 위상이 상쇄된다.
const WINDOW_PX := 24
## 표본을 뽑을 가로 구간 — 클립보드 오른쪽 여백. 글자가 닿지 않는 순수 종이여야 한다.
const MARGIN_FROM_RIGHT := 38
const SAMPLE_WIDTH := 11
## 위치 편차가 이 이상이면 실패. 단서(3.8%)의 1/4 — 잡음이 단서를 흔들면 안 된다.
const MAX_POSITION_SPREAD := 1.0
## 단서 대비가 이보다 작아지면 실패. 의도값 3.95%의 4분의 3.
const MIN_CLUE_CONTRAST := 3.0

var _frames: int = 0
var _started: bool = false


func _initialize() -> void:
	var save := SaveGame.new()
	save.night = int(_arg("--night=", "7"))
	save.store()
	change_scene_to_file(SCENE)


## `_process`가 true를 돌려주면 그 자리에서 루프가 끝난다. 측정은 프레임을 더 기다려야
## 하므로(견본을 덮고 다시 그려야 한다) **false를 돌려주고 `quit()`으로 끝낸다.**
## 처음에 true를 돌려줬더니 await가 재개되기 전에 트리가 죽어 아무것도 안 찍혔다.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= SETTLE_FRAMES and not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	quit(await _measure())


## 클립보드 자리에 같은 색 견본을 덮고, 그 위를 세로로 훑는다.
func _measure() -> int:  # await 를 쓰므로 코루틴이다
	var clipboard := _find_clipboard(current_scene)
	if clipboard == null:
		print("클립보드를 찾지 못했다 — 화면 구조가 바뀌었다")
		return 1
	var rect := clipboard.get_global_rect()
	_lay_swatch(rect)
	await process_frame
	await process_frame
	var image := get_root().get_texture().get_image()
	# 왼쪽 판(점장 종이) 안쪽에서 뽑는다. 오른쪽 판에 걸치면 종이 종류 차이를 재게 된다.
	var x0 := int(rect.position.x + rect.size.x * 0.5) - MARGIN_FROM_RIGHT
	var rows := _sample_rows(image, rect, x0)
	if rows.size() < 3:
		print("표본이 %d개뿐이다 — 클립보드가 너무 작거나 화면이 안 그려졌다" % rows.size())
		return 1
	var code := _report(rows)
	return maxi(code, _report_contrast(image, rect))


## 클립보드 자리를 덮는 판 둘. 왼쪽은 점장 종이, 오른쪽은 나중 종이.
##
## 위치 편차는 **왼쪽 판 안에서** 세로로 재고, 단서 대비는 **같은 높이의 좌우**로 잰다.
## 자리는 진짜 클립보드, 내용만 통제된 상태다.
func _lay_swatch(rect: Rect2) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = SWATCH_LAYER
	get_root().add_child(canvas)
	var paper: Dictionary = GameData.load_balance().get("clipboard_paper", {})
	for i in 2:
		var key := "tone_later" if i == 1 else "tone_manager"
		var swatch := ColorRect.new()
		swatch.color = PAPER * float(paper.get(key, 1.0))
		swatch.position = rect.position + Vector2(rect.size.x * 0.5 * float(i), 0.0)
		swatch.size = Vector2(rect.size.x * 0.5, rect.size.y)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(swatch)


func _sample_rows(image: Image, rect: Rect2, x0: int) -> Array:
	var out := []
	var y := int(rect.position.y) + WINDOW_PX
	var last := int(rect.position.y + rect.size.y) - WINDOW_PX
	while y < last:
		out.append({"y": y, "value": _block(image, x0, y)})
		y += WINDOW_PX * 2
	return out


## 세로 창 하나의 평균 밝기. 주사선을 상쇄하는 것이 이 평균의 목적이다.
func _block(image: Image, x0: int, y0: int) -> float:
	var total := 0.0
	var count := 0
	for y in range(y0, y0 + WINDOW_PX):
		for x in range(x0, x0 + SAMPLE_WIDTH):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var c := image.get_pixel(x, y)
			total += (c.r + c.g + c.b) / 3.0
			count += 1
	return total / maxf(1.0, float(count))


func _report(rows: Array) -> int:
	var low := INF
	var high := -INF
	print("클립보드 여백의 위치별 밝기 (세로 %dpx 평균, 주사선 상쇄)" % WINDOW_PX)
	for row in rows:
		var value: float = row["value"]
		low = minf(low, value)
		high = maxf(high, value)
		print("  y=%4d   %.4f" % [row["y"], value])
	var spread := (high / maxf(low, 0.0001) - 1.0) * 100.0
	print("\n위치만으로 인한 편차   %.2f%%   (한계 %.2f%%)" % [spread, MAX_POSITION_SPREAD])
	print("실제 단서(종이 두 종)   3.80%")
	if spread <= MAX_POSITION_SPREAD:
		print("통과 — 단서가 위치 잡음보다 크다")
		return 0
	print("실패 — **위치 잡음이 단서를 덮는다.** 매끄러운 휘도 효과가 클립보드 위에 있다")
	return 1


## **단서가 실제로 얼마나 벌어져 보이는가.** 이게 이 도구의 진짜 목적이다.
## 위치 편차가 0이어도 대비가 죽어 있으면 단서는 없는 것이다.
func _report_contrast(image: Image, rect: Rect2) -> int:
	var y := int(rect.position.y + rect.size.y * 0.5) - WINDOW_PX / 2
	var left := _block(image, int(rect.position.x + rect.size.x * 0.5) - MARGIN_FROM_RIGHT, y)
	var right := _block(image, int(rect.position.x + rect.size.x) - MARGIN_FROM_RIGHT, y)
	var delta := (left / maxf(right, 0.0001) - 1.0) * 100.0
	print("\n종이 두 종의 실제 대비   %.2f%%   (의도 %.2f%%)"
		% [delta, (1.0 / float(GameData.load_balance()
			.get("clipboard_paper", {}).get("tone_later", 0.962)) - 1.0) * 100.0])
	if delta >= MIN_CLUE_CONTRAST:
		print("통과 — 단서가 화면에 살아 있다")
		return 0
	print("실패 — **단서가 화면에서 사라졌다.** 셰이더가 종이 차이를 뭉갰다")
	return 1


## 클립보드 패널을 이름이 아니라 **스크립트로** 찾는다. 노드 경로를 박지 않는다 (CLAUDE.md 1.2).
func _find_clipboard(node: Node) -> Control:
	if node is Control and node.get_script() != null \
			and str(node.get_script().resource_path).ends_with("clipboard_panel.gd"):
		return node as Control
	for child in node.get_children():
		var found := _find_clipboard(child)
		if found != null:
			return found
	return null


static func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
