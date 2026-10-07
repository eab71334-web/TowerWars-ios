extends Control

const GOLD := Color(1.0, 0.86, 0.2)

var status: Label
var code_box: VBoxContainer
var code_label: Label
var verify_url := "https://www.google.com/device"
var went := false

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 130)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 26)
	margin.add_child(vb)

	vb.add_child(UI.label("برج الكتل", 104, GOLD, 18))
	vb.add_child(UI.label("سجّل الدخول لحفظ مستواك وإضافة أصدقاء وتحديهم", 34, Color(0.75, 0.95, 1.0), 6))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	vb.add_child(sp)

	var g := UI.button("الدخول بـ Google", Color(0.26, 0.52, 0.96), 140, 44)
	g.pressed.connect(_on_google)
	vb.add_child(g)

	code_box = VBoxContainer.new()
	code_box.add_theme_constant_override("separation", 16)
	code_box.visible = false
	vb.add_child(code_box)
	code_box.add_child(UI.label("اكتب هذا الكود في صفحة Google:", 32, Color.WHITE, 6))
	code_label = UI.label("", 110, GOLD, 14)
	code_box.add_child(code_label)
	var open_btn := UI.button("افتح google.com/device", Color(0.15, 0.75, 0.42), 110, 34)
	open_btn.pressed.connect(func(): OS.shell_open(verify_url))
	code_box.add_child(open_btn)

	status = UI.label("", 30, Color(1.0, 0.8, 0.5), 5)
	vb.add_child(status)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)
	var later := UI.button("لاحقاً", Color(0.45, 0.35, 0.85), 100, 32)
	later.pressed.connect(_on_later)
	vb.add_child(later)

	Net.message.connect(_on_msg)
	Net.profile_changed.connect(_on_profile)
	if not Net.is_open:
		status.text = "جاري الاتصال بالخادم..."
		Net.connected.connect(func(): status.text = "", CONNECT_ONE_SHOT)

func _on_google() -> void:
	if not Net.is_open:
		status.text = "لا يوجد اتصال بالخادم، انتظر ثواني وجرّب"
		return
	status.text = "جاري تجهيز الكود..."
	Net.send({"t": "g_start"})

func _on_msg(m: Dictionary) -> void:
	var t := str(m.get("t", ""))
	if t == "g_code":
		verify_url = str(m.get("url", verify_url))
		code_label.text = str(m.get("code", ""))
		code_box.visible = true
		DisplayServer.clipboard_set(code_label.text)
		status.text = "نسخنا الكود. افتح الرابط واكتبه ثم اختر حسابك."
	elif t == "g_err":
		status.text = str(m.get("m", "خطأ"))

func _on_profile() -> void:
	if Net.logged_in() and not went:
		went = true
		get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_later() -> void:
	Net.skipped_login = true
	Net.save()
	get_tree().change_scene_to_file("res://main_menu.tscn")
