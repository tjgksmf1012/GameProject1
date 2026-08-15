extends RefCounted

## 사람 하나의 **윤곽**. 그리지 않고 점만 만든다 — 노드가 없으므로 헤드리스로 검사된다.
##
## 처음 판은 몸통 62 · 다리 43이었다. **다리가 몸통보다 짧았다.** 사람은 반대다.
## 그래서 색을 아무리 고쳐도 어린이 그림으로 보였다 — 문제는 명도가 아니라 비율이었다.
##
## 기준은 7~7.5등신이다. 150 높이에서:
##   머리 지름 21 · 어깨 33 · 허리 62 · **골반 76(정확히 절반)** · 코트 자락 88 · 발 148
## 골반이 키의 한가운데 온다는 것 하나만 지켜도 사람으로 보인다.
##
## 그리고 **도형 다섯 개를 따로 그리면 이음매가 보인다.** 목·어깨·팔·몸통은 끊기지 않는
## 한 윤곽이어야 한다. 여기서 만드는 것이 그 한 줄이다.

const DESIGN_HEIGHT := 150.0

const HEAD_CENTER_Y := 13.0
const NECK_Y := 21.0
const SHOULDER_Y := 33.0
const WAIST_Y := 62.0
const HIP_Y := 76.0
const HEM_Y := 88.0
const FOOT_Y := 148.0
## 손목. 골반보다 살짝 아래에 온다 — 팔을 늘어뜨리면 실제로 그 자리다.
const WRIST_Y := 78.0

## 굽은 어깨를 만드는 세분 횟수. 각진 어깨는 마네킹으로 읽힌다.
const SMOOTH_STEPS := 5


## 머리부터 자락까지 한 바퀴. 오른쪽 절반을 만들고 뒤집어 붙인다.
static func silhouette(shoulder: float, waist: float) -> PackedVector2Array:
	var half := _smooth(_half(shoulder, waist))
	var out := PackedVector2Array()
	for p in half:
		out.append(p)
	for i in range(half.size() - 1, -1, -1):
		out.append(Vector2(-half[i].x, half[i].y))
	return out


## 어깨가 가장 넓고, 아래로 아주 조금 좁아지다 자락에서 다시 벌어진다.
## 팔은 몸에 붙여 **윤곽 안으로 넣는다** — 따로 그리면 옷걸이가 된다.
static func _half(shoulder: float, waist: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(4.6, NECK_Y - 3.0),
		Vector2(shoulder * 0.42, NECK_Y + 5.0),
		Vector2(shoulder, SHOULDER_Y),
		Vector2(shoulder * 0.99, SHOULDER_Y + 13.0),
		Vector2(shoulder * 0.95, WAIST_Y),
		Vector2(shoulder * 0.93, WRIST_Y),
		Vector2(shoulder * 0.97, HEM_Y),
		Vector2(waist * 0.50, HEM_Y + 2.5),
	])


## 다리 하나. `side`는 -1 또는 1. 자락 위에서 시작해 코트에 가려지게 한다.
static func leg(side: float, waist: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(side * 2.0, HEM_Y - 6.0),
		Vector2(side * waist * 0.85, HEM_Y - 6.0),
		Vector2(side * waist * 0.70, FOOT_Y),
		Vector2(side * 4.2, FOOT_Y),
	])


## 어깨에 **붙은** 가방. 몸 옆에 띄우면 가방이 아니라 정체불명의 도형이 된다.
static func bag(shoulder: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-shoulder * 0.88, SHOULDER_Y + 7.0),
		Vector2(-shoulder * 1.30, SHOULDER_Y + 14.0),
		Vector2(-shoulder * 1.36, WAIST_Y + 6.0),
		Vector2(-shoulder * 1.08, WRIST_Y - 1.0),
		Vector2(-shoulder * 0.86, WAIST_Y + 9.0),
	])


## 어깨를 가로지르는 끈. **몸통 뒤에 그리면 안 보인다.**
static func strap(shoulder: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(shoulder * 0.34, SHOULDER_Y + 1.0),
		Vector2(-shoulder * 1.02, WAIST_Y + 2.0),
	])


## 손이 오는 자리. 품목 아이콘이 여기 놓인다.
## **한 값을 두 곳이 각자 들면 어긋난다** — 예전에 물건이 가슴에 박혀 있었다.
static func hand_point(shoulder: float) -> Vector2:
	return Vector2(shoulder * 0.86, WRIST_Y + 2.0)


## 얼굴을 가린 머리. 두건은 정수리가 뾰족하고 턱 쪽이 넓다.
static func hood(radius: float) -> PackedVector2Array:
	var center := Vector2(0.0, HEAD_CENTER_Y)
	return _smooth(PackedVector2Array([
		center + Vector2(-radius - 2.0, radius * 0.62),
		center + Vector2(-radius - 1.0, -radius * 0.55),
		center + Vector2(0.0, -radius - 3.0),
		center + Vector2(radius + 1.0, -radius * 0.55),
		center + Vector2(radius + 2.0, radius * 0.62),
		center + Vector2(radius * 0.72, radius * 1.25),
		center + Vector2(-radius * 0.72, radius * 1.25),
		center + Vector2(-radius - 2.0, radius * 0.62),
	]))


## 캣멀롬으로 점 사이를 메운다. 끝점은 자기 자신을 물려 밖으로 튀지 않게 한다.
static func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	if n < 2:
		return points
	for i in n - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, n - 1)]
		for step in SMOOTH_STEPS:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(step) / float(SMOOTH_STEPS)))
	out.append(points[n - 1])
	return out
