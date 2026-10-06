extends Control

var code_input: LineEdit
var status: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.1, 0.25))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 80.0
	vb.offset_right = -80.0
	vb.offset_top = 160.0
	vb.offset_bottom = -120.0
	vb.add_theme_constant_override("separation", 28)
	add_child(vb)

	var title := Label.new()
	title.text = "تحدي الأصدقاء"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	vb.add_child(title)

	vb.add_child(_spacer(40.0))

	var create := _button("إنشاء لعبة", 130, 38)
	create.pressed.connect(_on_create)
	vb.add_child(create)

	var or_label := Label.new()
	or_label.text = "أو أدخل كود صديقك"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_font_size_override("font_size", 30)
	vb.add_child(or_label)

	code_input = LineEdit.new()
	code_input.placeholder_text = "الكود"
	code_input.max_length = 4
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_input.custom_minimum_size = Vector2(0, 110)
	code_input.add_theme_font_size_override("font_size", 52)
	vb.add_child(code_input)

	var join := _button("دخول", 130, 38)
	join.pressed.connect(_on_join)
	vb.add_child(join)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 28)
	status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	vb.add_child(status)

	vb.add_child(_spacer(30.0))

	var back := _button("رجوع", 90, 30)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	vb.add_child(back)

func _button(text: String, h: float, fs: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", fs)
	return b

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
