extends SceneTree

## 실제 게임 화면을 몰아서 특정 상태를 찍는다.
##   xvfb-run -a godot --script res://tools/shoot_states.gd -- --out=/tmp/state.png --verdict=refuse
##
## `screenshot.gd`는 시작 화면만 찍는다. 이건 시그널을 직접 쏘아 판정 이후 화면까지 간다.
## 통합 경로(POS → NightScreen → ResultPanel)를 그대로 태우므로 연결이 끊기면 여기서 드러난다.


## 도구 전용 세이브. 플레이 중인 회차와 같은 파일을 쓰면 스크린샷 한 장에 진행이 날아간다.
const TOOL_SAVE_PATH := "user://tool_shots.save.json"
const POS_SCRIPT := "res://ui/pos/pos_terminal.gd"
const RESULT_SCRIPT := "res://ui/result_panel.gd"
const CUSTOMER_SCRIPT := "res://ui/customer_view.gd"
const CLIPBOARD_SCRIPT := "res://ui/clipboard/clipboard_panel.gd"
const SCENE := "res://main/night_screen.tscn"

const SETTLE_FRAMES := 30
const AFTER_FRAMES := 45
## 판정 → 리플레이 → 결과가 한 사이클이다. 한 프레임에 몰아 쏘면 흐름이 겹친다.
const STEP_FRAMES := 250
## `--verdict=none` — 판정을 쏘지 않고 계산대 화면 그대로 찍는다.
const NO_VERDICT := "none"

var _after_frames: int = AFTER_FRAMES

var _frames: int = 0
var _fired: bool = false
var _done: bool = false
var _out_path: String = "user://state.png"
var _verdict: String = Verdict.REFUSE
var _target_index: int = 0
var _advanced: int = 0
var _next_step_frame: int = SETTLE_FRAMES
var _play_wrong: bool = false
var _awaiting_continue: bool = false
var _fire_frame: int = 0
var _night: int = 1
var _final_continue: int = -1
var _final_done: bool = false
var _pressure_stage: int = -1
var _step_frames: int = STEP_FRAMES
var _strike_ids: PackedStringArray = []
var _layout_failed: bool = false


func _initialize() -> void:
	_out_path = _arg("--out=", _out_path)
	_verdict = _arg("--verdict=", _verdict)
	_after_frames = int(_arg("--after=", str(AFTER_FRAMES)))
	_target_index = int(_arg("--index=", "0"))
	# 특정 밤 화면을 찍으려면 세이브를 먼저 써둔다. 게임은 세이브가 가리키는 밤부터 시작한다.
	_night = int(_arg("--night=", "1"))
	# **진짜 세이브를 밟지 않는다.** 도구가 찍겠다고 회차를 날리면 안 된다.
	SaveGame.use_path(TOOL_SAVE_PATH)
	var save := SaveGame.new()
	save.night = _night
	save.store()
	_play_wrong = _arg("--wrong=", "0") == "1"
	# 인내는 실제로 35~60초가 걸린다. xvfb에서 그만큼 프레임을 돌리면 20분이 넘는다.
	# 시계 자체는 tests/test_patience.gd 가 헤드리스로 검증한다 — 여기서 볼 것은 **레이아웃**이다.
	_pressure_stage = int(_arg("--pressure=", "-1"))
	# 정답만 내면 리플레이가 안 도므로 손님당 프레임을 줄일 수 있다. 끝까지 가는 촬영용.
	_step_frames = int(_arg("--step=", str(STEP_FRAMES)))
	# 그은 수칙을 화면에서 보려면 실제로 시그널을 쏘아야 한다. 세이브에 직접 쓰면
	# 클립보드가 그리는 경로(strike_toggled → set_struck)를 건너뛰어 검증이 안 된다.
	_strike_ids = _arg("--strike=", "").split(",", false)
	_final_continue = int(_arg("--final-continue=", "-1"))
	var packed: PackedScene = load(SCENE)
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		# 배치 검사가 실패했으면 종료 코드로 알린다. 스크린샷만 남기고 0을 돌려주면
		# 자동화가 통과로 읽는다 — 검사가 아니라 장식이 된다.
		if _layout_failed:
			quit(1)
		return true
	_frames += 1
	if not _fired and _frames >= _next_step_frame:
		_fire()
		return false
	# 밤이 실패로 끝나는 연출은 "다음 손님"을 한 번 더 눌러야 시작된다.
	if _fired and not _final_done and _final_continue >= 0 \
			and _frames >= _fire_frame + _final_continue:
		var panel := _find_by_script(root, RESULT_SCRIPT)
		if panel != null:
			panel.continued.emit()
		_final_done = true
	if _fired and _frames >= _fire_frame + _after_frames:
		_capture()
		_done = true
	return false


