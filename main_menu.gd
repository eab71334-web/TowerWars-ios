extends Control

var tower: Control
var title: Label
var toast: Label
var sound_btn: Button
var chip: Button
var t := 0.0

func _ready() -> void:
	if Net.token == "" and not Net.skipped_login and not Net.logged_in():
		get_tree().change_scene_to_file("res://login.tscn")
		return

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	chip = UI.button("", Color(0.18, 0.52, 1.0), 64, 24)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.custom_minimum_size = Vector2(300, 64)
	chip.pressed.connect(_on_profile)
	top.add_child(chip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	sound_btn = UI.button("", Color(0.45, 0.3, 0.9), 64, 24)
	sound_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	sound_btn.custom_minimum_size = Vector2(270, 64)
	sound_btn.pressed.connect(_on_sound)
	top.add_child(sound_btn)
	_refresh_sound()
	_refresh_chip()
	Net.profile_changed.connect(_refresh_chip)

	title = UI.label("برج الكتل", 112, Color(1.0, 0.86, 0.2), 20)
	col.add_child(title)
	title.resized.connect(func(): title.pivot_offset = title.size / 2.0)
	var tw := create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

	col.add_child(UI.label("ابنِ أعلى برج واهزم خصمك!", 32, Color(0.75, 0.95, 1.0), 6))

	tower = Control.new()
	tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower.custom_minimum_size = Vector2(0, 300)
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.draw.connect(_draw_tower)
	col.add_child(tower)

	var play := UI.button("ابدأ اللعب الآن!", Color(1.0, 0.58, 0.08), 150, 48)
	play.pressed.connect(_on_play)
	col.add_child(play)

	var row1 := _row(col)
	var training := UI.button("تدريب منفرد", Color(0.15, 0.75, 0.42), 120, 34)
	training.pressed.connect(_on_training)
	var friends := UI.button("تحدي الأصدقاء", Color(0.18, 0.52, 1.0), 120, 34)
	friends.pressed.connect(_on_friends)
	row1.add_child(training)
	row1.add_child(friends)

	var row2 := _row(col)
	var shop := UI.button("المتجر", Color(0.95, 0.3, 0.65), 120, 34)
	shop.pressed.connect(_on_soon)
	var settings := UI.button("الإعدادات", Color(0.6, 0.4, 1.0), 120, 34)
	settings.pressed.connect(_on_soon)
	row2.add_child(shop)
	row2.add_child(settings)

	var board := UI.button("المتصدرون", Color(0.95, 0.68, 0.08), 100, 36)
	board.pressed.connect(_on_soon)
	col.add_child(board)

	col.add_child(UI.label("الإصدار v1.2", 24, Color(1, 1, 1, 0.55), 0))

	toast = UI.label("", 32, Color.WHITE, 0)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 140.0
	toast.offset_right = -140.0
	toast.offset_top = -170.0
	toast.offset_bottom = -100.0
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_stylebox_override("normal", UI.style(Color(0.1, 0.05, 0.3, 0.92), 30, 0))
	toast.modulate.a = 0.0
	add_child(toast)

	var all: Array = [play, training, friends, shop, settings, board]
	for i in all.size():
		var b: Control = all[i]
		b.modulate.a = 0.0
		b.scale = Vector2(0.85, 0.85)
		var tw2 := create_tween()
		tw2.tween_interval(0.12 * i + 0.1)
		tw2.tween_property(b, "modulate:a", 1.0, 0.3)
		tw2.parallel().tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == 0:
			tw2.finished.connect(_pulse.bind(b))

func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 18)
	parent.add_child(r)
	return r

func _pulse(b: Control) -> void:
	var p := create_tween().set_loops()
	p.tween_property(b, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	p.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	t += delta
	if tower:
		tower.queue_redraw()

func _block(x: float, y: float, w: float, h: float, c: Color) -> void:
	tower.draw_rect(Rect2(x + 4.0, y + 6.0, w, h), Color(0, 0, 0, 0.25))
	tower.draw_rect(Rect2(x, y, w, h), c)
	tower.draw_rect(Rect2(x, y, w, h * 0.28), c.lightened(0.35))
	tower.draw_rect(Rect2(x, y + h - 5.0, w, 5.0), c.darkened(0.25))

func _draw_tower() -> void:
	var sz := tower.size
	if sz.x < 10.0:
		return
	var bh := clampf(sz.y / 9.0, 30.0, 54.0)
	var widths := [270.0, 250.0, 262.0, 226.0, 210.0, 186.0, 160.0]
	var offs := [0.0, -10.0, 12.0, -6.0, 8.0, -4.0, 2.0]
	var cx := sz.x / 2.0
	var base := sz.y - 8.0
	tower.draw_rect(Rect2(cx - 200.0, base, 400.0, 8.0), Color(1, 1, 1, 0.2))
	for i in widths.size():
		var w: float = widths[i]
		var x := cx + float(offs[i]) + sin(t * 1.6 + i * 0.7) * 5.0 - w / 2.0
		var y := base - (i + 1) * bh
		var c := Color.from_hsv(fmod(i * 0.085 + t * 0.05, 1.0), 0.65, 0.97)
		_block(x, y, w, bh - 4.0, c)
	var topy := base - (widths.size() + 1) * bh - 6.0 + sin(t * 4.0) * 3.0
	var sw := 150.0
	var sx := cx + sin(t * 2.0) * 120.0 - sw / 2.0
	_block(sx, topy, sw, bh - 4.0, Color.from_hsv(fmod(t * 0.12, 1.0), 0.7, 1.0))

func _refresh_sound() -> void:
	sound_btn.text = "الموسيقى: تشغيل" if Sfx.music_on else "الموسيقى: إيقاف"

func _refresh_chip() -> void:
	if chip == null:
		return
	if Net.logged_in():
		chip.text = "م%d · %s" % [int(Net.profile.get("level", 1)), str(Net.profile.get("name", ""))]
	else:
		chip.text = "تسجيل الدخول"

func _on_profile() -> void:
	if Net.logged_in():
		get_tree().change_scene_to_file("res://profile.tscn")
	else:
		get_tree().change_scene_to_file("res://login.tscn")

func _on_sound() -> void:
	Sfx.set_music(not Sfx.music_on)
	_refresh_sound()

func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _on_play() -> void:
	Engine.set_meta("mode", "random")
	_go("res://online.tscn")

func _on_training() -> void:
	_go("res://versus.tscn")

func _on_friends() -> void:
	_go("res://friends.tscn")

func _on_soon() -> void:
	toast.text = "قريباً..."
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
