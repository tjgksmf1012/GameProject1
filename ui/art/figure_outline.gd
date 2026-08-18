extends RefCounted

## 카운터에 붙어 선 손님의 상반신 윤곽.
##
## 작은 전신을 좁은 칸에 구겨 넣으면 머리는 점, 다리는 막대기로 읽힌다. 이 화면에서 필요한
## 것은 전신 비율 증명이 아니라 문을 열고 들어온 낯선 사람의 **질량과 자세**다. 그래서
## 계산대 아래는 과감히 버리고, 머리·어깨·소매·손이 화면을 채우도록 좌표계를 다시 만들었다.

const DESIGN_HEIGHT := 176.0
const HEAD_CENTER_Y := 30.0
const NECK_Y := 49.0
const SHOULDER_Y := 63.0
const ELBOW_Y := 106.0
const COUNTER_Y := 143.0
const BASE_Y := 176.0
const SMOOTH_STEPS := 5


## 목에서 소매를 지나 계산대 아래까지 이어지는 단일 코트 덩어리.
static func silhouette(shoulder: float, waist: float, lean: float) -> PackedVector2Array:
	var left := _smooth(_side(-1.0, shoulder, waist, lean))
	var right := _smooth(_side(1.0, shoulder, waist, lean))
	var out := PackedVector2Array()
	for point in left:
		out.append(point)
	for i in range(right.size() - 1, -1, -1):
		out.append(right[i])
	return out


static func _side(
	side: float, shoulder: float, waist: float, lean: float
) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(side * 7.0 + lean * 0.92, NECK_Y - 2.0),
		Vector2(side * 15.0 + lean * 0.82, NECK_Y + 7.0),
		Vector2(side * shoulder * 0.62 + lean * 0.68, SHOULDER_Y - 4.0),
		Vector2(side * shoulder + lean * 0.52, SHOULDER_Y + 2.0),
		Vector2(side * (shoulder + 3.0) + lean * 0.34, SHOULDER_Y + 22.0),
		Vector2(side * (shoulder + 5.0) + lean * 0.18, ELBOW_Y),
		Vector2(side * shoulder * 0.84, COUNTER_Y - 15.0),
		Vector2(side * shoulder * 0.58, COUNTER_Y + 2.0),
		Vector2(side * waist, COUNTER_Y + 13.0),
		Vector2(side * waist * 1.04, BASE_Y),
	])


## 완전한 원 대신 정수리·관자·턱이 구분되는 얼굴 없는 머리 덩어리.
static func head(radius: float, lean: float, facing: float) -> PackedVector2Array:
	var center := Vector2(lean * 0.95, HEAD_CENTER_Y)
	var shape := PackedVector2Array([
		Vector2(-0.52, -0.95), Vector2(-0.86, -0.62), Vector2(-0.94, 0.05),
		Vector2(-0.72, 0.68), Vector2(-0.34, 1.02), Vector2(0.18, 0.99),
		Vector2(0.55, 0.68), Vector2(0.67, 0.34), Vector2(1.10, 0.12),
		Vector2(0.76, -0.08), Vector2(0.78, -0.54), Vector2(0.50, -0.88),
		Vector2(0.0, -1.02),
	])
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + Vector2(point.x * radius * facing, point.y * radius))
	return _closed_smooth(points)


static func neck(radius: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-radius * 0.34 + lean * 0.90, HEAD_CENTER_Y + radius * 0.62),
		Vector2(radius * 0.38 + lean * 0.90, HEAD_CENTER_Y + radius * 0.62),
		Vector2(7.0 + lean * 0.84, NECK_Y + 7.0),
		Vector2(-7.0 + lean * 0.84, NECK_Y + 7.0),
	])


static func head_rim(radius: float, lean: float, facing: float) -> PackedVector2Array:
	var center := Vector2(lean * 0.95, HEAD_CENTER_Y)
	return PackedVector2Array([
		center + Vector2(-0.48 * radius * facing, -0.92 * radius),
		center + Vector2(-0.82 * radius * facing, -0.58 * radius),
		center + Vector2(-0.90 * radius * facing, 0.06 * radius),
		center + Vector2(-0.68 * radius * facing, 0.60 * radius),
	])


