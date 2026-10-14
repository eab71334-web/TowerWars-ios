extends Control

const NavBar = preload("res://navbar.gd")
const PW = preload("res://powers.gd")
const PowerIcon = preload("res://power_icon.gd")
const PowerHelp = preload("res://power_help.gd")
const GOLD := Color(1.0, 0.86, 0.2)
const GREEN := Color(0.15, 0.75, 0.42)
const RED := Color(0.9, 0.3, 0.35)
const ORANGE := Color(1.0, 0.58, 0.08)
const BLUE := Color(0.18, 0.52, 1.0)

var vb: VBoxContainer
var scroll: ScrollContainer
var dragging := false
var drag_start_y := 0.0
var drag_start_scroll := 0

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 110)
	add_child(margin)
	var nav = NavBar.new()
	nav.current = "shop"
	add_child(nav)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(scroll)
	vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 16)
	scroll.add_child(vb)
	_build()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			dragging = true
			drag_start_y = event.position.y
			drag_start_scroll = scroll.scroll_vertical
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		scroll.scroll_vertical = drag_start_scroll - int(event.position.y - drag_start_y)

func _panel(h_margin: float = 20.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := UI.style(Color(0.12, 0.08, 0.4, 0.95), 34, 10)
	sb.content_margin_left = h_margin
	sb.content_margin_right = h_margin
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 22.0
	p.add_theme_stylebox_override("panel", sb)
	return p

func _txt(text: String, fs: int, color: Color, outline: int) -> Label:
	var l := UI.label(text, fs, color, outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build() -> void:
	for c in vb.get_children():
		vb.remove_child(c)
		c.queue_free()

	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 56)
	vb.add_child(top_pad)

	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(NavBar.coin_pill())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var tl := _txt("القدرات", 60, GOLD, 12)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(tl)

	vb.add_child(_txt("اختر 3 قدرات فقط لتأخذها معك إلى المباراة", 26, Color(0.75, 0.95, 1.0), 4))
	vb.add_child(_loadout_panel())
	vb.add_child(_txt("كل قدرة تُستهلك عند الاستخدام. الحزمة 5 قدرات", 24, Color(1, 1, 1, 0.65), 0))
	for d in PW.LIST:
		vb.add_child(_card(d))

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 80)
	vb.add_child(pad)

func _loadout_panel() -> Control:
	var ids: Array = PW.get_loadout()
	var p := _panel()
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(_txt("قدراتك في المباراة (%d/%d)" % [ids.size(), PW.MAX_LOADOUT], 32, Color.WHITE, 8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	for i in PW.MAX_LOADOUT:
		if i < ids.size():
			var id := str(ids[i])
			var ic = PowerIcon.new()
			ic.pid = id
			ic.count = PW.count(id)
			ic.show_count = true
			ic.custom_minimum_size = Vector2(112, 112)
			ic.tapped.connect(_toggle.bind(id))
			row.add_child(ic)
		else:
			var e := PanelContainer.new()
			e.custom_minimum_size = Vector2(112, 112)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			e.add_theme_stylebox_override("panel", UI.style(Color(0.08, 0.05, 0.3, 0.9), 56, 6))
			e.add_child(_txt("فارغ", 24, Color(1, 1, 1, 0.5), 0))
			row.add_child(e)
	v.add_child(_txt("المس قدرة مجهّزة لإزالتها", 22, Color(1, 1, 1, 0.5), 0))
	return p

func _card(d: Dictionary) -> Control:
	var id := str(d.id)
	var is_self := str(d.kind) == "self"
	var equipped := PW.get_loadout().has(id)
	var p := _panel(16.0)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	var btns := VBoxContainer.new()
	btns.mouse_filter = Control.MOUSE_FILTER_PASS
	btns.custom_minimum_size = Vector2(170, 0)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btns.add_theme_constant_override("separation", 8)
	h.add_child(btns)
	btns.add_child(_buy_btn(int(d.price), id))
	if equipped:
		btns.add_child(_action("إزالة", RED, 60, 26, _toggle.bind(id)))
	else:
		btns.add_child(_action("تجهيز", GREEN, 60, 26, _toggle.bind(id)))
	btns.add_child(_action("كيف تعمل؟", BLUE, 60, 24, _help.bind(id)))

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	h.add_child(info)
	info.add_child(_txt(str(d.name), 36, Color.WHITE, 8))
	info.add_child(_txt("تقوية لنفسك" if is_self else "هجوم على الخصم", 24, Color(0.4, 1.0, 0.6) if is_self else Color(1.0, 0.5, 0.5), 4))
	info.add_child(_txt(str(d.desc), 22, Color(1, 1, 1, 0.85), 0))

	var ic = PowerIcon.new()
	ic.pid = id
	ic.count = PW.count(id)
	ic.show_count = true
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.custom_minimum_size = Vector2(104, 104)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	return p

func _buy_btn(price: int, id: String) -> Control:
	var can := Data.coins >= price
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 60)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", UI.style(ORANGE if can else Color(0.4, 0.3, 0.55), 28, 8))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cc)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	cc.add_child(hb)
	var ic := NavBar.icon("coin", 32)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)
	var l := _txt("%d  +%d" % [price, PW.PACK], 26, Color.WHITE, 6)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(l)
	p.gui_input.connect(_tap_input.bind(_buy.bind(id)))
	return p

func _action(text: String, color: Color, height: float, fs: int, cb: Callable) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, height)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", UI.style(color, 28, 8))
	var l := _txt(text, fs, Color.WHITE, 6)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	p.gui_input.connect(_tap_input.bind(cb))
	return p

func _tap_input(event: InputEvent, cb: Callable) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if UI.tapped():
			Sfx.click()
			cb.call()

func _buy(id: String) -> void:
	var d: Dictionary = PW.def(id)
	if PW.buy(id):
		Sfx.win()
		Net.toast("اشتريت %d من «%s»" % [PW.PACK, str(d.name)])
		_build()
	else:
		Sfx.hit()
		Net.toast("العملات غير كافية، العب لتكسب المزيد")

func _toggle(id: String) -> void:
	var r := PW.toggle(id)
	if r == "full":
		Sfx.hit()
		Net.toast("الحد الأقصى 3 قدرات، أزل واحدة أولاً")
		return
	_build()

func _help(id: String) -> void:
	var hp = PowerHelp.new()
	add_child(hp)
	hp.open(id)
