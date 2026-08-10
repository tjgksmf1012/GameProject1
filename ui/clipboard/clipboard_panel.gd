extends PanelContainer

## 점장이 남긴 수칙. 화면에서 유일하게 따뜻한 것 — 차가운 형광등 아래 종이 한 장.
##
## **수칙마다 종이가 다르다.** 점장이 처음에 쓴 줄과 나중에 누군가 덧쓴 줄은
## 종이 색조와 잉크가 미세하게 다르다 (F-05, `shaders/paper.gdshader`).
##
## `tools/solver_audit.gd`가 확인한 대로 논리적 모순은 "둘 중 하나가 거짓"까지만 알려준다.
## **어느 쪽인지는 이 시각 단서가 말해준다.** 없으면 코어 훅은 도박이 된다.

const Palette := preload("res://ui/theme_factory.gd")
const Juice := preload("res://ui/juice.gd")
const StrikeMark := preload("res://ui/clipboard/strike_mark.gd")
const PaperRow := preload("res://ui/clipboard/paper_row.gd")
const ReplaySpotlight := preload("res://ui/clipboard/replay_spotlight.gd")

const RULE_SEPARATION := 7
const RISE_DURATION := 0.34
const STAGGER := 0.05
const MIN_LIST_HEIGHT := 120

## 메모는 읽히되 **수칙만큼 크지 않다.** 같은 크기면 지켜야 할 줄로 읽힌다.
const NOTE_ALPHA := 0.86
## 찢긴 자국은 종이에 남지만 읽을 것은 아니다. 눈에는 띄되 수칙으로는 안 읽혀야 한다.
const TORN_ALPHA := 0.72

signal rule_added
## 찢긴 자국이 **새로** 생겼다. 밤 7의 사건이고, 소리가 붙어야 사건으로 읽힌다.
signal rule_torn
## 플레이어가 수칙 하나를 그었다/지웠다. **믿음일 뿐이고 판정에는 영향이 없다.**
signal strike_toggled(rule_id: String)

var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _strings: Dictionary = {}
var _shown_ids: PackedStringArray = []
var _rows: Dictionary = {}
var _labels: Dictionary = {}
var _strikes: Dictionary = {}
var _torn: Dictionary = {}
var _notes: Dictionary = {}


func _init() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PAPER, Palette.PAPER_EDGE))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build() -> void:
	if _list != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", RULE_SEPARATION)
	add_child(box)

	box.add_child(Palette.make_label(_t("ui.clipboard_header"), Palette.SIZE_HEAD, Palette.PAPER_TEXT))
	box.add_child(_divider())

	# 스크롤이 있어야 수칙이 늘어나도 화면이 안 무너진다 (F-05).
	# 부수 효과가 더 중요하다 — 최소 높이가 작아져서 결과 패널이 들어갈 자리가 난다.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, MIN_LIST_HEIGHT)
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", RULE_SEPARATION)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func set_strings(strings: Dictionary) -> void:
	_strings = strings
	_build()


func _t(key: String) -> String:
	return str(_strings.get(key, "<%s>" % key))


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Palette.PAPER_EDGE
	line.custom_minimum_size = Vector2(0, 1)
	return line


## 새 수칙만 골라 끼워 넣는다. 이미 붙어 있던 줄은 다시 애니메이션하지 않는다.
##
## `reveal`이면 새로 붙은 줄까지 스크롤을 내린다 — **근무 중에 붙는 줄(밤 5)은
## 목록 맨 아래에 생기므로 그냥 두면 화면 밖이다.** 종이 소리만 나고 화면은 그대로면
## 그건 연출이 아니라 버그로 읽힌다. 밤 시작에는 내리지 않는다 (첫째 줄부터 읽어야 한다).
func show_rules(rules: Array[Rule], reveal: bool = false) -> void:
	_remove_absent(rules)
	var added := 0
	for rule in rules:
		if _shown_ids.has(rule.id):
			continue
		_shown_ids.append(rule.id)
		var row := _make_row(rule)
		_list.add_child(row)
		_rows[rule.id] = row
		Juice.fade_in(row, RISE_DURATION, added * STAGGER)
		added += 1
	if added == 0:
		return
	rule_added.emit()
	if reveal:
		_scroll_to_new_rule()


