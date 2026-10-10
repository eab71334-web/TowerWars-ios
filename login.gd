extends Control

const GOLD := Color(1.0, 0.86, 0.2)

var user_in: LineEdit
var pass_in: LineEdit
var name_in: LineEdit
var status: Label
var action_btn: Button
var mode_btn: Button
var is_register := false
var went := false

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	margin.add_child(vb)

	vb.add_child(UI.label("برج الكتل", 100, GOLD, 18))
	vb.add_child(UI.label("حسابك يحفظ مستواك وأصدقاءك", 32, Color(0.75, 0.95, 1.0), 6))

	user_in = _field("اسم المستخدم (إنجليزي)")
	vb.add_child(user_in)
	name_in = _field("اسمك داخل اللعبة")
	vb.add_child(name_in)
	pass_in = _field("كلمة السر")
	pass_in.secret = true
	vb.add_child(pass_in)

	action_btn = UI.button("", Color(1.0, 0.58, 0.08), 130, 42)
	action_btn.pressed.connect(_submit)
	vb.add_child(action_btn)

	mode_btn = UI.button("", Color(0.18, 0.52, 1.0), 100, 32)
	mode_btn.pressed.connect(func():
		is_register = not is_register
		status.text = ""
		_apply_mode())
	vb.add_child(mode_btn)

	status = UI.label("", 30, Color(1.0, 0.8, 0.5), 5)
	vb.add_child(status)
	vb.add_child(UI.label("لا تستخدم كلمة سر حسابات أخرى", 24, Color(1, 1, 1, 0.5), 0))

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)
	var later := UI.button("لاحقاً", Color(0.45, 0.35, 0.85), 100, 32)
	later.pressed.connect(_on_later)
	vb.add_child(later)

	_apply_mode()
	Net.message.connect(_on_msg)
	Net.profile_changed.connect(_on_profile)
	if not Net.is_open:
		status.text = "جاري الاتصال بالخادم..."
		Net.connected.connect(func(): status.text = "", CONNECT_ONE_SHOT)

func _field(hint: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = hint
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.custom_minimum_size = Vector2(0, 100)
	le.add_theme_font_size_override("font_size", 38)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.24, 0.92)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.3, 0.8, 1.0)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	le.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.border_color = GOLD
	le.add_theme_stylebox_override("focus", sb2)
	le.add_theme_color_override("font_color", Color.WHITE)
	le.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	return le

func _apply_mode() -> void:
	name_in.visible = is_register
	action_btn.text = "إنشاء الحساب" if is_register else "دخول"
	mode_btn.text = "عندي حساب بالفعل" if is_register else "حساب جديد"

func _submit() -> void:
	if not Net.is_open:
		status.text = "لا يوجد اتصال بالخادم، انتظر ثواني وجرّب"
		return
	var u := user_in.text.strip_edges()
	var p := pass_in.text
	if u == "" or p == "":
		status.text = "اكتب اسم المستخدم وكلمة السر"
		return
	status.text = "جاري المعالجة..."
	if is_register:
		Net.send({"t": "register", "user": u, "pass": p, "name": name_in.text})
	else:
		Net.send({"t": "login", "user": u, "pass": p})

func _on_msg(m: Dictionary) -> void:
	if str(m.get("t", "")) == "acc_err":
		status.text = str(m.get("m", "خطأ"))

func _on_profile() -> void:
	if Net.logged_in() and not went:
		went = true
		get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_later() -> void:
	Net.skipped_login = true
	Net.save()
	get_tree().change_scene_to_file("res://main_menu.tscn")
