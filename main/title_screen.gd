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
const TitleView := preload("res://ui/title_view.gd")
const AudioDeck := preload("res://ui/audio_deck.gd")

const NIGHT_SCENE := "res://main/night_screen.tscn"
const BOOTH_ARG := "--booth"
const TITLE_TENSION := 0.18

var _view: TitleView = null
var _audio: AudioDeck = null
var _entered: bool = false


func _ready() -> void:
	var strings := GameData.load_strings()
	var balance := GameData.load_balance()
	if is_booth():
		SaveGame.new().store()

	_audio = AudioDeck.new()
	add_child(_audio)
	_audio.setup(balance.get("audio", {}) as Dictionary)

	_view = TitleView.new()
	add_child(_view)
	_view.build(strings, SaveGame.load_or_new().night)
	_view.play_intro()

	var effects := ScreenEffects.new()
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
	get_tree().change_scene_to_file(NIGHT_SCENE)


## 아무 키나, 아무 버튼이나. 뗄 때가 아니라 누를 때 반응한다.
static func _is_start_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false
