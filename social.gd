extends Control

const GOLD := Color(1.0, 0.86, 0.2)
const GREEN := Color(0.15, 0.75, 0.42)
const RED := Color(0.9, 0.3, 0.35)
const ORANGE := Color(1.0, 0.58, 0.08)
const BLUE := Color(0.18, 0.52, 1.0)

var list: VBoxContainer
var status: Label
var cancel_btn: Button
var search_in: LineEdit
var results: Array = []
var searched := false

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	margin.add_child(vb)

	vb.add_child(UI.label("أصدقائي", 68, GOLD, 14))

	if not Net.logged_in():
		vb.add_child(UI.label("سجّل الدخول لإضافة أصدقاء وتحديهم", 36, Color.WHITE, 8))
		var lb := UI.button("تسجيل الدخول", BLUE, 130, 40)
		lb.pressed.connect(func(): get_tree().change_scene_to_file("res://login.tscn"))
		vb.add_child(lb)
		var fl := Control.new()
		fl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(fl)
		vb.add_child(_back())
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	search_in = LineEdit.new()
	search_in.placeholder_text = "ابحث بالاسم أو الـ ID"
	search_in.alignment = HORIZONTAL_ALIGNMENT_CENTER
	search_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_in.custom_minimum_size = Vector2(0, 90)
	search_in.add_theme_font_size_override("font_size", 32)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.24, 0.92)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.3, 0.8, 1.0)
	search_in.add_theme_stylebox_override("normal", sb)
	search_in.add_theme_stylebox_override("focus", sb)
	search_in.text_submitted.connect(func(_t): _search())
	row.add_child(search_in)
	var go := UI.button("بحث", BLUE, 90, 32)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.custom_minimum_size = Vector2(150, 90)
	go.pressed.connect(_search)
	row.add_child(go)

	status = UI.label("", 30, Color(1.0, 0.8, 0.5), 5)
	vb.add_child(status)
	cancel_btn = UI.button("إلغاء التحدي", RED, 80, 28)
	cancel_btn.visible = false
	cancel_btn.pressed.connect(func():
		Net.send({"t": "ch_cancel"})
		status.text = ""
		cancel_btn.visible = false)
	vb.add_child(cancel_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	vb.add_child(_back())

	Net.message.connect(_on_msg)
	Net.friends_changed.connect(_rebuild)
	Net.send({"t": "friends"})
	_rebuild()

func _back() -> Button:
	var b := UI.button("رجوع", Color(0.45, 0.35, 0.85), 90, 30)
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://friends.tscn"))
	return b

func _search() -> void:
	var q := search_in.text.strip_edges()
	if q == "":
		return
	Net.send({"t": "search", "q": q})

func _is_friend(pid: String) -> bool:
	for f in Net.friends:
		if str(f.id) == pid:
			return true
	return false

func _rebuild() -> void:
	if list == null:
		return
	for c in list.get_children():
		c.queue_free()
	if Net.requests.size() > 0:
		list.add_child(UI.label("طلبات الصداقة", 34, ORANGE, 6))
		for p in Net.requests:
			_row(p, [["قبول", GREEN, _accept.bind(str(p.id))], ["رفض", RED, _decline.bind(str(p.id))]])
	if searched:
		list.add_child(UI.label("نتائج البحث", 34, Color(0.75, 0.95, 1.0), 6))
		if results.is_empty():
			list.add_child(UI.label("لا توجد نتائج", 28, Color(1, 1, 1, 0.6), 0))
		for r in results:
			if _is_friend(str(r.id)):
				_row(r, [])
			else:
				_row(r, [["إضافة", GREEN, _add.bind(str(r.id))]])
	list.add_child(UI.label("أصدقائي (%d)" % Net.friends.size(), 34, GOLD, 6))
	if Net.friends.is_empty():
		list.add_child(UI.label("ما عندك أصدقاء بعد. ابحث بالاسم أو الـ ID", 28, Color(1, 1, 1, 0.6), 0))
	for p in Net.friends:
		if p.get("online", false):
			_row(p, [["تحدّي", ORANGE, _challenge.bind(p)]])
		else:
			_row(p, [])

func _row(p: Dictionary, btns: Array) -> void:
	var panel := PanelContainer.new()
	var sbx := UI.style(Color(0.1, 0.07, 0.34, 0.9), 28, 6)
	sbx.content_margin_left = 16.0
	sbx.content_margin_right = 16.0
	sbx.content_margin_top = 12.0
	sbx.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sbx)
	list.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	for b in btns:
		var btn := UI.button(str(b[0]), b[1], 80, 28)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.custom_minimum_size = Vector2(150, 80)
		btn.pressed.connect(b[2])
		h.add_child(btn)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var dot := "● " if p.get("online", false) else "○ "
	var n := UI.label("%s%s  (م%d)" % [dot, str(p.name), int(p.level)], 32, Color.WHITE, 6)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(n)
	var idl := UI.label("ID %s" % str(p.id), 22, Color(1, 1, 1, 0.6), 0)
	idl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(idl)

func _add(pid: String) -> void:
	Net.send({"t": "fr_add", "id": pid})

func _accept(pid: String) -> void:
	Net.send({"t": "fr_accept", "id": pid})

func _decline(pid: String) -> void:
	Net.send({"t": "fr_decline", "id": pid})

func _challenge(p: Dictionary) -> void:
	status.text = "بانتظار موافقة %s..." % str(p.name)
	cancel_btn.visible = true
	Net.send({"t": "ch_send", "id": str(p.id)})

func _on_msg(m: Dictionary) -> void:
	var t := str(m.get("t", ""))
	if t == "search_res":
		results = m["res"]
		searched = true
		_rebuild()
	elif t == "ch_declined":
		status.text = "رفض صديقك التحدي"
		cancel_btn.visible = false
	elif t == "ch_timeout":
		status.text = "ما رد صديقك"
		cancel_btn.visible = false
	elif t == "ch_fail":
		status.text = str(m.get("m", "تعذر التحدي"))
		cancel_btn.visible = false
