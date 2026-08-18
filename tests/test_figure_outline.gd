extends RefCounted

## 좁은 손님 패널에서 사람이 **질량과 자세**로 읽히는가.
## 전신 등신대 검사는 폐기했다. 이 구도에서는 다리를 줄여 넣는 순간 다시 막대기 그림이 된다.

const Outline := preload("res://ui/art/figure_outline.gd")

const SHOULDER := 38.0
const WAIST := 32.0
const HEAD_RADIUS := 14.0


func run(r: RefCounted) -> void:
	r.suite("figure_outline")
	_test_upper_body_fills_the_frame(r)
	_test_head_and_shoulders_read_at_small_size(r)
	_test_coat_is_one_continuous_mass(r)
	_test_hands_reach_the_counter(r)
	_test_bag_touches_the_body(r)


## 화면 아래 19%는 계산대가 가린다. 다리를 축소해 남겨두지 않는다.
func _test_upper_body_fills_the_frame(r: RefCounted) -> void:
	var counter_ratio: float = Outline.COUNTER_Y / Outline.DESIGN_HEIGHT
	r.check(counter_ratio > 0.76 and counter_ratio < 0.84,
		"계산대가 화면의 %.0f%%에 있다 — 상반신이 화면 대부분을 차지한다" % [counter_ratio * 100.0])
	var source := FileAccess.get_file_as_string("res://ui/art/figure_outline.gd")
	r.check(not source.contains("func leg(") and not source.contains("FOOT_Y"),
		"축소한 다리 도형이 완전히 제거되었다")


## 머리가 점처럼 작지 않고, 어깨는 옷걸이 선이 아니라 큰 덩어리여야 한다.
func _test_head_and_shoulders_read_at_small_size(r: RefCounted) -> void:
	var head_width := HEAD_RADIUS * 2.0
	var shoulder_width := SHOULDER * 2.0
	var ratio := head_width / shoulder_width
	r.check(ratio > 0.30 and ratio < 0.46,
		"머리/어깨 너비가 %.0f%%다 — 작은 화면에서도 둘 다 읽힌다" % [ratio * 100.0])
	var torso_depth: float = Outline.COUNTER_Y - Outline.SHOULDER_Y
	r.check(torso_depth > head_width * 2.5,
		"어깨 아래 코트 깊이 %.0f가 머리 너비 %.0f보다 충분히 크다" % [torso_depth, head_width])


## 목·어깨·팔·몸통은 하나의 외곽이다. 작은 도형을 이어 붙인 이음매가 없어야 한다.
func _test_coat_is_one_continuous_mass(r: RefCounted) -> void:
	var points := Outline.silhouette(SHOULDER, WAIST, 0.0)
	r.check(points.size() >= 90, "코트 윤곽 점이 %d개라 곡선이 충분하다" % points.size())
	r.check(points[0].distance_to(points[points.size() - 1]) < HEAD_RADIUS * 1.2,
		"목 양끝 간격 %.1f를 한 번에 닫을 수 있다" % points[0].distance_to(points[points.size() - 1]))
	var widest := 0.0
	for point in points:
		widest = maxf(widest, absf(point.x))
	r.check(widest >= SHOULDER,
		"소매까지 포함한 상반신 반폭 %.1f가 어깨 %.1f 이상이다" % [widest, SHOULDER])


## 상품과 손이 같은 계산대 접점에 있어 공중에 뜨지 않는다.
func _test_hands_reach_the_counter(r: RefCounted) -> void:
	var hand := Outline.hand_point(SHOULDER)
	r.check(absf(hand.y - Outline.COUNTER_Y) <= 4.0,
		"손과 계산대 높이 차가 %.1fpx다" % absf(hand.y - Outline.COUNTER_Y))
	r.check(absf(hand.x) < SHOULDER * 0.60,
		"손 x=%.1f가 몸 중심 가까이에 있어 물건을 받친다" % hand.x)


func _test_bag_touches_the_body(r: RefCounted) -> void:
	var bag_right := -999.0
	for point in Outline.bag(SHOULDER, 0.0):
		bag_right = maxf(bag_right, point.x)
	var body_left := 0.0
	for point in Outline.silhouette(SHOULDER, WAIST, 0.0):
		if absf(point.y - (Outline.SHOULDER_Y + 10.0)) < 8.0:
			body_left = minf(body_left, point.x)
	r.check(bag_right >= body_left,
		"가방 안쪽 %.1f가 몸 바깥 %.1f에 닿는다" % [bag_right, body_left])
