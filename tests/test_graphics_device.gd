extends RefCounted

const Palette := preload("res://ui/theme_factory.gd")

const SIGNAL_PATH := "res://shaders/grain.gdshader"
const CUSTOMER_PATH := "res://ui/art/customer_figure.gd"
const PRODUCT_PATH := "res://ui/art/product_glyph.gd"


func run(r: RefCounted) -> void:
	r.suite("graphics_device")
	_test_global_dither(r)
	_test_temporal_caps(r)
	_test_outlines(r)
	_test_tactile_feedback(r)


func _test_global_dither(r: RefCounted) -> void:
	var source := FileAccess.get_file_as_string(SIGNAL_PATH)
	var graphics: Dictionary = GameData.load_balance().get("graphics", {})
	var levels := float(graphics.get("dither_levels", 0.0))
	r.check(levels >= 6.0 and levels <= 8.0, "전역 디더 단계가 6~8 사이이다")
	r.check(source.contains("bayer4(FRAGCOORD.xy)"), "디더가 화면 픽셀 격자에 고정된다")
	r.check(source.contains("palette_light = vec4(0.39, 0.59, 0.79, 0.84)"),
		"종이 단서를 나누는 0.79·0.84 밝기 단계가 있다")
	r.check(source.contains("quantize_luma"), "화면 전체를 제한 휘도 팔레트로 양자화한다")


func _test_temporal_caps(r: RefCounted) -> void:
	var source := FileAccess.get_file_as_string(SIGNAL_PATH)
	var graphics: Dictionary = GameData.load_balance().get("graphics", {})
	r.check(float(graphics.get("chromatic_peak_px", 99.0)) <= 1.5, "색 번짐 상한이 1.5px 이하이다")
	r.check(float(graphics.get("ghost_peak", 99.0)) <= 0.15, "인광 잔상 혼합이 15% 이하이다")
	r.check(float(graphics.get("jitter_peak_px", 99.0)) <= 1.2, "간헐 지터 상한이 1.2px 이하이다")
	r.check(float(graphics.get("interlace_peak_px", 99.0)) <= 0.6, "인터레이스 떨림이 0.6px 이하이다")
	for parameter in ["ghost_strength", "jitter_pixels", "interlace_pixels", "tension"]:
		r.check(source.contains("uniform float %s" % parameter), "%s를 외부에서 조절한다" % parameter)
	r.check(source.contains("safe_signal"), "종이 위 시간축 결함을 별도 감쇠한다")


func _test_outlines(r: RefCounted) -> void:
	var customer := FileAccess.get_file_as_string(CUSTOMER_PATH)
	var product := FileAccess.get_file_as_string(PRODUCT_PATH)
	r.check(customer.contains("const OUTLINE_WIDTH := 2.4"), "손님 외곽 키라인이 2px 이상이다")
	r.check(product.contains("const OUTLINE_WIDTH := 2.2"), "상품 외곽선이 2px 이상이다")
	var keyline := Color("090c0d")
	var backlight := Color("59686b")
	r.check(_luminance(keyline) < _luminance(Palette.BG), "전신 키라인은 배경보다 어둡다")
	r.check(_luminance(backlight) > _luminance(Palette.BG), "선택적 역광만 배경보다 밝다")
	r.check(customer.contains("KEYLINE, OUTLINE_WIDTH"), "코트 외곽은 어두운 키라인을 사용한다")
	r.check(customer.contains("BACKLIGHT, RIM_WIDTH"), "밝은 윤곽은 머리·어깨 일부에만 쓴다")


func _test_tactile_feedback(r: RefCounted) -> void:
	var strike := FileAccess.get_file_as_string("res://ui/clipboard/strike_mark.gd")
	var receipt := FileAccess.get_file_as_string("res://ui/pos/receipt_slip.gd")
	var juice := FileAccess.get_file_as_string("res://ui/juice.gd")
	r.check(strike.contains("PRESS_WIDTH") and strike.contains("_pressure_recoil"),
		"취소선에 펜 압력과 반동이 있다")
	r.check(receipt.contains("RESIST_PIXELS") and receipt.contains("_recoil_edge"),
		"영수증 톱니가 걸렸다 놓이는 저항이 있다")
	r.check(juice.contains("static func rebound"), "스캔 버튼에 압축·과회복 반동이 있다")


static func _luminance(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
