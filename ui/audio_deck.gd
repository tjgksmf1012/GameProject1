extends Node

## 소리 전부. 효과음과 환경음 플레이어를 만들고 들고 있는다.
##
## 오디오 파일이 하나도 없다 — 파형을 코드로 만든다 (F-08, `systems/audio/`).
## 라이선스 관리 비용이 0이고, 긴장에 따라 소리를 바꿀 수 있다.

const AMBIENCE_SPECS := {
	"fridge": "fridge_db",
	"fluorescent": "fluorescent_db",
	"rain": "rain_db",
}

const DEFAULT_DB := {
	"fridge_db": -24.0,
	"fluorescent_db": -32.0,
	"rain_db": -27.0,
}

var _config: Dictionary = {}
var _sfx: Dictionary = {}
var _ambience: Dictionary = {}


func setup(audio_config: Dictionary) -> void:
	_config = audio_config
	_build_sfx()
	_build_ambience()


func _build_sfx() -> void:
	var makers := {
		"click": SfxBank.click,
		"scan": SfxBank.scan,
		"correct": SfxBank.correct,
		"wrong": SfxBank.wrong,
		"paper": SfxBank.paper,
		"bell": SfxBank.door_bell,
		"tap": SfxBank.counter_tap,
		"pen": SfxBank.pen_stroke,
		"death": SfxBank.death,
	}
	for name in makers:
		_sfx[name] = _make_player((makers[name] as Callable).call(), 0.0, false)


func _build_ambience() -> void:
	var makers := {
		"fridge": AmbienceBank.fridge,
		"fluorescent": AmbienceBank.fluorescent,
		"rain": AmbienceBank.rain,
	}
	for name in makers:
		var key: String = AMBIENCE_SPECS[name]
		var volume := float(_config.get(key, DEFAULT_DB[key]))
		_ambience[name] = _make_player((makers[name] as Callable).call(), volume, true)


func _make_player(stream: AudioStream, volume_db: float, autostart: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	if autostart:
		player.play()
	return player


func play(name: String) -> void:
	var player: AudioStreamPlayer = _sfx.get(name)
	if player != null:
		player.play()


## 긴장이 오르면 냉장고 소리가 커진다. 조용한 게임에서 소리는 압박의 일부다.
func set_tension(tension: float) -> void:
	var player: AudioStreamPlayer = _ambience.get("fridge")
	if player == null:
		return
	player.volume_db = float(_config.get("fridge_db", DEFAULT_DB["fridge_db"])) \
		+ tension * float(_config.get("fridge_tension_boost_db", 7.0))


## 사망 연출은 정적으로 시작한다. 굉음보다 소리가 사라지는 게 무섭다.
func silence_ambience() -> void:
	for name in _ambience:
		(_ambience[name] as AudioStreamPlayer).stop()


## **끈 것은 누군가 다시 켜야 한다.**
##
## 사망 연출이 환경음을 끄고 아무도 안 켰다. 밤을 실패하고 「다시 시작」을 누르면
## 냉장고도 형광등도 빗소리도 없는 채로 그 밤을 통째로 다시 했고, 밤 화면에서
## 제목으로 나가는 길이 없어 게임을 껐다 켜기 전에는 소리가 영영 안 돌아왔다.
## **못 하는 플레이어일수록 오래 무음으로 논다** — 정확히 거꾸로다.
func resume_ambience() -> void:
	for name in _ambience:
		var player := _ambience[name] as AudioStreamPlayer
		if not player.playing:
			player.play()
