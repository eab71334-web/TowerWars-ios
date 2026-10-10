extends Control

const NavBar = preload("res://navbar.gd")
const GOLD := Color(1.0, 0.86, 0.2)

var tower: Control
var title: Label
var toast: Label
var name_label: Label
var lvl_label: Label
var xp_bar: ProgressBar
var av_panel: PanelContainer
var av_letter: Label
var t := 0.0

func _ready() -> void:
	if Net.token == "" and not Net.skipped_login and not Net.logged_in():
		get_tree().change_scene_to_file("res://login.tscn")
		return

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 172)
	add_child(margin)

	var nav = NavBar.new()
	nav.current = "home"
	add_child(nav)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# ----- الشريط العلوي -----
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var csb := UI.style(Color(0.1, 0.07, 0.36, 0.92), 36, 8)
	csb.content_margin_left = 14.0
	csb.content_margin_right = 18.0
	csb.content_margin_top = 10.0
	csb.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", csb)
	top.add_child(card)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	card.add_child(ch)
	av_panel = PanelContainer.new()
	av_panel.custom_minimum_size = Vector2(76, 76)
	ch.add_child(av_panel)
	av_letter = UI.label("A", 40, Color.WHITE, 6)
	av_letter.autowrap_mode = TextServer.AUTOWRAP_OFF
	av_letter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av_panel.add_child(av_letter)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	ch.add_child(info)
	name_label = UI.label("", 30, Color.WHITE, 6)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(name_label)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	info.add_child(lrow)
	lvl_label = UI.label("م1", 24, GOLD, 6)
	lvl_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	lrow.add_child(lvl_label)
	xp_bar = NavBar.bar(0.0, 1.0, GOLD, 20.0)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lrow.add_child(xp_bar)
	card.add_child(NavBar.tap(_on_profile, null))

	top.add_child(NavBar.coin_pill())
	top.add_child(_gear())
	_refresh_profile()
	Net.profile_changed.connect(_refresh_profile)

	# ----- الشعار -----
	title = UI.label(Data.GAME_NAME, 96, GOLD, 22)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(title)
	title.resized.connect(func(): title.pivot_offset = title.size / 2.0)
	var tw := create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	var sub := UI.label(Data.GAME_SUB, 28, Color(0.55, 0.9, 1.0), 6)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(sub)

	# ----- البرج -----
	tower = Control.new()
	tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower.custom_minimum_size = Vector2(0, 180)
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.draw.connect(_draw_tower)
	col.add_child(tower)

	# ----- زر اللعب -----
	var play := UI.button("العب الآن", Color(1.0, 0.58, 0.08), 150, 56)
	play.pressed.connect(_on_play)
	col.add_child(play)

	# ----- بطاقات الأنماط -----
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	var cards: Array = []
	cards.append(_card("friends", "تحدي الأصدقاء", "العب ضد صديقك", Color(0.18, 0.52, 1.0), _on_friends))
	cards.append(_card("bot", "ضد البوت", "تدريب بدون إنترنت", Color(0.15, 0.75, 0.42), _on_bot))
	cards.append(_card("bolt", "الأنماط", "6 أنماط مختلفة", Color(0.95, 0.3, 0.65), _on_modes))
	cards.append(_card("trophy", "المتصدرون", "قريباً", Color(0.95, 0.68, 0.08), _on_soon))
	for c in cards:
		grid.add_child(c)

	toast = UI.label("", 32, Color.WHITE, 0)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 140.0
	toast.offset_right = -140.0
	toast.offset_top = -250.0
	toast.offset_bottom = -180.0
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_stylebox_override("normal", UI.style(Color(0.1, 0.05, 0.3, 0.92), 30, 0))
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)

	# ----- ظهور متتابع -----
	var all: Array = [play]
	all.append_array(cards)
	for i in all.size():
		var b: Control = all[i]
		b.modulate.a = 0.0
		b.scale = Vector2(0.85, 0.85)
		var tw2 := create_tween()
		tw2.tween_interval(0.1 * float(i) + 0.1)
		tw2.tween_property(b, "modulate:a", 1.0, 0.3)
		tw2.parallel().tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == 0:
			tw2.finished.connect(_pulse.bind(b))

func _gear() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(84, 84)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := UI.style(Color(0.45, 0.3, 0.9), 36, 8)
	p.add_theme_stylebox_override("panel", sb)
	var cc := CenterContainer.new()
	p.add_child(cc)
	cc.add_child(NavBar.icon("gear", 46, Color.WHITE, Color(0.35, 0.2, 0.75)))
	p.add_child(NavBar.tap(_on_sound, p))
	return p

