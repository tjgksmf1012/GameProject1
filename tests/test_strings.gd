extends RefCounted

## 표시 문자열 (F-10). **하드코딩된 표시 문자열은 0개여야 한다** (CLAUDE.md 4절).
##
## `test_fairness.gd`에서 떼어냈다 — 공정성 불변식이 아니라 현지화 검사이고,
## 한 파일이 300줄 상한에 닿았기 때문이다 (CLAUDE.md 1.4).
##
## 여기서 막는 사고는 두 가지다:
##   ① 코드가 참조하는 키가 데이터에 없다 → 화면에 `<key>`가 그대로 뜬다
##   ② 로케일마다 키가 어긋난다 → **그 언어에서만** 뜬다. 출시 후에 알게 된다

const UI_KEYS := [
	"ui.clipboard_header", "ui.customer_header", "ui.observation_header",
	"ui.serve", "ui.refuse", "ui.next", "ui.restart",
	"ui.night", "ui.time", "ui.progress", "ui.yes", "ui.no", "ui.log_saved",
	"result.correct", "result.wrong", "result.trap", "result.trap_grace",
	"result.expected", "result.missed_header",
	"night.cleared", "night.failed", "night.summary",
	"ui.cctv_header", "cctv.counter", "cctv.aisle", "cctv.storage", "cctv.entrance",
	"ui.scan_header", "ui.receipt_header", "ui.receipt_empty", "ui.total", "ui.id_check",
	"ui.night_cleared_next", "night.all_cleared", "death.last_line",
	"pressure.urging", "pressure.demanding",
	"title.store", "title.hours", "title.premise", "title.twist",
	"title.start", "title.continue_night",
]


func run(r: RefCounted) -> void:
	r.suite("strings")
	_all_referenced_keys_exist(r)
	_locales_have_identical_keys(r)


## 코드와 데이터가 참조하는 키가 전부 실제로 있는가.
func _all_referenced_keys_exist(r: RefCounted) -> void:
	var strings := GameData.load_strings()
	r.check(strings.has(RuleEngine.CLUE_NO_RULE_APPLIED),
		"문자열 키 없음: %s" % RuleEngine.CLUE_NO_RULE_APPLIED)
	for key in UI_KEYS:
		r.check(strings.has(key), "문자열 키 없음: %s" % key)
	for rule in GameData.load_rules():
		r.check(strings.has(rule.text_key), "문자열 키 없음: %s" % rule.text_key)
		if rule.tell_key != "":
			r.check(strings.has(rule.tell_key), "문자열 키 없음: %s" % rule.tell_key)
	for customer in GameData.load_customers():
		r.check(strings.has(customer.name_key), "문자열 키 없음: %s" % customer.name_key)
		for key in customer.item_keys:
			r.check(strings.has(key), "문자열 키 없음: %s" % key)
		for key in customer.dialogue_keys:
			r.check(strings.has(key), "문자열 키 없음: %s" % key)
		for name in customer.trait_names():
			r.check(strings.has("trait." + name), "문자열 키 없음: trait.%s" % name)


## 로케일마다 키가 하나라도 어긋나면 그 언어에서는 화면에 `<key>`가 그대로 뜬다.
## 번역 누락을 출시 후에 발견하면 늦다.
func _locales_have_identical_keys(r: RefCounted) -> void:
	var reference := GameData.DEFAULT_LOCALE
	var base := _content_keys(GameData.load_strings(reference))
	for locale in GameData.locales():
		if locale == reference:
			continue
		var other := _content_keys(GameData.load_strings(locale))
		for key in base:
			r.check(other.has(key), "F-10: '%s' 로케일에 키가 없다: %s" % [locale, key])
		for key in other:
			r.check(base.has(key), "F-10: '%s'에만 있는 키다: %s" % [locale, key])


## `_`로 시작하는 키는 주석이므로 번역 대상이 아니다.
static func _content_keys(strings: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key in strings:
		if not str(key).begins_with("_"):
			out.append(str(key))
	return out
