extends CanvasLayer

signal again_pressed
signal menu_pressed

func _init() -> void:
	layer = 50

func build(title: String, subtitle: String, accent: Color, mine: int, theirs: int, opp_name: String, again_text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.12, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var sb := UI.style(Color(0.14, 0.09, 0.42, 0.98), 48, 12)
	sb.content_margin_left = 36.0
	sb.content_margin_right = 36.0
	sb.content_margin_top = 40.0
	sb.content_margin_bottom = 40.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	panel.add_child(vb)

	vb.add_child(UI.label(title, 96, accent, 18))
	vb.add_child(UI.label(subtitle, 32, Color(0.75, 0.95, 1.0), 6))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	vb.add_child(row)
	row.add_child(_score_box(opp_name, theirs, Color(0.4, 0.9, 1.0)))
	row.add_child(_score_box("أنت", mine, Color(1.0, 0.86, 0.2)))

	var again := UI.button(again_text, Color(1.0, 0.58, 0.08), 120, 40)
	again.pressed.connect(func(): again_pressed.emit())
	vb.add_child(again)

	var menu := UI.button("القائمة", Color(0.45, 0.35, 0.85), 100, 32)
	menu.pressed.connect(func(): menu_pressed.emit())
	vb.add_child(menu)

	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	dim.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _score_box(label_text: String, value: int, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(240, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(label_text, 32, Color(1, 1, 1, 0.85), 6))
	v.add_child(UI.label(str(value), 120, color, 14))
	return v