## 목표 손님까지 정답으로 진행한 뒤, 거기서 지정한 판정을 쏜다.
func _fire() -> void:
	var pos := _find_by_script(root, POS_SCRIPT)
	var result_panel := _find_by_script(root, RESULT_SCRIPT)
	if pos == null or result_panel == null:
		push_error("화면 구성이 바뀌었다 — POS 또는 결과 패널을 찾을 수 없다")
		_done = true
		return
	if _advanced < _target_index:
		# 판정과 진행을 같은 프레임에 쏘면 리플레이가 도는 중에 다음 손님이 들어온다.
		if _awaiting_continue:
			result_panel.continued.emit()
			_awaiting_continue = false
			_advanced += 1
		else:
			pos.verdict_chosen.emit(_step_verdict())
			_awaiting_continue = true
		_next_step_frame = _frames + _step_frames
		return
	if _strike_ids.size() > 0:
		var clipboard := _find_by_script(root, CLIPBOARD_SCRIPT)
		if clipboard != null:
			for id in _strike_ids:
				clipboard.strike_toggled.emit(id)
			print("그은 수칙: %s" % ", ".join(_strike_ids))
		_strike_ids = PackedStringArray()
	if _pressure_stage >= 0:
		var view := _find_by_script(root, CUSTOMER_SCRIPT)
		if view != null:
			view.set_pressure_stage(_pressure_stage)
		_fired = true
		_fire_frame = _frames
		print("압박 단계 %d 를 그린다" % _pressure_stage)
		return
	# **판정 전 화면을 찍는 길.** 이 도구는 늘 판정을 쏘고 나서야 찍었는데, 그러면
	# POS 는 잠기고 버튼은 비활성이라 **계산대 자체를 볼 수가 없다.** 포커스 테두리처럼
	# 판정 전에만 존재하는 것은 확인할 방법이 없었다.
	if _verdict == NO_VERDICT:
		_fired = true
		_fire_frame = _frames
		print("손님 %d 를 판정 없이 찍는다" % _target_index)
		return
	pos.verdict_chosen.emit(_verdict)
	_fired = true
	_fire_frame = _frames
	print("손님 %d 에서 판정 발사: %s" % [_target_index, _verdict])


## 목표까지 가는 동안 무엇을 낼지. 기본은 정답(밤이 안 끝나야 하므로),
## `--wrong=1`이면 일부러 오답을 내서 밤을 실패시킨다 (사망 연출 촬영용).
func _step_verdict() -> String:
	var right := _correct_verdict()
	if not _play_wrong:
		return right
	return Verdict.REFUSE if right == Verdict.SERVE else Verdict.SERVE


func _correct_verdict() -> String:
	# **밤 번호를 넘겨야 한다.** 1로 굳히면 밤 2의 수칙이 빠진 채 정답을 계산해
	# 도구가 엉뚱한 판정을 쏘고, 밤이 의도대로 진행되지 않는다.
	var engine := RuleEngine.new(GameData.load_rules())
	var customers := NightPlan.load().customers_for(_night)
	var ctx := JudgeContext.new(
		_night, NightSession.arrival_minutes(_advanced, customers.size()), customers[_advanced])
	return engine.required_verdicts(ctx)[0].id()


