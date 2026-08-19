extends RefCounted

const Palette := preload("res://ui/theme_factory.gd")

const CUSTOMER_SCRIPT := "res://ui/art/customer_figure.gd"
const PRODUCT_SCRIPT := "res://ui/art/product_glyph.gd"
const PORTRAITS := [
	"res://assets/art/customers/office-worker.png",
	"res://assets/art/customers/student.png",
	"res://assets/art/customers/older-woman.png",
	"res://assets/art/customers/bag-woman.png",
	"res://assets/art/customers/bag-worker.png",
	"res://assets/art/customers/hood-no-bag.png",
	"res://assets/art/customers/hood-woman.png",
	"res://assets/art/customers/hood-bag.png",
]
const BRIGHTNESS_GATE := 0.92


func run(r: RefCounted) -> void:
	r.suite("art_palette")
	_test_product_colors(r)
	_test_portrait_roster(r)
	_test_portrait_fairness(r)


func _test_product_colors(r: RefCounted) -> void:
	var paper := _luminance(Palette.PAPER)
	var limit := paper * BRIGHTNESS_GATE
	var colors := _colors_in(PRODUCT_SCRIPT)
	r.check(colors.size() >= 16, "상품 글리프 팔레트를 소스에서 충분히 읽는다")
	for hex in colors:
		var value := _luminance(Color(str(hex)))
		r.check(value <= limit,
			"상품 글리프 #%s가 종이보다 밝다 (%.0f > %.0f)" % [
				hex, value * 255.0, limit * 255.0])


func _test_portrait_roster(r: RefCounted) -> void:
	for path in PORTRAITS:
		r.check(FileAccess.file_exists(path), "런타임 초상이 있다: %s" % path.get_file())
		var texture := load(path) as Texture2D
		r.check(texture != null, "초상을 임포트 텍스처로 읽는다: %s" % path.get_file())
		if texture != null:
			r.check(texture.get_width() >= 1024 and texture.get_height() >= 1024,
				"초상이 1024px 이상 원화다: %s" % path.get_file())


func _test_portrait_fairness(r: RefCounted) -> void:
	var source := FileAccess.get_file_as_string(CUSTOMER_SCRIPT)
	var start := source.find("func show_customer")
	var finish := source.find(") -> void:", start)
	var signature := source.substr(start, finish - start) if start >= 0 and finish > start else source
	r.check(source.contains("OPEN_PORTRAITS") and source.contains("HOOD_PORTRAITS"),
		"공개 특성별 호환 초상 그룹을 사용한다")
	r.check(source.contains("_stable_seed(customer_id)"), "고객 ID로 그룹 안 초상을 안정 분산한다")
	for forbidden in ["anomaly", "verdict", "has_shadow"]:
		r.check(not signature.contains(forbidden), "초상 선택기가 %s를 입력받지 않는다" % forbidden)


static func _luminance(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


static func _colors_in(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var regex := RegEx.new()
	regex.compile('Color\\("([0-9a-fA-F]{6})"\\)')
	for found in regex.search_all(FileAccess.get_file_as_string(path)):
		out.append(found.get_string(1))
	return out
