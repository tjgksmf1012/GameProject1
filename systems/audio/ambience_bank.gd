class_name AmbienceBank
extends RefCounted

## 환경음. 냉장고 웅웅거림, 형광등, 빗소리 — 전부 코드로 만든다 (F-08).
##
## **이음매 없는 루프를 만드는 법**: 버퍼 길이에 딱 떨어지는 정수 개의 사이클만 쓴다.
## 그러면 끝과 처음의 위상이 일치해서 루프 지점에 딸깍 소리가 안 난다.
## 잡음 기반(빗소리)은 위상을 맞출 수 없으므로 꼬리를 머리에 크로스페이드한다.

const SAMPLE_RATE := 22050
const MAX_AMPLITUDE := 32767.0
const CROSSFADE_RATIO := 0.08


## 냉장고. 낮은 웅웅거림에 아주 느린 맥놀이가 섞인다.
static func fridge() -> AudioStreamWAV:
	return harmonics(4.0, [
		{"cycles": 240, "gain": 1.0},
		{"cycles": 242, "gain": 0.55},
		{"cycles": 480, "gain": 0.18},
		{"cycles": 121, "gain": 0.22},
	], 0.16)


## 형광등. 높고 얇은 잡음. 있는 줄도 모르다가 꺼지면 안다.
static func fluorescent() -> AudioStreamWAV:
	return harmonics(4.0, [
		{"cycles": 480, "gain": 1.0},
		{"cycles": 960, "gain": 0.35},
		{"cycles": 1440, "gain": 0.12},
	], 0.035)


## 비. 잡음이라 위상을 맞출 수 없으므로 크로스페이드로 잇는다.
static func rain() -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * 4.0)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var low := 0.0
	for i in frames:
		# 1차 저역통과. 백색잡음을 그냥 쓰면 쉿 소리라 비처럼 안 들린다.
		low = low * 0.86 + (randf() * 2.0 - 1.0) * 0.14
		samples[i] = low * 0.9
	return _pack(_crossfade(samples), 0.20)


## 정수 배음의 합. 사이클 수가 정수라 루프가 이어진다.
static func harmonics(seconds: float, partials: Array, amplitude: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i in frames:
		var phase := float(i) / float(frames)
		var value := 0.0
		var total := 0.0
		for partial in partials:
			var gain := float((partial as Dictionary).get("gain", 1.0))
			value += sin(TAU * float((partial as Dictionary)["cycles"]) * phase) * gain
			total += gain
		samples[i] = value / maxf(total, 0.001)
	return _pack(samples, amplitude)


## 꼬리를 머리에 겹쳐 이음매를 지운다.
static func _crossfade(samples: PackedFloat32Array) -> PackedFloat32Array:
	var span := int(samples.size() * CROSSFADE_RATIO)
	for i in span:
		var t := float(i) / float(span)
		var tail := samples[samples.size() - span + i]
		samples[i] = samples[i] * t + tail * (1.0 - t)
	samples.resize(samples.size() - span)
	return samples


static func _pack(samples: PackedFloat32Array, amplitude: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * amplitude, -1.0, 1.0) * MAX_AMPLITUDE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream
