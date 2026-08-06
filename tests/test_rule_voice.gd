extends RefCounted

## 수칙 문구의 **문체가 데이터와 일치하는가.**
##
## 규약: 어떤 줄은 이유를 대고(변명하고) 어떤 줄은 명령만 한다. 이건 단서다 —
## 이유를 대는 줄은 점장이 쓴 것이 아닐 가능성이 높다.
##
## **하지만 진위와 1:1이면 안 된다.** 예전에는 이 파일이 "거짓은 전부 이유를 대고
## 참은 하나도 안 댄다"를 강제했다. 그 결과 정규식 한 줄(`니[\s,]`)이 수칙 11개의
## 진위를 **11/11 맞히는 완전 분류기**가 됐다. 필체 상관을 불변식 2c로 끊어놓고
## 문체 상관을 대신 만들어 놓은 것이고, 이 파일이 그걸 **강제**하고 있었다.
##
## 지금은 `gives_reason`이 수칙마다 따로 적힌 authored 속성이고, 이 파일은
## **문구가 그 속성과 맞는지만** 본다. 상관 자체는 불변식 2e가 감시한다.
## 두 로케일 모두 보는 이유는 그대로다 — 번역자가 이유절을 매끄럽게 다듬어 없애면
## 그 언어에서만 단서가 사라지고, 아무도 눈치채지 못한다.

const REASON_MARKERS := {
	"ko": ["니 ", "니,", "니、", "때문", "므로"],
	"en": [" so ", " so,", "because"],
}

## `Label`은 마크다운을 해석하지 않는다. 문서용 강조를 표시 문자열에 옮기면 별표가 찍힌다.
const FORBIDDEN_MARKUP := ["**", "__", "`", "<b>", "<i>"]


func run(r: RefCounted) -> void:
	r.suite("rule_voice")
	for locale in REASON_MARKERS:
		_check_locale(r, locale)
		_check_no_markup(r, locale)


func _check_locale(r: RefCounted, locale: String) -> void:
	var strings := GameData.load_strings(locale)
	for rule in GameData.load_rules():
		var text := str(strings.get(rule.text_key, ""))
		r.check(text != "", "[%s] 수칙 %s의 문구가 있다" % [locale, rule.id])
		if text == "":
			continue
		var pleads := _gives_a_reason(text, locale)
		if rule.gives_reason:
			r.check(pleads,
				"[%s] %s는 이유를 대는 줄로 적혀 있는데 문구에 이유절이 없다 — 번역이 단서를 지웠다: 「%s」"
					% [locale, rule.id, text])
		else:
			r.check(not pleads,
				"[%s] %s는 명령만 하는 줄인데 문구가 이유를 댄다 — 없던 단서가 생겼다: 「%s」"
					% [locale, rule.id, text])


func _check_no_markup(r: RefCounted, locale: String) -> void:
	var strings := GameData.load_strings(locale)
	for key in strings:
		if str(key).begins_with("_"):
			continue
		var text := str(strings[key])
		var found := PackedStringArray()
		for markup in FORBIDDEN_MARKUP:
			if text.contains(str(markup)):
				found.append(str(markup))
		r.check(found.is_empty(),
			"[%s] 표시 문자열 %s에 마크다운 %s이 남아 있다 — Label은 그대로 찍는다"
				% [locale, key, str(found)])


func _gives_a_reason(text: String, locale: String) -> bool:
	for marker in REASON_MARKERS[locale]:
		if text.to_lower().contains(str(marker)):
			return true
	return false
