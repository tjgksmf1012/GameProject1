extends RefCounted

## 절차 생성 효과음. 소리를 들을 수 없어도 파형이 맞는지는 볼 수 있다.
## 오디오 파일이 저장소에 하나도 없다는 사실을 지키는 테스트이기도 하다.

const SOUND_MAKERS := ["click", "scan", "correct", "wrong", "paper"]


func run(r: RefCounted) -> void:
	r.suite("sfx_bank")
	_test_all_sounds_generate(r)
	_test_format(r)
	_test_length_matches_duration(r)
	_test_not_silent(r)


func _all() -> Array[AudioStreamWAV]:
	return [SfxBank.click(), SfxBank.scan(), SfxBank.correct(), SfxBank.wrong(), SfxBank.paper()]


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
