extends RefCounted

const Palette := preload("res://ui/theme_factory.gd")

const CUSTOMER_SCRIPT := "res://ui/art/customer_figure.gd"
const PRODUCT_SCRIPT := "res://ui/art/product_glyph.gd"
const PERFORMANCE_SHEETS := [
	"res://assets/art/performers/bus-driver.png",
	"res://assets/art/performers/night-florist.png",
	"res://assets/art/performers/lab-technician.png",
	"res://assets/art/performers/night-office-worker.png",
	"res://assets/art/performers/delivery-rider.png",
	"res://assets/art/performers/portrait-retoucher.png",
	"res://assets/art/performers/printmaking-student.png",
	"res://assets/art/performers/amateur-boxer.png",
	"res://assets/art/performers/fish-auctioneer.png",
	"res://assets/art/performers/laundry-collector.png",
]
const BRIGHTNESS_GATE := 0.92


func run(r: RefCounted) -> void:
	r.suite("art_palette")
	_test_product_colors(r)
	_test_performance_roster(r)
	_test_performance_states(r)
	_test_portrait_fairness(r)


func _test_product_colors(r: RefCounted) -> void:
	var paper := _luminance(Palette.PAPER)
	var limit := paper * BRIGHTNESS_GATE
	var colors := _colors_in(PRODUCT_SCRIPT)
	r.check(colors.size() >= 16, "상품 글리프 팔레트를 충분히 검사한다")
	for hex in colors:
		var value := _luminance(Color(str(hex)))
		r.check(value <= limit,
			"상품 글리프 #%s가 종이보다 밝지 않다 (%.0f <= %.0f)" % [
				hex, value * 255.0, limit * 255.0])


func _test_performance_roster(r: RefCounted) -> void:
	for path in PERFORMANCE_SHEETS:
		r.check(FileAccess.file_exists(path), "연기 시트가 있다: %s" % path.get_file())
		var texture := load(path) as Texture2D
		r.check(texture != null, "연기 시트가 Texture2D로 열린다: %s" % path.get_file())
		if texture != null:
			r.check(texture.get_width() >= 1024 and texture.get_height() >= 1024,
				"연기 시트의 두 축이 1024px 이상이다: %s" % path.get_file())
			r.check(texture.get_width() % 2 == 0 and texture.get_height() % 2 == 0,
				"연기 시트를 같은 크기의 2x2 칸으로 나눌 수 있다: %s" % path.get_file())


func _test_performance_states(r: RefCounted) -> void:
	var source := FileAccess.get_file_as_string(CUSTOMER_SCRIPT)
	for state in ["ACT_ARRIVAL", "ACT_SPEAKING", "ACT_URGING", "ACT_DEMANDING"]:
		r.check(source.contains(state), "손님 연기에 %s 상태가 있다" % state)
	r.check(source.contains("_atlas_region") and source.contains("ACT_CROSSFADE"),
		"2x2 원화를 상태별로 자르고 교차 전환한다")
	r.check(source.contains("set_dialogue_active"), "대사 진행이 손님의 말하기 자세를 제어한다")


func _test_portrait_fairness(r: RefCounted) -> void:
	var source := FileAccess.get_file_as_string(CUSTOMER_SCRIPT)
	var start := source.find("func show_customer")
	var finish := source.find(") -> void:", start)
	var signature := source.substr(start, finish - start) if start >= 0 and finish > start else source
	r.check(source.contains("OPEN_SHEETS") and source.contains("HOOD_SHEETS"),
		"공개 특성별 연기 시트 그룹을 사용한다")
	r.check(source.contains("_session_salt") and source.contains("customer_id, _session_salt"),
		"한 회차 안에서는 같은 얼굴을 유지하고 새 게임에서는 외운 얼굴을 다시 섞는다")
	r.check(source.contains("APPEARANCE_OVERRIDES")
		and source.contains("cust_office_worker") and source.contains("cust_student_bag"),
		"이름에 성별·역할이 명시된 손님은 일치하는 시트로 고정한다")
	for forbidden in ["anomaly", "verdict", "has_shadow"]:
		r.check(not signature.contains(forbidden), "시트 선택기가 %s를 입력받지 않는다" % forbidden)


static func _luminance(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


static func _colors_in(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var regex := RegEx.new()
	regex.compile('Color\\("([0-9a-fA-F]{6})"\\)')
	for found in regex.search_all(FileAccess.get_file_as_string(path)):
		out.append(found.get_string(1))
	return out
