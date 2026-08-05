extends RefCounted

## 수칙의 **문체 규약**을 검사한다.
##
## 규약(`data/rules/night_01.json`의 `_comment_textual_tell`):
##   참 수칙은 이유를 대지 않고 명령만 한다. 거짓 수칙은 이유를 댄다 — 변명한다.
##
## 밤 3까지는 이게 보조 단서였다. **밤 4부터는 하중 구조물이다.**
## 점장 필체로 쓴 거짓(아홉)이 나오면서 종이가 더는 진위를 말해주지 않기 때문이다.
## 그래서 사람이 지키기로 했던 규약을 여기서 기계가 지킨다.
##
## `strings_en.json`의 머리 주석이 못박은 대로 **이 단서는 번역을 넘어 살아남아야 한다.**
## 번역자가 「먼 길을 왔으니」를 매끄럽게 다듬어 없애면 그 로케일에서 코어 훅이 죽는다.

## 이유를 대는 표지. 한국어는 연결어미 「-니」, 영어는 "so"/"because".
const REASON_MARKERS := {
	"ko": ["니 ", "니,", "니、", "때문", "므로"],
	"en": [" so ", " so,", "because"],
}


## `Label`은 마크다운을 해석하지 않는다. 문서에 쓰던 강조를 표시 문자열에 그대로 옮기면
## 화면에 별표가 그대로 찍힌다. 밤 4의 단서에서 실제로 그랬다.
## 강조가 필요하면 이 프로젝트가 이미 쓰는 「」를 쓴다.
const FORBIDDEN_MARKUP := ["**", "__", "`", "<b>", "<i>"]


func run(r: RefCounted) -> void:
	r.suite("rule_voice")
	for locale in REASON_MARKERS:
		_check_locale(r, locale)
		_check_no_markup(r, locale)


func _check_no_markup(r: RefCounted, locale: String) -> void:
	var strings := GameData.load_strings(locale)
	for key in strings:
		if str(key).begins_with("_"):
			continue  # 주석 키는 화면에 안 나온다
		var text := str(strings[key])
		var found := PackedStringArray()
		for markup in FORBIDDEN_MARKUP:
			if text.contains(str(markup)):
				found.append(str(markup))
		r.check(found.is_empty(),
			"[%s] 표시 문자열 %s에 마크다운 %s이 남아 있다 — Label은 그대로 찍는다"
				% [locale, key, str(found)])


func _check_locale(r: RefCounted, locale: String) -> void:
	var strings := GameData.load_strings(locale)
	for rule in GameData.load_rules():
		var text := str(strings.get(rule.text_key, ""))
		r.check(text != "", "[%s] 수칙 %s의 문구가 있다" % [locale, rule.id])
		if text == "":
			continue
		if _is_visual_tell_only(rule):
			continue
		var pleads := _gives_a_reason(text, locale)
		if rule.veracity == Rule.VERACITY_FALSE:
			r.check(pleads,
				"[%s] 거짓 수칙 %s가 이유를 대지 않는다 — 문체 단서가 사라졌다: 「%s」"
					% [locale, rule.id, text])
		else:
			r.check(not pleads,
				"[%s] 참 수칙 %s가 이유를 댄다 — 점장은 변명하지 않는다: 「%s」"
					% [locale, rule.id, text])


## 전환된 수칙은 예외다. 어제까지 참이었으므로 문구는 명령문 그대로이고,
## 대신 종이와 ✎ 표식이 단서 노릇을 한다 (`data/rules/night_03.json`).
func _is_visual_tell_only(rule: Rule) -> bool:
	return rule.veracity == Rule.VERACITY_DECAYING


func _gives_a_reason(text: String, locale: String) -> bool:
	for marker in REASON_MARKERS[locale]:
		if text.to_lower().contains(str(marker)):
			return true
	return false
