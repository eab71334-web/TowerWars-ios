extends Control

const NavBar = preload("res://navbar.gd")
const GOLD := Color(1.0, 0.86, 0.2)
const GREEN := Color(0.15, 0.75, 0.42)
const ORANGE := Color(1.0, 0.58, 0.08)

var grid: GridContainer
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

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 16)
	scroll.add_child(vb)

	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 56)
	vb.add_child(top_pad)

	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(NavBar.coin_pill())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var tl := UI.label("المتجر", 60, GOLD, 12)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(tl)
	vb.add_child(UI.label("اشترِ ألوان جديدة لكتلك بعملات تكسبها من المباريات والتحديات", 24, Color(0.75, 0.95, 1.0), 4))

	var pw_btn := UI.button("القدرات الخارقة", Color(0.6, 0.4, 1.0), 90, 34)
	pw_btn.pressed.connect(UI.guard(func(): UI.go("res://power_shop.tscn")))
	vb.add_child(pw_btn)

	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	vb.add_child(grid)

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 80)
	vb.add_child(bottom_pad)
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

func _build() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for def in Data.SKINS:
		grid.add_child(_card(def))

func _card(def: Dictionary) -> Control:
	var id := str(def.id)
	var owned := Data.owned.has(id)
	var equipped := Data.skin == id
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := UI.style(Color(0.12, 0.08, 0.4, 0.95), 34, 10)
	if equipped:
		sb.set_border_width_all(6)
		sb.border_color = GOLD
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 18.0
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var pv := Control.new()
	pv.custom_minimum_size = Vector2(0, 150)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.draw.connect(func():
		var widths := [140.0, 120.0, 110.0, 92.0, 74.0]
		for i in 5:
			var wd: float = widths[i]
			var x := pv.size.x / 2.0 - wd / 2.0 + (6.0 if i % 2 == 0 else -6.0)
			var y := pv.size.y - 8.0 - float(i + 1) * 27.0
			var c := Data.color_for(def, i, 0.0)
			pv.draw_rect(Rect2(x + 3.0, y + 4.0, wd, 23.0), Color(0, 0, 0, 0.25))
			pv.draw_rect(Rect2(x, y, wd, 23.0), c)
			pv.draw_rect(Rect2(x, y, wd, 5.0), c.lightened(0.3)))
	v.add_child(pv)

	var nm := UI.label(str(def.name), 32, Color.WHITE, 8)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)

	if equipped:
		v.add_child(_pill("مُجهّز", GOLD, Color(0.3, 0.2, 0.0)))
	elif owned:
		v.add_child(_action("تجهيز", GREEN, _equip.bind(id)))
	else:
		v.add_child(_buy_btn(int(def.price), id))
	return p

func _pill(text: String, color: Color, tc: Color) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 70)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.style(color, 30, 6))
	var l := UI.label(text, 30, tc, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	return p

func _action(text: String, color: Color, cb: Callable) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 70)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", UI.style(color, 30, 8))
	var l := UI.label(text, 30, Color.WHITE, 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	p.gui_input.connect(_tap_input.bind(cb))
	return p

func _buy_btn(price: int, id: String) -> Control:
	var can := Data.coins >= price
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 70)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", UI.style(ORANGE if can else Color(0.4, 0.3, 0.55), 30, 8))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cc)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	cc.add_child(h)
	var ic := NavBar.icon("coin", 36)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var l := UI.label(str(price), 30, Color.WHITE, 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	p.gui_input.connect(_tap_input.bind(_buy.bind(id)))
	return p

func _tap_input(event: InputEvent, cb: Callable) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if UI.tapped():
			Sfx.click()
			cb.call()

func _equip(id: String) -> void:
	Data.equip(id)
	_build()

func _buy(id: String) -> void:
	var def := Data.skin_def(id)
	if Data.buy(id):
		Data.equip(id)
		Sfx.win()
		Net.toast("تم الشراء وتجهيز %s" % str(def.name))
		_build()
	else:
		Sfx.hit()
		Net.toast("العملات غير كافية، العب لتكسب المزيد")
