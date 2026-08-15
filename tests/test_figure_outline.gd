extends RefCounted

## 손님이 **사람 비율인가.** 색이 아니라 이게 문제였다.
##
## 처음 판은 몸통 62 · 다리 43이었다 — 다리가 몸통보다 짧았다. 그 상태로는 명도를 어떻게
## 만져도 어린이 그림으로 보인다. 눈으로 「좀 이상하네」로 넘어갈 일이라서 숫자로 잰다.
##
## 윤곽이 `Control` 밖에 있는 이유가 이것이다. 그리는 코드 안에 있었으면 이 검사를 못 썼다.

const Outline := preload("res://ui/art/figure_outline.gd")

const SHOULDER := 24.0
const WAIST := 18.0
const HEAD_RADIUS := 10.4


func run(r: RefCounted) -> void:
	r.suite("figure_outline")
	_test_proportions(r)
	_test_shoulders_are_the_widest_part(r)
	_test_the_outline_is_one_closed_symmetric_loop(r)
	_test_the_bag_touches_the_body(r)


## 골반이 키의 한가운데 온다. 이거 하나만 지켜도 사람으로 보인다.
func _test_proportions(r: RefCounted) -> void:
	var height := Outline.DESIGN_HEIGHT
	var hip_ratio := Outline.HIP_Y / height
	r.check(hip_ratio > 0.45 and hip_ratio < 0.56,
		"골반이 키의 %.0f%%에 있다 — 사람은 절반 근처다" % [hip_ratio * 100.0])

	var torso := Outline.HEM_Y - Outline.SHOULDER_Y
	var legs := Outline.FOOT_Y - Outline.HEM_Y
	r.check(legs > torso,
		"다리 %.0f가 몸통 %.0f보다 짧다 — 이 비율이 어린이 그림을 만든다" % [legs, torso])

	var head := HEAD_RADIUS * 2.0
	r.check(head / height > 0.11 and head / height < 0.17,
		"머리가 키의 %.0f%%다 — 7~8등신이면 12~15%%다" % [head / height * 100.0])


## 어깨가 가장 넓어야 한다. 자락이 더 넓으면 사람이 아니라 종이 되고,
## 허리가 더 넓으면 눈사람이 된다.
func _test_shoulders_are_the_widest_part(r: RefCounted) -> void:
	var points := Outline.silhouette(SHOULDER, WAIST)
	var widest := 0.0
	var widest_y := 0.0
	for p in points:
		if absf(p.x) > widest:
			widest = absf(p.x)
			widest_y = p.y
	r.check(absf(widest_y - Outline.SHOULDER_Y) < 14.0,
		"가장 넓은 곳이 y=%.0f다 — 어깨(%.0f) 근처여야 한다" % [widest_y, Outline.SHOULDER_Y])


## 목·어깨·팔·몸통은 **끊기지 않는 한 윤곽**이다. 도형을 따로 그리면 이음매가 보인다.
func _test_the_outline_is_one_closed_symmetric_loop(r: RefCounted) -> void:
	var points := Outline.silhouette(SHOULDER, WAIST)
	r.check(points.size() > 40, "윤곽 점이 %d개뿐이다 — 각져 보인다" % points.size())
	r.check(points[0].distance_to(points[points.size() - 1]) < SHOULDER,
		"윤곽이 닫히지 않는다 — 시작과 끝이 %.1f 떨어져 있다"
			% points[0].distance_to(points[points.size() - 1]))
	# 좌우 대칭. 뒤집어 붙였으므로 i번째와 뒤에서 i번째가 x부호만 달라야 한다.
	var last := points.size() - 1
	for i in points.size() / 2:
		var a: Vector2 = points[i]
		var b: Vector2 = points[last - i]
		r.check(absf(a.x + b.x) < 0.01 and absf(a.y - b.y) < 0.01,
			"윤곽이 좌우 대칭이 아니다 (%d번째: %s vs %s)" % [i, a, b])


## 가방은 몸에 **붙어** 있어야 한다. 옆에 띄우면 가방이 아니라 정체불명의 도형이 된다.
func _test_the_bag_touches_the_body(r: RefCounted) -> void:
	var bag_right := -999.0
	for p in Outline.bag(SHOULDER):
		bag_right = maxf(bag_right, p.x)
	# 가방이 걸리는 높이에서 몸이 어디까지 나와 있는가.
	var body_left := 0.0
	for p in Outline.silhouette(SHOULDER, WAIST):
		if absf(p.y - (Outline.SHOULDER_Y + 10.0)) < 8.0:
			body_left = minf(body_left, p.x)
	r.check(bag_right >= body_left,
		"가방의 안쪽 끝(%.1f)이 몸의 바깥 끝(%.1f)에 못 미친다 — 떨어져 보인다"
			% [bag_right, body_left])
