extends Control

## 부팅 화면. **흐름만 맡는다** — 배치는 `ui/title_view.gd`.
##
## 여기서 게임이 시작된다. 아무 키나 누르거나 클릭하면 밤으로 넘어간다.
## 버튼을 두지 않은 이유: 부스에서 처음 앉은 사람이 마우스를 어디로 가져갈지 고민하면
## 30초 중 몇 초를 거기 쓴다. 무엇을 눌러도 되는 화면이 가장 빠르다.
##
## `--booth`면 세이브를 무시하고 항상 첫 밤부터 시작한다. 시연대에서 앞사람의
## 진행 상황이 남아 있으면 다음 사람은 3일째 밤부터 시작하게 된다.

const ScreenEffects := preload("res://ui/screen_effects.gd")
const WindowKeys := preload("res://main/window_keys.gd")
const TitleView := preload("res://ui/title_view.gd")
const AudioDeck := preload("res://ui/audio_deck.gd")
const Palette := preload("res://ui/theme_factory.gd")

const NIGHT_SCENE := "res://main/night_screen.tscn"
const BOOTH_ARG := "--booth"
const TITLE_TENSION := 0.18

var _view: TitleView = null
var _audio: AudioDeck = null
var _entered: bool = false
## 일곱 밤을 끝낸 세이브인가. 시작을 누르면 새 회차를 연다.
var _finished: bool = false


func _ready() -> void:
	# 내보낸 빌드가 멀쩡한지 스스로 검사하고 끝낸다. PCK에서만 일어나는 사고를 잡는다.
	if BuildCheck.requested():
		# 종료 코드는 `SceneTree.quit(code)` 로만 나간다. Godot 4.4에 OS.set_exit_code 는 없다.
		get_tree().quit(BuildCheck.new().run(Palette.font()))
		return

	var strings := GameData.load_strings()
	var balance := GameData.load_balance()
	if is_booth():
		SaveGame.new().store()

	_audio = AudioDeck.new()
	add_child(_audio)
	_audio.setup(balance.get("audio", {}) as Dictionary)

	_view = TitleView.new()
	add_child(_view)
	# **완주한 사람은 다른 화면을 봐야 한다.** 세이브는 마지막 밤에 머무르므로
	# night 만 보면 일곱 밤을 끝낸 사람과 마지막 밤을 하다 만 사람이 구분되지 않는다.
	var save := SaveGame.load_or_new()
	_finished = save.has_finished(NightPlan.load().last_night())
	_view.build(strings, save.night, _finished)
	_view.play_intro()

	var effects := ScreenEffects.new()
	effects.configure(balance.get("graphics", {}) as Dictionary)
	add_child(effects)
	# 제목 화면에서도 CRT는 켜져 있다. 여기서 꺼두면 밤으로 넘어갈 때 화면 질감이 바뀐다.
	effects.set_tension(TITLE_TENSION)


static func is_booth() -> bool:
	return OS.get_cmdline_user_args().has(BOOTH_ARG)


func _unhandled_input(event: InputEvent) -> void:
	if _entered or not _is_start_input(event):
		return
	_entered = true
	_audio.play("click")
	# 일곱 밤을 끝낸 뒤에 시작하면 **다음 사람이 된다** — 밤은 처음으로, 그어둔 줄은 그대로.
	if _finished:
		var save := SaveGame.load_or_new()
		save.begin_new_run()
		save.store()
	get_tree().change_scene_to_file(NIGHT_SCENE)


## 아무 키나, 아무 버튼이나. 뗄 때가 아니라 누를 때 반응한다.
static func _is_start_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		# **F11·Alt+Enter·ESC는 밤을 시작하지 않는다.** 「아무 키나 눌러 시작」이라
		# 전체화면을 켜려던 손가락이 게임을 시작해버린다. 자동 로드가 먼저 먹어주지도
		# 않는다 — `_unhandled_input`은 트리 아래에서 위로 도는데 장면이 자동 로드보다 아래다.
		if WindowKeys.decide(event, DisplayServer.window_get_mode()) != WindowKeys.STAY:
			return false
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false
