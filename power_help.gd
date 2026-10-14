extends CanvasLayer

const PW = preload("res://powers.gd")
const PowerIcon = preload("res://power_icon.gd")
const DW := 560.0
const DH := 400.0
const CYCLE := 5.0
const CX_EN := 150.0
const CX_ME := 410.0
const BASE := 290.0
const GOLD := Color(1.0, 0.86, 0.2)

var pid := "slow"
var d: Dictionary = {}
var demo: Control
var icon
var pop: Label
var t := 0.0
var ph_me := 0.0
var ph_en := 1.7

func _init() -> void:
	layer = 60

func open(id: String) -> void:
	pid = id
	d = PW.def(id)
	if d.is_empty():
		queue_free()
		return
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.12, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var sb := UI.style(Color(0.14, 0.09, 0.42, 0.98), 44, 12)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 28.0
	sb.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var kind_text := "تقوية لنفسك" if str(d.kind) == "self" else "هجوم على الخصم"
	var kind_col := Color(0.4, 1.0, 0.6) if str(d.kind) == "self" else Color(1.0, 0.5, 0.5)
	vb.add_child(UI.label(str(d.name), 54, GOLD, 12))
	vb.add_child(UI.label(kind_text, 28, kind_col, 6))

	demo = Control.new()
	demo.custom_minimum_size = Vector2(DW, DH)
	demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo.draw.connect(_draw_demo)
	vb.add_child(demo)

	var le := UI.label("الخصم", 26, Color(0.75, 0.95, 1.0), 6)
	le.position = Vector2(CX_EN - 90.0, 10.0)
	le.size = Vector2(180, 40)
	demo.add_child(le)
	var lm := UI.label("أنت", 26, GOLD, 6)
	lm.position = Vector2(CX_ME - 90.0, 10.0)
	lm.size = Vector2(180, 40)
	demo.add_child(lm)
	pop = UI.label(str(d.pop), 34, GOLD, 8)
	pop.position = Vector2(0, 46)
	pop.size = Vector2(DW, 50)
	demo.add_child(pop)

	icon = PowerIcon.new()
	icon.pid = id
	icon.enabled = true
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(DW / 2.0 - 42.0, DH - 96.0)
	icon.size = Vector2(84, 84)
	icon.pivot_offset = Vector2(42, 42)
	demo.add_child(icon)

	vb.add_child(UI.label(str(d.how), 28, Color.WHITE, 6))
	var close := UI.button("حسناً", Color(0.15, 0.75, 0.42), 96, 36)
	close.pressed.connect(queue_free)
	vb.add_child(close)

	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if demo == null:
		return
	t += delta
	var cyc := fmod(t, CYCLE)
	var act := cyc >= 1.3 and cyc < 4.3
	var sp_me := 4.0
	var sp_en := 4.0
	if pid == "slow":
		sp_me = 2.0 if act else 7.0
	elif pid == "fast":
		sp_en = 9.0 if act else 3.0
	elif pid == "jitter":
		sp_en = 3.0 + (7.0 * absf(sin(t * 9.0)) if act else 0.0)
	ph_me += delta * sp_me
	ph_en += delta * sp_en
	var pulse := clampf(1.0 - absf(cyc - 1.15) / 0.25, 0.0, 1.0)
	icon.scale = Vector2.ONE * (1.0 + 0.3 * pulse)
	pop.visible = act
	demo.queue_redraw()

func _blk(x: float, y: float, w: float, h: float, c: Color) -> void:
	demo.draw_rect(Rect2(x + 3.0, y + 4.0, w, h), Color(0, 0, 0, 0.28))
	demo.draw_rect(Rect2(x, y, w, h), c)
	demo.draw_rect(Rect2(x, y, w, h * 0.28), c.lightened(0.35))

func _stack(cx: float, hue: float) -> void:
	demo.draw_rect(Rect2(cx - 95.0, BASE + 2.0, 190.0, 6.0), Color(1, 1, 1, 0.25))
	for i in 4:
		var w := 120.0 - float(i) * 12.0
		var y := BASE - float(i + 1) * 32.0
		var c := Color.from_hsv(fposmod(hue + float(i) * 0.05, 1.0), 0.65, 0.95)
		_blk(cx - w / 2.0, y, w, 29.0, c)

func _attack_arrow(x: float, a: float) -> void:
	var y := BASE - 80.0
	var c := Color(1.0, 0.3, 0.3, a)
	demo.draw_line(Vector2(x - 56.0, y), Vector2(x, y), c, 8.0)
	demo.draw_colored_polygon(PackedVector2Array([Vector2(x + 18.0, y), Vector2(x - 4.0, y - 16.0), Vector2(x - 4.0, y + 16.0)]), c)

