extends RefCounted

const Palette := preload("res://ui/theme_factory.gd")

const SIGNAL_PATH := "res://shaders/grain.gdshader"
const CUSTOMER_PATH := "res://ui/art/customer_figure.gd"
const PRODUCT_PATH := "res://ui/art/product_glyph.gd"


func run(r: RefCounted) -> void:
	r.suite("graphics_device")
	_test_global_dither(r)
	_test_temporal_caps(r)
	_test_character_art(r)
	_test_tactile_feedback(r)
	_test_workstation_staging(r)


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


func _test_character_art(r: RefCounted) -> void:
	var customer := FileAccess.get_file_as_string(CUSTOMER_PATH)
	var product := FileAccess.get_file_as_string(PRODUCT_PATH)
	r.check(product.contains("const OUTLINE_WIDTH := 2.2"), "상품 외곽선이 2px 이상이다")
	r.check(customer.contains("TextureRect.STRETCH_KEEP_ASPECT_COVERED"),
		"손님 원화가 패널을 비율 유지해 채운다")
	r.check(customer.contains("OPEN_PORTRAITS") and customer.contains("BAG_PORTRAITS"),
		"얼굴 공개·가방 공개 상태마다 복수 원화를 가진다")
	r.check(not customer.contains("draw_colored_polygon"),
		"초등 도형처럼 보이던 절차형 인물 렌더를 폐기했다")


func _test_tactile_feedback(r: RefCounted) -> void:
	var strike := FileAccess.get_file_as_string("res://ui/clipboard/strike_mark.gd")
	var receipt := FileAccess.get_file_as_string("res://ui/pos/receipt_slip.gd")
	var juice := FileAccess.get_file_as_string("res://ui/juice.gd")
	r.check(strike.contains("PRESS_WIDTH") and strike.contains("_pressure_recoil"),
		"취소선에 펜 압력과 반동이 있다")
	r.check(receipt.contains("RESIST_PIXELS") and receipt.contains("_recoil_edge"),
		"영수증 톱니가 걸렸다 놓이는 저항이 있다")
	r.check(juice.contains("static func rebound"), "스캔 버튼에 압축·과회복 반동이 있다")


func _test_workstation_staging(r: RefCounted) -> void:
	var night := FileAccess.get_file_as_string("res://ui/night_view.gd")
	var customer := FileAccess.get_file_as_string("res://ui/customer_view.gd")
	var pos := FileAccess.get_file_as_string("res://ui/pos/pos_terminal.gd")
	var cctv := FileAccess.get_file_as_string("res://ui/cctv/cctv_channel.gd")
	var title := FileAccess.get_file_as_string("res://ui/title_view.gd")
	r.check(night.contains("WorkstationFrame"), "네 기능이 하나의 계산대 프레임에 고정된다")
	r.check(customer.contains("CustomerWindow"), "손님은 비 오는 유리창 장면 안에 선다")
	r.check(pos.contains("RegisterSurface"), "POS가 스캐너·프린터 계산대 표면을 가진다")
	r.check(cctv.contains("CCTV_ATLAS") and cctv.contains("_atlas_region"),
		"CCTV 네 장소가 래스터 아틀라스의 독립 장면이다")
	r.check(cctv.contains("_shadow_shape") and cctv.contains("_figure_shape"),
		"CCTV 판정 단서는 원화가 아니라 테스트 가능한 코드 오버레이다")
	r.check(title.contains("TITLE_ART") and title.contains("TextureRect"),
		"제목 화면이 비 내리는 점포 래스터 원화를 사용한다")