## 찢겨 나간 줄 자리에 **자국을 남긴다** (밤 7). 그냥 사라지게 두면 처음 배운 수칙이
## 조용히 없어지고, 그걸 모른 채 판정하면 퍼즐이 아니라 함정이다.
##
## 자국은 `_shown_ids`에 넣지 않는다 — 그건 **지금 유효한 수칙** 목록이고,
## 화면과 엔진이 같은 것을 본다는 검사(tests/test_clipboard.gd)의 기준이기 때문이다.
## 자국은 수칙이 아니라 수칙이 있었다는 흔적이다.
func show_torn(rules: Array[Rule]) -> void:
	for rule in rules:
		if _torn.has(rule.id):
			continue
		var row := PaperRow.make("✂ " + _t("clipboard.torn"), Palette.SIZE_BODY,
			Palette.INK_LATER, true, false, _torn.size() + 90)
		row.modulate.a = TORN_ALPHA
		_list.add_child(row)
		_torn[rule.id] = row
		# **TORN_ALPHA 로 도착해야 한다.** 1.0으로 올리면 위에서 준 0.72가 지워진다.
		Juice.fade_in(row, RISE_DURATION, 0.0, TORN_ALPHA)
		rule_torn.emit()


## 줄 순서를 원래 수칙 순서로 되돌린다.
##
## 찢긴 자국은 나중에 붙이므로 그냥 두면 목록 맨 아래에 생긴다. 그러면 화면상
## **첫째 줄이 그냥 사라진 것으로 보이고** 정체불명의 자국만 바닥에 남는다.
## 자국은 그 줄이 있던 자리에 있어야 "여기 있던 게 찢겼다"로 읽힌다.
func reorder(canonical_ids: PackedStringArray) -> void:
	var at := 0
	for id in canonical_ids:
		var row: Node = _rows.get(id, _notes.get(id, _torn.get(id)))
		if row == null:
			continue
		_list.move_child(row, at)
		at += 1


## 찢긴 자국을 치운다. 밤이 바뀌면 자국도 같이 사라져야 한다.
func clear_torn() -> void:
	for id in _torn:
		(_torn[id] as Node).queue_free()
	_torn.clear()


## **더는 붙어 있지 않은 줄은 걷어낸다.**
##
## 이게 없으면 클립보드가 한 번 붙은 줄을 영영 들고 있는다. 밤 5의 열째 수칙은
## 02:00에 붙는데, 그 밤을 실패하고 다시 시작하면 22:00 화면에 이미 붙어 있다 —
## **아직 쓰이지도 않은 줄을 보고 판정하게 된다.**
func _remove_absent(rules: Array[Rule]) -> void:
	var keep := PackedStringArray()
	for rule in rules:
		keep.append(rule.id)
	for id in _shown_ids.duplicate():
		if keep.has(id):
			continue
		(_rows[id] as Node).queue_free()
		_rows.erase(id)
		_labels.erase(id)
		_strikes.erase(id)
		# 목록에서도 빼야 다시 붙을 때 새 줄로 취급돼 애니메이션과 종이 소리가 난다.
		_shown_ids.remove_at(_shown_ids.find(id))


## 새 줄은 항상 목록 맨 아래에 붙으므로 **끝까지 내린다.** `ensure_control_visible`은
## 여기서 안 움직인다 — 줄이 막 붙어 라벨 높이가 아직 안 나왔고, 그 상태로 계산하면
## 이미 보이는 것으로 친다. 두 프레임 기다린 뒤 스크롤 최대치로 보내는 쪽이 확실하다.
func _scroll_to_new_rule() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int(bar.max_value)