## 얼굴을 가린 두건. 머리보다 크게 감싸며 어깨 쪽으로 자연스럽게 닫힌다.
static func hood(radius: float, lean: float) -> PackedVector2Array:
	var center := Vector2(lean * 0.95, HEAD_CENTER_Y)
	return _closed_smooth(PackedVector2Array([
		center + Vector2(-radius * 1.15, radius * 0.75),
		center + Vector2(-radius * 1.08, -radius * 0.50),
		center + Vector2(-radius * 0.42, -radius * 1.12),
		center + Vector2(0.0, -radius * 1.34),
		center + Vector2(radius * 0.42, -radius * 1.12),
		center + Vector2(radius * 1.08, -radius * 0.50),
		center + Vector2(radius * 1.15, radius * 0.75),
		center + Vector2(radius * 0.62, radius * 1.16),
		center + Vector2(-radius * 0.62, radius * 1.16),
	]))


## 몸 뒤에 붙는 숄더백. 화면 밖으로 잘리더라도 몸과 한 덩어리로 읽혀야 한다.
static func bag(shoulder: float, lean: float) -> PackedVector2Array:
	return _closed_smooth(PackedVector2Array([
		Vector2(-shoulder * 0.82 + lean, SHOULDER_Y + 3.0),
		Vector2(-shoulder * 1.36 + lean * 0.45, SHOULDER_Y + 14.0),
		Vector2(-shoulder * 1.49, ELBOW_Y + 5.0),
		Vector2(-shoulder * 1.34, COUNTER_Y + 5.0),
		Vector2(-shoulder * 0.84, COUNTER_Y + 7.0),
	]))


static func strap(shoulder: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(shoulder * 0.45 + lean * 0.65, SHOULDER_Y - 1.0),
		Vector2(-shoulder * 0.86, COUNTER_Y + 2.0),
	])


## 상품은 손과 계산대가 만나는 곳에 놓인다. 공중에 뜨거나 가슴에 박히지 않는다.
static func hand_point(shoulder: float) -> Vector2:
	return Vector2(shoulder * 0.42, COUNTER_Y - 3.0)


static func sleeve_seam(side: float, shoulder: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(side * shoulder * 0.76 + lean * 0.55, SHOULDER_Y + 5.0),
		Vector2(side * (shoulder + 1.0), ELBOW_Y - 2.0),
		Vector2(side * shoulder * 0.58, COUNTER_Y - 10.0),
		Vector2(side * shoulder * 0.30, COUNTER_Y - 3.0),
	])


## 형광등이 닿는 머리와 한쪽 어깨만 돌려준다. 전신을 밝게 두르지 않는다.
static func shoulder_rim(shoulder: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-15.0 + lean * 0.82, NECK_Y + 7.0),
		Vector2(-shoulder * 0.64 + lean * 0.68, SHOULDER_Y - 4.0),
		Vector2(-shoulder + lean * 0.52, SHOULDER_Y + 2.0),
		Vector2(-shoulder - 4.0 + lean * 0.34, SHOULDER_Y + 20.0),
	])


## 코트 안쪽의 넓은 냉광 면. 선이 아니라 면으로 체적을 보여준다.
static func light_plane(shoulder: float, lean: float) -> PackedVector2Array:
	return _closed_smooth(PackedVector2Array([
		Vector2(-9.0 + lean * 0.82, NECK_Y + 8.0),
		Vector2(-shoulder * 0.58 + lean * 0.65, SHOULDER_Y),
		Vector2(-shoulder * 0.86 + lean * 0.46, SHOULDER_Y + 15.0),
		Vector2(-shoulder * 0.88 + lean * 0.22, ELBOW_Y - 5.0),
		Vector2(-shoulder * 0.58, COUNTER_Y - 13.0),
		Vector2(-shoulder * 0.18, COUNTER_Y - 4.0),
		Vector2(2.0 + lean * 0.18, COUNTER_Y - 4.0),
		Vector2(1.0 + lean * 0.70, SHOULDER_Y + 12.0),
	]))


static func face_plane(radius: float, lean: float, facing: float) -> PackedVector2Array:
	var center := Vector2(lean * 0.95, HEAD_CENTER_Y)
	return _closed_smooth(PackedVector2Array([
		center + Vector2(-0.48 * radius * facing, -0.74 * radius),
		center + Vector2(-0.72 * radius * facing, -0.25 * radius),
		center + Vector2(-0.58 * radius * facing, 0.48 * radius),
		center + Vector2(-0.25 * radius * facing, 0.78 * radius),
		center + Vector2(0.08 * radius * facing, 0.68 * radius),
		center + Vector2(0.02 * radius * facing, -0.60 * radius),
	]))


static func _closed_smooth(points: PackedVector2Array) -> PackedVector2Array:
	var loop := PackedVector2Array(points)
	loop.append(points[0])
	return _smooth(loop)


static func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return points
	for i in points.size() - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for step in SMOOTH_STEPS:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(step) / float(SMOOTH_STEPS)))
	out.append(points[points.size() - 1])
	return out
