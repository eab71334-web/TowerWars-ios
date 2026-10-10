extends Control

const NavBar = preload("res://navbar.gd")
const GOLD := Color(1.0, 0.86, 0.2)
const GREEN := Color(0.15, 0.75, 0.42)
const ORANGE := Color(1.0, 0.58, 0.08)

var grid: GridContainer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 175)
	add_child(margin)
	var nav = NavBar.new()
	nav.current = "shop"
	add_child(nav)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(NavBar.coin_pill())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var tl := UI.label("المتجر", 60, GOLD, 12)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(tl)
	root.add_child(UI.label("اشترِ ألوان جديدة لكتلك بعملات تكسبها من المباريات والتحديات", 24, Color(0.75, 0.95, 1.0), 4))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	_build()

func _build() -> void:
	for c in grid.get_children():
		c.queue_free()
	for def in Data.SKINS:
		grid.add_child(_card(def))

func _card(def: Dictionary) -> Control:
	var id := str(def.id)
	var owned := Data.owned.has(id)
	var equipped := Data.skin == id
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UI.style(Color(0.12, 0.08, 0.4, 0.95), 34, 10)
	if equipped:
		sb.set_border_width_all(6)
		sb.border_color = GOLD
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 20.0
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)

	var pv := Control.new()
	pv.custom_minimum_size = Vector2(0, 190)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.draw.connect(func():
		var widths := [150.0, 130.0, 120.0, 100.0, 80.0]
		for i in 5:
			var wd: float = widths[i]
			var x := pv.size.x / 2.0 - wd / 2.0 + (6.0 if i % 2 == 0 else -6.0)
			var y := pv.size.y - 12.0 - float(i + 1) * 32.0
			var c := Data.color_for(def, i, 0.0)
			pv.draw_rect(Rect2(x + 3.0, y + 5.0, wd, 29.0), Color(0, 0, 0, 0.25))
			pv.draw_rect(Rect2(x, y, wd, 29.0), c)
			pv.draw_rect(Rect2(x, y, wd, 6.0), c.lightened(0.3)))
	v.add_child(pv)

	v.add_child(UI.label(str(def.name), 34, Color.WHITE, 8))

	if equipped:
		v.add_child(_pill("مُجهّز", GOLD, Color(0.3, 0.2, 0.0)))
	elif owned:
		var b := UI.button("تجهيز", GREEN, 76, 30)
		b.pressed.connect(_equip.bind(id))
		v.add_child(b)
	else:
		v.add_child(_buy_btn(int(def.price), id))
	return p

func _pill(text: String, color: Color, tc: Color) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 76)
	var sb := UI.style(color, 30, 6)
	p.add_theme_stylebox_override("panel", sb)
	var l := UI.label(text, 30, tc, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	return p

func _buy_btn(price: int, id: String) -> Control:
	var can := Data.coins >= price
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 76)
	var sb := UI.style(ORANGE if can else Color(0.4, 0.3, 0.55), 30, 8)
	p.add_theme_stylebox_override("panel", sb)
	var cc := CenterContainer.new()
	p.add_child(cc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	cc.add_child(h)
	h.add_child(NavBar.icon("coin", 38))
	var l := UI.label(str(price), 32, Color.WHITE, 6)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	p.add_child(NavBar.tap(_buy.bind(id), p))
	return p

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
