extends Control

var code_input: LineEdit
var status: Label

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	margin.add_child(vb)

	vb.add_child(UI.label("تحدي الأصدقاء", 72, Color(1.0, 0.86, 0.2), 16))
	vb.add_child(UI.label("العب ضد صديقك بكود خاص", 30, Color(0.75, 0.95, 1.0), 4))
	vb.add_child(_spacer(30.0))

	var create := UI.button("إنشاء لعبة", Color(1.0, 0.58, 0.08), 140, 44)
	create.pressed.connect(_on_create)
	vb.add_child(create)

	vb.add_child(UI.label("أو أدخل كود صديقك", 32, Color.WHITE, 6))

	code_input = LineEdit.new()
	code_input.placeholder_text = "الكود"
	code_input.max_length = 4
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_input.custom_minimum_size = Vector2(0, 110)
	code_input.add_theme_font_size_override("font_size", 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.24, 0.92)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.3, 0.8, 1.0)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	code_input.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.border_color = Color(1.0, 0.86, 0.2)
	code_input.add_theme_stylebox_override("focus", sb2)
	code_input.add_theme_color_override("font_color", Color.WHITE)
	code_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	vb.add_child(code_input)

	var join := UI.button("دخول", Color(0.15, 0.75, 0.42), 130, 40)
	join.pressed.connect(_on_join)
	vb.add_child(join)

	status = UI.label("", 28, Color(1.0, 0.45, 0.45), 4)
	vb.add_child(status)

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)

	var back := UI.button("رجوع", Color(0.45, 0.35, 0.85), 100, 32)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	vb.add_child(back)

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _on_create() -> void:
	Engine.set_meta("mode", "create")
	get_tree().change_scene_to_file("res://online.tscn")

func _on_join() -> void:
	var code := code_input.text.strip_edges()
	if code.length() != 4 or not code.is_valid_int():
		status.text = "اكتب كود من 4 أرقام"
		return
	Engine.set_meta("mode", "join")
	Engine.set_meta("code", code)
	get_tree().change_scene_to_file("res://online.tscn")
