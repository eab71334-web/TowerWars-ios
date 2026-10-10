extends Control

const IconNode = preload("res://icon_node.gd")
const GOLD := Color(1.0, 0.86, 0.2)
const TABS := [
	["home", "الرئيسية", "home"],
	["challenges", "التحديات", "target"],
	["shop", "المتجر", "shop"],
	["friends", "الأصدقاء", "friends"],
	["profile", "حسابي", "user"],
]

var current := "home"

static func icon(kind: String, px: float, color: Color = Color.WHITE, color2: Color = Color(0.15, 0.08, 0.35), badge: bool = false) -> Control:
	var n = IconNode.new()
	n.kind = kind
	n.col = color
	n.col2 = color2
	n.badge = badge
	n.custom_minimum_size = Vector2(px, px)
	return n

static func bar(value: float, max_value: float, color: Color, h: float = 24.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, h)
	b.show_percentage = false
	b.max_value = maxf(1.0, max_value)
	b.value = value
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(int(h / 2.0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(h / 2.0))
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b

static func coin_pill() -> Control:
	var panel := PanelContainer.new()
	var sb := UI.style(Color(0.08, 0.05, 0.3, 0.9), 30, 6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var ic := icon("coin", 48)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UI.label(str(Data.coins), 36, Color.WHITE, 6)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var cb := func(): l.text = str(Data.coins)
	Data.coins_changed.connect(cb)
	l.tree_exiting.connect(func(): Data.coins_changed.disconnect(cb))
	return panel

static func tap(cb: Callable, target: Control) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var e := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, e)
	b.pressed.connect(func():
		Sfx.click()
		cb.call())
	if target != null:
		target.resized.connect(func(): target.pivot_offset = target.size / 2.0)
		b.button_down.connect(func(): target.create_tween().tween_property(target, "scale", Vector2(0.95, 0.95), 0.08))
		b.button_up.connect(func(): target.create_tween().tween_property(target, "scale", Vector2.ONE, 0.1))
	return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -160.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	var bar_panel := PanelContainer.new()
	bar_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := UI.style(Color(0.07, 0.04, 0.27, 0.98), 0, 0)
	sb.corner_radius_top_left = 40
	sb.corner_radius_top_right = 40
	sb.shadow_offset = Vector2(0, -6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 26.0
	bar_panel.add_theme_stylebox_override("panel", sb)
	add_child(bar_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar_panel.add_child(row)
	for i in range(TABS.size() - 1, -1, -1):
		row.add_child(_tab(TABS[i]))

func _tab(tab: Array) -> Control:
	var id := str(tab[0])
	var sel := id == current
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.14) if sel else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(26)
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var c := GOLD if sel else Color(0.7, 0.75, 1.0)
	var badge := id == "challenges" and (Data.daily_available() or Data.claimable_count() > 0)
	var ic := icon(str(tab[2]), 54.0 if sel else 46.0, c, Color(0.2, 0.12, 0.45), badge)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UI.label(str(tab[1]), 22, c, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(l)
	p.add_child(tap(_go.bind(id), null))
	return p

func _go(id: String) -> void:
	if id == current:
		return
	var path := ""
	match id:
		"home":
			path = "res://main_menu.tscn"
		"challenges":
			path = "res://challenges.tscn"
		"shop":
			path = "res://shop.tscn"
		"friends":
			path = "res://social.tscn" if Net.logged_in() else "res://friends.tscn"
		"profile":
			path = "res://profile.tscn" if Net.logged_in() else "res://login.tscn"
	get_tree().change_scene_to_file(path)
