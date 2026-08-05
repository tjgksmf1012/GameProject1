class_name SfxBank
extends RefCounted

## 효과음을 코드로 만든다. 오디오 파일이 하나도 없다.
##
## `CLAUDE.md`가 오디오만 외부 에셋을 허용하지만, UI 효과음은 절차 생성이 우선이다
## (04-functional-spec F-08). 라이선스 관리 비용이 0이고, 긴장도에 따라 음정을 바꿀 수 있다.
##
## 순수 로직이라 헤드리스로 검증 가능하다 — 소리를 들을 수 없어도 파형이 맞는지는 볼 수 있다.

const SAMPLE_RATE := 22050
const MAX_AMPLITUDE := 32767.0


## 버튼 클릭. 짧고 건조한 딸깍.
static func click() -> AudioStreamWAV:
	return tone(880.0, 0.045, 90.0, 0.15, true, 0.35)


## 바코드 스캔. 편의점에서 나는 그 소리.
static func scan() -> AudioStreamWAV:
	return tone(1760.0, 0.09, 28.0, 0.0, false, 0.30)


## 정상 응대. 낮고 짧게, 안심시키지 않는다.
static func correct() -> AudioStreamWAV:
	return tone(392.0, 0.16, 14.0, 0.0, false, 0.28)


## 오판. 거칠고 낮게.
static func wrong() -> AudioStreamWAV:
	return tone(87.0, 0.55, 5.0, 0.35, true, 0.42)


## 클립보드에 종이가 끼워지는 소리.
static func paper() -> AudioStreamWAV:
	return tone(240.0, 0.13, 30.0, 0.85, false, 0.22)


## 사망. 낮고 길게. 정적 다음에 와야 효과가 있다.
static func death() -> AudioStreamWAV:
	return _mix(tone(41.0, 1.9, 1.1, 0.20, false, 0.55),
		tone(62.0, 1.5, 1.6, 0.35, true, 0.28))


## 편의점 문 종소리. 두 음이 겹쳐야 종처럼 들린다.
static func door_bell() -> AudioStreamWAV:
	return _mix(tone(2093.0, 0.5, 7.0, 0.0, false, 0.20),
		tone(2637.0, 0.42, 9.0, 0.0, false, 0.14))


## 두 파형을 겹친다. 짧은 쪽은 끝나면 무음으로 둔다.
static func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var data := a.data
	var other := b.data
	for i in range(0, mini(data.size(), other.size()), 2):
		var sum := data.decode_s16(i) + other.decode_s16(i)
		data.encode_s16(i, clampi(sum, -32768, 32767))
	a.data = data
	return a


## 단일 톤 생성. `square`면 사각파, 아니면 사인파. `noise`만큼 잡음을 섞는다.
static func tone(
	frequency: float,
	seconds: float,
	decay: float,
	noise: float,
	square: bool,
	amplitude: float
) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := exp(-decay * t)
		var wave := _wave(frequency, t, square)
		var mixed := wave * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var value := clampf(mixed * envelope * amplitude, -1.0, 1.0)
		data.encode_s16(i * 2, int(value * MAX_AMPLITUDE))
	return _wrap(data)


static func _wave(frequency: float, t: float, square: bool) -> float:
	if square:
		return 1.0 if fposmod(t * frequency, 1.0) < 0.5 else -1.0
	return sin(TAU * frequency * t)


static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
