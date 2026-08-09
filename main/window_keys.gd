extends Node

## 창 키 둘. **설정 화면이 없는 게임이라 키가 곧 설정이다.**
##
## 이 게임에는 옵션 메뉴가 없고 만들지도 않는다 — 제목 화면이 튜토리얼을 대신하는 것과
## 같은 이유다 (05-prioritization.md). 그런데 1280x720 창으로만 도는 게임은 1440p·4K
## 모니터에서 우표만 하게 뜨고, **스팀덱은 아예 전체화면으로 실행된다** (M6 "Steam Deck 확인").
##
##   F11 · Alt+Enter   전체화면 토글
##   ESC               전체화면일 때만 창으로 돌아간다
##
## 화면에 안내하지 않는다. 둘 다 어느 게임에서나 같은 키라 배울 것이 없다.
##
## **ESC로 게임을 끝내지 않는다.** 이 게임은 밤 단위로만 저장하고 중간 저장이 없다
## (save_game.gd). 한 키에 밤 하나가 날아가면 그건 편의가 아니라 사고다.
## 창을 닫는 것은 창 버튼과 Alt+F4가 이미 한다.
##
## 판단은 `decide()`에 모아 두었다. 노드 없이 검증할 수 있어야 하기 때문이다 —
## 전체화면은 xvfb 스크린샷으로 확인이 안 되는 몇 안 되는 것 중 하나다.

const STAY := 0
const GO_FULLSCREEN := 1
const GO_WINDOWED := 2


func _unhandled_input(event: InputEvent) -> void:
	var action := decide(event, DisplayServer.window_get_mode())
	if action == STAY:
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if action == GO_FULLSCREEN
		else DisplayServer.WINDOW_MODE_WINDOWED)
	get_viewport().set_input_as_handled()


## 이 입력에 창을 어떻게 할 것인가. 순수 판단이라 헤드리스로 검증된다.
static func decide(event: InputEvent, mode: int) -> int:
	if not (event is InputEventKey):
		return STAY
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return STAY
	var full := _is_fullscreen(mode)
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		return GO_WINDOWED if full else GO_FULLSCREEN
	# ESC는 **빠져나오기만 한다.** 창 모드에서 누르면 아무 일도 없어야 한다.
	if key.keycode == KEY_ESCAPE and full:
		return GO_WINDOWED
	return STAY


static func _is_fullscreen(mode: int) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
