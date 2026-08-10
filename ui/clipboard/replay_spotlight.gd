extends RefCounted

## 3초 리플레이(F-07)가 **놓친 줄을 짚는** 연출. 클립보드에서 떼어냈다.
##
## 판정 뒤에만 도는 물건이고 클립보드의 다른 일과 공유하는 상태가 `_rows`·`_scroll`뿐이다.
## 붙여 두면 클립보드가 「종이를 그리는 일」과 「실패를 설명하는 일」을 같이 하게 된다.

## 짚지 않은 줄은 이만큼만 남긴다. 0으로 두면 사라져 버려서 「몇 째 줄인지」가 안 보인다.
const DIM_ALPHA := 0.32
## 놓친 줄이 화면 밖일 때 굴러가는 시간. 3초 리플레이 안에 끝나야 한다.
const SCROLL_DURATION := 0.28


## **짚는 줄이 화면 밖이면 짚은 게 아니다.** 밤 3부터 수칙이 보이는 높이를 넘어가는데
## 예전에는 색만 바꾸고 스크롤은 안 건드렸다 — 놓친 줄이 아래에 있으면 플레이어는
## **전부 흐려지고 아무것도 밝아지지 않는 화면**을 3초 본다 (공정성 불변식 3).
## 새 줄을 붙일 때와 달리 여기서는 배치가 이미 끝나 있다 — 손님이 몇 초째 서 있다.
static func light(scroll: ScrollContainer, rows: Dictionary, rule_ids: PackedStringArray) -> void:
	var deepest: Control = null
	for id in rows:
		var row: PanelContainer = rows[id]
		var lit := rule_ids.has(id)
		row.modulate = Color.WHITE if lit else Color(1.0, 1.0, 1.0, DIM_ALPHA)
		if lit:
			deepest = row  # 화면 밖으로 밀리는 것은 언제나 아래쪽이다
	if deepest == null:
		return
	var before := scroll.scroll_vertical
	scroll.ensure_control_visible(deepest)
	var target := scroll.scroll_vertical
	if target == before:
		return
	scroll.scroll_vertical = before
	var tween := scroll.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(scroll, "scroll_vertical", target, SCROLL_DURATION)


static func clear(rows: Dictionary) -> void:
	for id in rows:
		(rows[id] as PanelContainer).modulate = Color.WHITE
