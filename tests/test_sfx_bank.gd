extends RefCounted

## 절차 생성 효과음. 소리를 들을 수 없어도 파형이 맞는지는 볼 수 있다.
## 오디오 파일이 저장소에 하나도 없다는 사실을 지키는 테스트이기도 하다.

const SOUND_MAKERS := [
	"click", "scan", "correct", "wrong", "paper",
	"counter_tap", "pen_stroke", "door_bell", "death", "shift_end", "tear",
]


func run(r: RefCounted) -> void:
	r.suite("sfx_bank")
	_test_all_sounds_generate(r)
	_test_format(r)
	_test_length_matches_duration(r)
	_test_not_silent(r)
	_test_ambience_loops_seamlessly(r)
	_test_no_sound_escapes_the_list(r)


func _all() -> Array[AudioStreamWAV]:
	# **뱅크에 있는 소리는 전부 여기 들어와야 한다.** 빠진 소리는 무음이어도 아무도 모른다 —
	# 나는 소리를 들을 수 없으므로 이 목록이 유일한 방어선이다.
	return [
		SfxBank.click(), SfxBank.scan(), SfxBank.correct(), SfxBank.wrong(),
		SfxBank.paper(), SfxBank.counter_tap(), SfxBank.pen_stroke(),
		SfxBank.door_bell(), SfxBank.death(), SfxBank.shift_end(), SfxBank.tear(),
	]


func _test_all_sounds_generate(r: RefCounted) -> void:
	var streams := _all()
	r.equals(streams.size(), SOUND_MAKERS.size(), "효과음이 전부 생성된다")
	for stream in streams:
		r.check(stream != null, "스트림이 null이 아니다")


func _test_format(r: RefCounted) -> void:
	for stream in _all():
		r.equals(stream.format, AudioStreamWAV.FORMAT_16_BITS, "16비트 PCM")
		r.equals(stream.mix_rate, SfxBank.SAMPLE_RATE, "샘플레이트가 일치한다")
		r.equals(stream.stereo, false, "모노")


func _test_length_matches_duration(r: RefCounted) -> void:
	var seconds := 0.25
	var stream := SfxBank.tone(440.0, seconds, 10.0, 0.0, false, 0.5)
	var expected_bytes := int(SfxBank.SAMPLE_RATE * seconds) * 2
	r.equals(stream.data.size(), expected_bytes, "길이가 지정한 초와 맞는다")


## 엔벨로프가 잘못되면 전부 0이 나온다. 무음은 소리가 아니다.
func _test_not_silent(r: RefCounted) -> void:
	for stream in _all():
		var peak := 0
		var data := stream.data
		for i in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		r.check(peak > 1000, "파형에 실제 진폭이 있다 (peak=%d)" % peak)


## 환경음은 루프다. 이음매에서 딸깍 소리가 나면 몰입이 즉시 깨진다.
func _test_ambience_loops_seamlessly(r: RefCounted) -> void:
	for stream in [AmbienceBank.fridge(), AmbienceBank.fluorescent(), AmbienceBank.rain()]:
		r.equals(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "루프로 설정된다")
		r.equals(stream.loop_begin, 0, "루프가 처음부터 시작한다")
		r.equals(stream.loop_end, stream.data.size() / 2, "루프 끝이 버퍼 끝과 일치한다")

	# 정수 배음이면 끝과 처음의 위상이 맞는다. 어긋나면 루프에서 딸깍 소리가 난다.
	var hum := AmbienceBank.fridge().data
	var first := hum.decode_s16(0)
	var last := hum.decode_s16(hum.size() - 2)
	r.check(absi(first - last) < 3000,
		"루프 이음매의 진폭 차가 작다 (처음 %d, 끝 %d)" % [first, last])


## **목록이 방어선이면 목록 자체를 지켜야 한다.**
##
## 위 검사들은 전부 `SOUND_MAKERS` 를 기준으로 돈다. 그래서 뱅크에 소리를 하나 더
## 만들어놓고 목록에 안 넣으면 **그 소리는 아무 검사도 안 받는다** — 무음이어도,
## 형식이 틀려도 통과한다. 나는 소리를 들을 수 없으므로 그걸 알아챌 방법이 없다.
## 실제로 `shift_end` 를 추가하면서 이 구멍을 지나갈 뻔했다.
##
## 그래서 소스를 읽어 인자 없이 AudioStreamWAV 를 돌려주는 함수를 전부 찾아 대조한다.
func _test_no_sound_escapes_the_list(r: RefCounted) -> void:
	var source := FileAccess.get_file_as_string("res://systems/audio/sfx_bank.gd")
	r.check(source != "", "sfx_bank.gd 를 읽을 수 있다")
	for line in source.split("\n"):
		if not line.begins_with("static func ") or not line.ends_with("() -> AudioStreamWAV:"):
			continue
		var name := line.substr("static func ".length())
		name = name.substr(0, name.find("("))
		if name.begins_with("_"):
			continue
		r.check(SOUND_MAKERS.has(name),
			"SfxBank.%s() 가 검사 목록에 없다 — 무음이어도 아무도 모른다" % name)