func _card(kind: String, ttl: String, sub: String, color: Color, cb: Callable) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 130)
	var sb := UI.style(color, 34, 10)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 18.0
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var ic := NavBar.icon(kind, 60, Color.WHITE, color.darkened(0.4))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(UI.label(ttl, 28, Color.WHITE, 8))
	v.add_child(UI.label(sub, 20, Color(1, 1, 1, 0.85), 0))
	p.add_child(NavBar.tap(cb, p))
	return p

func _pulse(b: Control) -> void:
	var p := create_tween().set_loops()
	p.tween_property(b, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	p.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

func _refresh_profile() -> void:
	if name_label == null:
		return
	var nm := "ضيف"
	var lv := 1
	var xp := 0
	var need := 40
	var pid := "0"
	if Net.logged_in():
		var p: Dictionary = Net.profile
		nm = str(p.get("name", ""))
		lv = int(p.get("level", 1))
		xp = int(p.get("xp", 0))
		need = int(p.get("need", 40))
		pid = str(p.get("id", "0"))
	else:
		var li := Data.level_info()
		lv = int(li.level)
		xp = int(li.xp)
		need = int(li.need)
	name_label.text = nm
	lvl_label.text = "م%d" % lv
	xp_bar.max_value = maxf(1.0, float(need))
	xp_bar.value = float(xp)
	av_letter.text = nm.substr(0, 1)
	var hue := float(int(pid) % 100) / 100.0
	av_panel.add_theme_stylebox_override("panel", UI.style(Color.from_hsv(hue, 0.6, 0.9), 38, 6))

func _process(delta: float) -> void:
	t += delta
	if tower:
		tower.queue_redraw()

func _block(x: float, y: float, w: float, h: float, c: Color) -> void:
	tower.draw_rect(Rect2(x + 4.0, y + 6.0, w, h), Color(0, 0, 0, 0.25))
	tower.draw_rect(Rect2(x, y, w, h), c)
	tower.draw_rect(Rect2(x, y, w, h * 0.28), c.lightened(0.35))
	tower.draw_rect(Rect2(x, y + h - 5.0, w, 5.0), c.darkened(0.25))

func _spark(p: Vector2, s: float, a: float) -> void:
	var c := Color(1, 1, 1, a)
	tower.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), c, 3.0)
	tower.draw_line(p - Vector2(0, s), p + Vector2(0, s), c, 3.0)
	tower.draw_circle(p, s * 0.35, c)

func _draw_tower() -> void:
	var sz := tower.size
	if sz.x < 10.0:
		return
	var bh := clampf(sz.y / 9.0, 24.0, 54.0)
	var widths := [270.0, 250.0, 262.0, 226.0, 210.0, 186.0, 160.0]
	var offs := [0.0, -10.0, 12.0, -6.0, 8.0, -4.0, 2.0]
	var cx := sz.x / 2.0
	var base := sz.y - 8.0
	tower.draw_rect(Rect2(cx - 200.0, base, 400.0, 8.0), Color(1, 1, 1, 0.2))
	for i in widths.size():
		var w: float = widths[i]
		var x := cx + float(offs[i]) + sin(t * 1.6 + float(i) * 0.7) * 5.0 - w / 2.0
		var y := base - float(i + 1) * bh
		_block(x, y, w, bh - 4.0, Data.block_color(i, fmod(t * 0.05, 1.0)))
	var topy := base - float(widths.size() + 1) * bh - 6.0 + sin(t * 4.0) * 3.0
	var sw := 150.0
	var sx := cx + sin(t * 2.0) * 120.0 - sw / 2.0
	_block(sx, topy, sw, bh - 4.0, Data.block_color(widths.size(), fmod(t * 0.12, 1.0)))
	for k in 6:
		var px := sz.x * (0.12 + 0.76 * fposmod(float(k) * 0.37, 1.0))
		var py := sz.y * (0.1 + 0.7 * fposmod(float(k) * 0.61, 1.0))
		_spark(Vector2(px, py), 7.0 + float(k % 3) * 3.0, 0.25 + 0.6 * (0.5 + 0.5 * sin(t * 2.2 + float(k))))

func _on_profile() -> void:
	if Net.logged_in():
		get_tree().change_scene_to_file("res://profile.tscn")
	else:
		get_tree().change_scene_to_file("res://login.tscn")

func _on_sound() -> void:
	Sfx.set_music(not Sfx.music_on)
	_say("الموسيقى: تشغيل" if Sfx.music_on else "الموسيقى: إيقاف")

func _on_play() -> void:
	Engine.set_meta("mode", "random")
	get_tree().change_scene_to_file("res://online.tscn")

func _on_friends() -> void:
	if Net.logged_in():
		get_tree().change_scene_to_file("res://social.tscn")
	else:
		get_tree().change_scene_to_file("res://friends.tscn")

func _on_bot() -> void:
	get_tree().change_scene_to_file("res://versus.tscn")

func _on_modes() -> void:
	get_tree().change_scene_to_file("res://modes.tscn")

func _on_soon() -> void:
	_say("قريباً...")

func _say(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