## 찍는 **그 프레임**의 배치를 같이 찍는다.
##
## 화면에서 잘려 나간 것을 스크린샷만 보고 추론하다 두 번 틀렸다. 어느 상자가
## 얼마나 커졌는지는 스크린샷에 안 나오고 숫자에만 나온다.
func _dump_layout() -> void:
	var box := _find_layout_box(root)
	if box == null:
		return
	print("배치 (화면 %d) — VBox y=%.0f h=%.0f min=%.0f"
		% [root.size.y, box.global_position.y, box.size.y, box.get_combined_minimum_size().y])
	for child in box.get_children():
		if child is Control:
			var c := child as Control
			print("  %-16s vis=%-5s y=%6.1f h=%6.1f bottom=%6.1f min=%5.1f"
				% [c.get_class(), str(c.visible), c.global_position.y, c.size.y,
					c.global_position.y + c.size.y, c.get_combined_minimum_size().y])


static func _find_layout_box(node: Node) -> VBoxContainer:
	if node is VBoxContainer and node.get_child_count() >= 4:
		return node as VBoxContainer
	for child in node.get_children():
		var found := _find_layout_box(child)
		if found != null:
			return found
	return null


## 내용이 화면 밖으로 나갔는가. **나갔으면 버튼을 못 누른다.**
##
## 헤드리스 단위 테스트로는 못 잡는다 — 실제로 시도했고 예전 코드를 넣어도 통과했다.
## 늘어나는 조건(오답 셰이크 + 내용이 정한 최소 크기 + 앵커)이 진짜 화면에서만 갖춰진다.
## 그래서 **여기가 이 버그의 유일한 검사 자리**다:
##   xvfb-run -a godot --script res://tools/shoot_states.gd -- \
##     --out=/tmp/x.png --night=6 --wrong=1 --index=1 --assert-layout=1
func _assert_layout() -> int:
	var box := _find_layout_box(root)
	if box == null:
		print("배치 상자를 못 찾았다 — 화면 구조가 바뀌었다")
		return 1
	var bottom := box.global_position.y + box.size.y
	# **캔버스 높이와 비교해야 한다.** `root.size.y`는 실제 창 크기라 stretch가 걸리면
	# 배치 좌표와 다른 공간의 값이다. 1080 창에서 재보면 root.size.y=1080, 캔버스=720 —
	# 그 상태로는 692 ≤ 1080 이 되어 **어떤 넘침도 통과한다.** 720에서만 우연히 맞았다.
	# 검사가 조용히 일을 그만두는 것이 이 프로젝트에서 반복해서 나온 실패 방식이다.
	var screen := root.get_visible_rect().size.y
	if bottom <= screen:
		print("배치 정상 — 바닥 %.0f ≤ 화면 %.0f" % [bottom, screen])
		return 0
	print("배치 넘침 — 바닥 %.0f > 화면 %.0f (%.0fpx 잘렸다). 버튼을 누를 수 없다"
		% [bottom, screen, bottom - screen])
	return 1


func _capture() -> void:
	if _arg("--dump-layout=", "0") == "1":
		_dump_layout()
	if _arg("--assert-layout=", "0") == "1" and _assert_layout() != 0:
		_layout_failed = true
	var image := root.get_texture().get_image()
	if image == null or image.save_png(_out_path) != OK:
		push_error("스크린샷 저장 실패")
		return
	print("저장됨: ", ProjectSettings.globalize_path(_out_path))


static func _find_by_script(node: Node, script_path: String) -> Node:
	var script: Variant = node.get_script()
	if script is Script and (script as Script).resource_path == script_path:
		return node
	for child in node.get_children():
		var found := _find_by_script(child, script_path)
		if found != null:
			return found
	return null


static func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
