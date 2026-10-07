extends Control

const GOLD := Color(1.0, 0.86, 0.2)

var vb: VBoxContainer
var name_in: LineEdit

func _ready() -> void:
	if not Net.logged_in():
		get_tree().change_scene_to_file("res://login.tscn")
		return
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	margin.add_child(vb)
	Net.profile_changed.connect(_build)
	_build()

func _build() -> void:
	if not Net.logged_in():
		get_tree().change_scene_to_file("res://main_menu.tscn")
		return
	for c in vb.get_children():
		c.queue_free()
	var p: Dictionary = Net.profile
	var pname := str(p.get("name", ""))

	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(180, 180)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hue := float(int(str(p.get("id", "0"))) % 100) / 100.0
	av.add_theme_stylebox_override("panel", UI.style(Color.from_hsv(hue, 0.6, 0.9), 90, 10))
	vb.add_child(av)
	var letter := UI.label(pname.substr(0, 1), 100, Color.WHITE, 10)
	letter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_child(letter)

	vb.add_child(UI.label(pname, 62, GOLD, 14))

	var idrow := HBoxContainer.new()
	idrow.alignment = BoxContainer.ALIGNMENT_CENTER
	idrow.add_theme_constant_override("separation", 14)
	vb.add_child(idrow)
	idrow.add_child(UI.label("ID: %s" % str(p.get("id", "")), 36, Color(0.75, 0.95, 1.0), 6))
	var cp := UI.button("نسخ", Color(0.18, 0.52, 1.0), 64, 26)
	cp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cp.custom_minimum_size = Vector2(120, 64)
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(str(p.get("id", "")))
		Net.toast("تم نسخ الـ ID"))
	idrow.add_child(cp)

	vb.add_child(UI.label("المستوى %d" % int(p.get("level", 1)), 54, Color.WHITE, 10))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(p.get("need", 1)))
	bar.value = float(p.get("xp", 0))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(20)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(20)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)
	vb.add_child(UI.label("%d / %d XP" % [int(p.get("xp", 0)), int(p.get("need", 1))], 28, Color(1, 1, 1, 0.7), 0))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 20)
	vb.add_child(stats)
	stats.add_child(_stat("انتصارات", int(p.get("wins", 0)), Color(0.4, 1.0, 0.6)))
	stats.add_child(_stat("خسارات", int(p.get("losses", 0)), Color(1.0, 0.5, 0.55)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	name_in = LineEdit.new()
	name_in.placeholder_text = "غيّر اسمك"
	name_in.max_length = 16
	name_in.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_in.custom_minimum_size = Vector2(0, 80)
	name_in.add_theme_font_size_override("font_size", 32)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.24, 0.92)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.3, 0.8, 1.0)
	name_in.add_theme_stylebox_override("normal", sb)
	name_in.add_theme_stylebox_override("focus", sb)
	row.add_child(name_in)
	var save := UI.button("حفظ", Color(0.15, 0.75, 0.42), 80, 30)
	save.size_flags_horizontal = Control.SIZE_SHRINK_END
	save.custom_minimum_size = Vector2(150, 80)
	save.pressed.connect(func():
		if name_in.text.strip_edges() != "":
			Net.send({"t": "set_name", "name": name_in.text}))
	row.add_child(save)

	var fillr := Control.new()
	fillr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fillr)
	var out := UI.button("تسجيل الخروج", Color(0.9, 0.3, 0.35), 90, 30)
	out.pressed.connect(func():
		Net.logout())
	vb.add_child(out)
	var back := UI.button("رجوع", Color(0.45, 0.35, 0.85), 90, 30)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	vb.add_child(back)

func _stat(title: String, value: int, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UI.style(Color(0.1, 0.07, 0.34, 0.9), 28, 6)
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UI.label(title, 28, Color(1, 1, 1, 0.8), 4))
	v.add_child(UI.label(str(value), 64, color, 10))
	return panel
