extends Control

const NavBar = preload("res://navbar.gd")
const GOLD := Color(1.0, 0.86, 0.2)

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 175)
	add_child(margin)
	var nav = NavBar.new()
	nav.current = "home"
	add_child(nav)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(NavBar.coin_pill())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var tl := UI.label("الأنماط", 60, GOLD, 12)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(tl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	for m in Data.MODES:
		list.add_child(_card(m))

func _card(m: Dictionary) -> Control:
	var color: Color = m.color
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UI.style(color, 36, 10)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 26.0
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)

	var go := PanelContainer.new()
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gsb := UI.style(Color(1, 1, 1, 0.95), 26, 4)
	gsb.content_margin_left = 22.0
	gsb.content_margin_right = 22.0
	gsb.content_margin_top = 10.0
	gsb.content_margin_bottom = 12.0
	go.add_theme_stylebox_override("panel", gsb)
	var gl := UI.label("العب", 30, color.darkened(0.3), 0)
	gl.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.add_child(gl)
	h.add_child(go)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	info.add_child(UI.label(str(m.name), 40, Color.WHITE, 10))
	info.add_child(UI.label(str(m.desc), 22, Color(1, 1, 1, 0.9), 0))
	var bt := UI.label("الأفضل: %d" % int(Data.best.get(str(m.id), 0)), 24, GOLD, 4)
	info.add_child(bt)

	var ic := NavBar.icon(str(m.icon), 84, Color.WHITE, color.darkened(0.4))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)

	p.add_child(NavBar.tap(_start.bind(str(m.id)), p))
	return p

func _start(id: String) -> void:
	Engine.set_meta("solo_mode", id)
	get_tree().change_scene_to_file("res://solo.tscn")