func _draw_demo() -> void:
	var cyc := fmod(t, CYCLE)
	var act := cyc >= 1.3 and cyc < 4.3
	var k := 0.0
	if act:
		k = clampf((cyc - 1.3) / 0.35, 0.0, 1.0)
	elif cyc >= 4.3:
		k = clampf(1.0 - (cyc - 4.3) / 0.35, 0.0, 1.0)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.2, 0.95)
	bg.set_corner_radius_all(28)
	demo.draw_style_box(bg, Rect2(0, 0, DW, DH))

	_stack(CX_EN, 0.55)
	_stack(CX_ME, 0.0)

	var y_mv := BASE - 4.0 * 32.0 - 34.0
	var w_en := 100.0
	var w_me := 100.0
	if pid == "grow":
		w_me = lerpf(80.0, 170.0, k)
	if pid == "narrow":
		w_en = lerpf(110.0, 62.0, k)
	var x_en := CX_EN + sin(ph_en) * 58.0
	var x_me := CX_ME + sin(ph_me) * 58.0
	if pid == "magnet":
		x_me = lerpf(x_me, CX_ME, k)

	_blk(x_en - w_en / 2.0, y_mv, w_en, 30.0, Color.from_hsv(0.55, 0.65, 0.95))
	_blk(x_me - w_me / 2.0, y_mv, w_me, 30.0, Color.from_hsv(0.0, 0.65, 0.95))

	var bar_cx := CX_ME
	var show_bar := false
	match pid:
		"slow":
			show_bar = true
			if act:
				demo.draw_rect(Rect2(x_me - w_me / 2.0 - 4.0, y_mv - 4.0, w_me + 8.0, 38.0), Color(0.4, 0.85, 1.0), false, 4.0)
		"grow":
			if act:
				demo.draw_rect(Rect2(x_me - w_me / 2.0 - 4.0, y_mv - 4.0, w_me + 8.0, 38.0), Color(0.4, 1.0, 0.55), false, 4.0)
		"magnet":
			if k > 0.0:
				for i in 3:
					demo.draw_arc(Vector2(x_me, y_mv - 8.0), 18.0 + float(i) * 14.0 + fmod(t * 40.0, 14.0), PI * 1.15, PI * 1.85, 12, Color(0.8, 0.55, 1.0, 0.75 - float(i) * 0.2), 4.0)
				demo.draw_rect(Rect2(x_me - w_me / 2.0 - 4.0, y_mv - 4.0, w_me + 8.0, 38.0), Color(0.75, 0.5, 1.0), false, 4.0)
		"shield":
			var hx := CX_ME - 62.0
			if cyc >= 1.0 and cyc < 2.4:
				_attack_arrow(lerpf(CX_EN + 70.0, hx, (cyc - 1.0) / 1.4), 1.0)
			elif cyc >= 2.4 and cyc < 3.4:
				var p2 := cyc - 2.4
				_attack_arrow(lerpf(hx, hx - 140.0, p2), 1.0 - p2)
			if cyc >= 1.3 and cyc < 4.0:
				var a := clampf((cyc - 1.3) / 0.3, 0.0, 1.0)
				demo.draw_circle(Vector2(CX_ME, BASE - 80.0), 112.0, Color(0.4, 0.75, 1.0, 0.16 * a))
				demo.draw_arc(Vector2(CX_ME, BASE - 80.0), 112.0, 0.0, TAU, 48, Color(0.5, 0.85, 1.0, 0.85 * a), 6.0)
		"fast":
			show_bar = true
			bar_cx = CX_EN
			if act:
				demo.draw_rect(Rect2(x_en - w_en / 2.0 - 4.0, y_mv - 4.0, w_en + 8.0, 38.0), Color(1.0, 0.6, 0.2), false, 4.0)
				var dir := signf(cos(ph_en))
				for i in 3:
					var lx := x_en - dir * (w_en / 2.0 + 12.0 + float(i) * 16.0)
					demo.draw_line(Vector2(lx, y_mv + 6.0 + float(i) * 9.0), Vector2(lx - dir * 22.0, y_mv + 6.0 + float(i) * 9.0), Color(1.0, 0.7, 0.3, 0.8), 4.0)
		"narrow":
			if k > 0.0:
				var pc := Color(0.95, 0.35, 0.65, k)
				var lt := x_en - w_en / 2.0 - 6.0
				var rt := x_en + w_en / 2.0 + 6.0
				demo.draw_colored_polygon(PackedVector2Array([Vector2(lt, y_mv + 15.0), Vector2(lt - 18.0, y_mv + 2.0), Vector2(lt - 18.0, y_mv + 28.0)]), pc)
				demo.draw_colored_polygon(PackedVector2Array([Vector2(rt, y_mv + 15.0), Vector2(rt + 18.0, y_mv + 2.0), Vector2(rt + 18.0, y_mv + 28.0)]), pc)
		"fog":
			show_bar = true
			bar_cx = CX_EN
			if k > 0.0:
				demo.draw_rect(Rect2(CX_EN - 100.0, y_mv - 50.0, 200.0, 160.0), Color(0.78, 0.86, 1.0, 0.88 * k))
				for i in 4:
					var fx := CX_EN - 80.0 + fposmod(float(i) * 61.0 + t * 30.0, 160.0)
					demo.draw_circle(Vector2(fx, y_mv - 10.0 + float(i) * 22.0), 44.0, Color(1, 1, 1, 0.5 * k))
		"jitter":
			show_bar = true
			bar_cx = CX_EN
			if act:
				demo.draw_rect(Rect2(x_en - w_en / 2.0 - 4.0, y_mv - 4.0, w_en + 8.0, 38.0), Color(1.0, 0.8, 0.2), false, 4.0)
				var zz := PackedVector2Array()
				for i in 7:
					zz.append(Vector2(x_en - 42.0 + float(i) * 14.0, y_mv - 16.0 + (10.0 if i % 2 == 0 else -2.0)))
				demo.draw_polyline(zz, Color(1.0, 0.85, 0.3), 4.0)

	if show_bar and act:
		var fr := clampf(1.0 - (cyc - 1.3) / 3.0, 0.0, 1.0)
		demo.draw_rect(Rect2(bar_cx - 80.0, 98.0, 160.0, 10.0), Color(1, 1, 1, 0.2))
		demo.draw_rect(Rect2(bar_cx - 80.0, 98.0, 160.0 * fr, 10.0), GOLD)

	var ic := Vector2(DW / 2.0, DH - 54.0)
	if cyc >= 1.0 and cyc < 1.4:
		var p := (cyc - 1.0) / 0.4
		demo.draw_arc(ic, 44.0 + p * 34.0, 0.0, TAU, 32, Color(1, 1, 1, 1.0 - p), 4.0)