func _make_row(rule: Rule) -> PanelContainer:
	var row := PaperRow.make(
		ScreenSnapshot.line_prefix(false) + _t(rule.text_key),
		Palette.SIZE_BODY, Palette.INK_MANAGER, false, false, 0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	# 패드로도 그을 수 있어야 한다. 그리기는 밤 4(수칙 아홉 줄)부터 사실상 필수다.
	row.focus_mode = Control.FOCUS_ALL
	row.add_theme_stylebox_override("focus", Palette.focus_style(Palette.PAPER))
	row.gui_input.connect(_on_row_input.bind(rule.id))
	var label := PaperRow.label_of(row)
	_labels[rule.id] = label
	_strikes[rule.id] = StrikeMark.attach(label)
	return row


## 메모를 붙인다. **판정에 참여하지 않는 줄이다** — 그을 수도 없고 포커스도 안 잡힌다.
##
## `_shown_ids`에 넣지 않는 것은 찢긴 자국과 같은 이유다. 그 목록은 **지금 유효한 수칙**이고,
## 화면과 엔진이 같은 것을 본다는 검사(tests/test_clipboard.gd)의 기준이기 때문이다.
## 메모를 거기 넣으면 그 검사가 조용히 무의미해진다.
func show_notes(notes: Array[Rule], night: int, reveal: bool = false) -> void:
	var keep := PackedStringArray()
	for note in notes:
		keep.append(note.id)
	for id in _notes.keys():
		if not keep.has(str(id)):
			(_notes[id] as Node).queue_free()
			_notes.erase(id)
	var added := 0
	for note in notes:
		if _notes.has(note.id):
			continue
		var foreign := note.hand_at(night) != Rule.HAND_MANAGER
		var row := PaperRow.make(
			ScreenSnapshot.note_prefix() + _t(note.text_key), Palette.SIZE_SMALL,
			Palette.INK_LATER if foreign else Palette.INK_MANAGER,
			foreign, false, _notes.size() + 40)
		_list.add_child(row)
		_notes[note.id] = row
		Juice.fade_in(row, RISE_DURATION, added * STAGGER, NOTE_ALPHA)
		added += 1
	if added == 0:
		return
	# **소리 없이 종이가 늘어나면 안 된다.** 밤 3의 메모는 04:00에 혼자 붙는다 —
	# 같이 붙는 수칙이 없으므로 `show_rules`의 종이 소리가 안 난다. 화면만 바뀌고
	# 소리가 없으면 그건 연출이 아니라 버그로 읽힌다 (밤 7의 찢김에서 같은 실수를 했다).
	rule_added.emit()
	if reveal:
		_scroll_to_new_rule()


## 클릭·ui_accept 로 긋고 다시 눌러 지운다. **표시일 뿐 판정은 바뀌지 않는다.**
## 없으면 밤 4(수칙 아홉 줄)부터 추론이 아니라 기억력 게임이 된다.
func _on_row_input(event: InputEvent, rule_id: String) -> void:
	var click := event as InputEventMouseButton
	var clicked := click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		strike_toggled.emit(rule_id)


## 밤을 새로 열 때는 이미 그어져 있던 줄을 **애니메이션 없이** 되살린다.
## 밤이 시작되자마자 펜이 저절로 움직이면 누가 긋는 것처럼 보인다.
func set_struck(rule_ids: PackedStringArray, animate_id: String = "") -> void:
	for id in _strikes:
		var mark: Node2D = _strikes[id]
		if rule_ids.has(id):
			mark.show_stroke(str(id) == animate_id)
		else:
			mark.hide_stroke()


## 밤마다 줄의 종이와 잉크를 다시 칠한다.
## **전환된 수칙은 그 밤부터 고쳐 쓴 자국이 남는다** — 안 보이면 "속았다"가 된다.
func apply_night(rules: Array[Rule], night: int) -> void:
	for i in rules.size():
		var rule := rules[i]
		if not _rows.has(rule.id):
			continue
		var foreign := rule.hand_at(night) != Rule.HAND_MANAGER
		var rewritten := rule.has_decayed_by(night)
		(_rows[rule.id] as PanelContainer).material = PaperRow.material(foreign, rewritten, i)
		var label: Label = _labels[rule.id]
		label.add_theme_color_override(
			"font_color", Palette.INK_LATER if foreign else Palette.INK_MANAGER)
		# 고쳐 쓴 줄에는 표식이 남는다. 잉크 색만으로는 눈에 안 들어온다.
		label.text = ScreenSnapshot.line_prefix(rewritten) + _t(rule.text_key)


## 3초 리플레이가 놓친 줄을 짚는다. 연출 자체는 `replay_spotlight.gd`가 소유한다.
func highlight(rule_ids: PackedStringArray) -> void:
	ReplaySpotlight.light(_scroll, _rows, rule_ids)


func clear_highlight() -> void:
	ReplaySpotlight.clear(_rows)
