extends Node2D

const ResultOverlay = preload("res://result_overlay.gd")
const PW = preload("res://powers.gd")
const PowerFx = preload("res://power_fx.gd")
const PowerHud = preload("res://power_hud.gd")
const W := 720.0
const TW := 360.0
const BLOCK_H := 48.0
const START_W := 150.0
const PERFECT_TOL := 8.0
const ROUND_TIME := 90.0
const CONNECT_TIMEOUT := 12.0
const GOLD := Color(1.0, 0.86, 0.2)
const RED := Color(1.0, 0.4, 0.45)
const ORANGE := Color(1.0, 0.65, 0.2)
const CYAN := Color(0.4, 0.9, 1.0)

class Tower:
	var blocks: Array = []
	var falling: Array = []
	var cur_x := 0.0
	var cur_w := 0.0
	var dir := 1.0
	var score := 0
	var combo := 0
	var cam := 0.0
	var dead := false
	var attack := 0
	var hit := false
	var shake := 0.0
	var ox := 0.0
	var hue := 0.0

var base_y := 1000.0
var vh := 1280.0
var player: Tower
var opp: Tower
var state := "connecting"
var mode := "random"
var code := ""
var opp_name := "الخصم"
var time_left := ROUND_TIME
var pos_t := 0.0
var msg_t := 0.0
var end_ms := 0
var connect_t := 0.0
var shake_t := 0.0
var flash := 0.0
var last_sec := -1
var fx_me = PowerFx.new()
var cool: Dictionary = {}
var grow_active := false

var ui: CanvasLayer
var hud: Control
var timer_label: Label
var opp_score: Label
var player_score: Label
var opp_name_label: Label
var msg_label: Label

func _ready() -> void:
	vh = get_viewport_rect().size.y
	base_y = vh - 215.0
	mode = str(Engine.get_meta("mode", "random"))
	code = str(Engine.get_meta("code", ""))

	player = Tower.new()
	player.ox = TW
	player.hue = 0.0
	opp = Tower.new()
	opp.ox = 0.0
	opp.hue = 0.5

	ui = CanvasLayer.new()
	add_child(ui)
	timer_label = _hud(0.0, 8.0, W, 84, Color.WHITE)
	opp_score = _hud(0.0, 120.0, TW, 110, CYAN)
	player_score = _hud(TW, 120.0, TW, 110, GOLD)
	opp_name_label = _hud(0.0, 250.0, TW, 32, Color(1, 1, 1, 0.85))
	opp_name_label.text = "الخصم"
	var me_label := _hud(TW, 250.0, TW, 32, Color(1, 1, 1, 0.85))
	me_label.text = str(Net.profile.get("name", "أنت")) if Net.logged_in() else "أنت"
	msg_label = _hud(0.0, 330.0, W, 48, Color.WHITE)

	var back := UI.button("القائمة", Color(0.45, 0.35, 0.85), 70, 26)
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.pressed.connect(_leave)
	ui.add_child(back)

	hud = PowerHud.new()
	ui.add_child(hud)
	hud.build(W, vh - 135.0)
	hud.pressed.connect(_use_power)
	hud.visible = false

	_init_tower(player)
	_init_tower(opp)

	Net.in_match_scene = true
	Net.message.connect(_on_msg)
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disc)

	if Net.start_pending:
		Net.start_pending = false
		var sm := Net.start_msg
		Net.start_msg = {}
		_start(sm)
	elif Net.is_open:
		_on_connected()
	else:
		msg_label.text = "جاري الاتصال..."

func _exit_tree() -> void:
	Net.in_match_scene = false

func _hud(x: float, y: float, w: float, fs: int, color: Color) -> Label:
	var l := UI.label("", fs, color, 12)
	l.position = Vector2(x, y)
	l.size = Vector2(w, fs + 30)
	ui.add_child(l)
	return l

func _pop(l: Label) -> void:
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.2)

func _fail(text: String) -> void:
	state = "offline"
	hud.visible = false
	end_ms = Time.get_ticks_msec()
	msg_label.size.y = 220.0
	msg_label.text = text + "\nالمس للمحاولة من جديد"

func _leave() -> void:
	Net.send({"t": "leave", "done": state == "over"})
	UI.go("res://main_menu.tscn")

func _again() -> void:
	if mode == "random":
		get_tree().reload_current_scene()
	else:
		UI.go("res://friends.tscn")

func _init_tower(t: Tower) -> void:
	t.blocks.clear()
	t.falling.clear()
	t.blocks.append({"x": (TW - START_W) / 2.0, "w": START_W, "c": _color(t, 0)})
	t.score = 0
	t.combo = 0
	t.cam = 0.0
	t.dead = false
	t.attack = 0
	t.shake = 0.0
	t.hit = false
	if t == player:
		_spawn(t, START_W)
	else:
		t.cur_w = START_W
		t.cur_x = (TW - START_W) / 2.0

func _color(t: Tower, i: int) -> Color:
	return Data.block_color(i, t.hue)

func _spawn(t: Tower, w: float) -> void:
	t.cur_w = w
	t.hit = false
	if t.attack > 0:
		t.attack -= 1
		t.hit = true
		t.cur_w = maxf(40.0, w * 0.8)
		t.shake = 0.5
	if t.score % 2 == 0:
		t.cur_x = 0.0
		t.dir = 1.0
	else:
		t.cur_x = TW - t.cur_w
		t.dir = -1.0

func _speed(t: Tower) -> float:
	var s := 180.0 + minf(t.score * 6.0, 260.0)
	if t.hit:
		s *= 1.5
	if t == player:
		s *= fx_me.speed_mult()
	return s

func _say(text: String, secs: float, color: Color = Color.WHITE) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	msg_t = secs

func _hit_fx() -> void:
	shake_t = 0.45
	flash = 1.0
	Sfx.hit()
	Input.vibrate_handheld(200)

func _update_ui() -> void:
	var ps := str(player.score)
	if player_score.text != ps:
		player_score.text = ps
		_pop(player_score)
	var oss := str(opp.score)
	if opp_score.text != oss:
		opp_score.text = oss
		_pop(opp_score)

# ---------- القدرات ----------

func _grow_block(t: Tower) -> void:
	var nw := minf(t.cur_w * 1.8, TW)
	t.cur_x = clampf(t.cur_x - (nw - t.cur_w) / 2.0, 0.0, TW - nw)
	t.cur_w = nw

func _narrow_block(t: Tower) -> void:
	var nw := maxf(40.0, t.cur_w * 0.62)
	t.cur_x += (t.cur_w - nw) / 2.0
	t.cur_w = nw

func _use_power(id: String) -> void:
	if state != "playing" or player.dead:
		return
	var d: Dictionary = PW.def(id)
	if d.is_empty():
		return
	if PW.count(id) <= 0:
		Sfx.hit()
		_say("انتهت هذه القدرة، اشترِ المزيد من القدرات", 1.6, RED)
		return
	if str(d.kind) == "self":
		if fx_me.active(id) or (id == "grow" and grow_active):
			_say("مفعّلة بالفعل", 1.0, ORANGE)
			return
		PW.use(id)
		if id == "grow":
			grow_active = true
			_grow_block(player)
		else:
			fx_me.start(id)
	else:
		if float(cool.get(id, 0.0)) > 0.0:
			return
		PW.use(id)
		cool[id] = 3.0
		Net.send({"t": "pw", "id": id})
	Sfx.perfect()
	_say("استخدمت: %s" % str(d.name), 1.2, GOLD)

func _receive_power(id: String) -> void:
	var d: Dictionary = PW.def(id)
	if d.is_empty() or str(d.kind) != "enemy":
		return
	if fx_me.shield:
		fx_me.shield = false
		Sfx.perfect()
		_say("درعك صدّ قدرة الخصم!", 1.6, CYAN)
		return
	if id == "narrow":
		_narrow_block(player)
	else:
		fx_me.start(id)
	_hit_fx()
	_say("الخصم استخدم: %s" % str(d.name), 1.6, RED)

# ---------- الشبكة ----------

func _start(m: Dictionary) -> void:
	var info = m.get("opp", {})
	if typeof(info) == TYPE_DICTIONARY:
		opp_name = str(info.get("name", "الخصم"))
		opp_name_label.text = "%s (م%d)" % [opp_name, int(info.get("level", 1))]
	_init_tower(player)
	_init_tower(opp)
	fx_me = PowerFx.new()
	cool = {}
	grow_active = false
	hud.visible = true
	time_left = ROUND_TIME
	last_sec = -1
	state = "playing"
	msg_label.size.y = 100.0
	_say("ابدأ! المس لإنزال الكتلة", 2.0, GOLD)
	Sfx.perfect()
	_update_ui()

func _on_connected() -> void:
	if state != "connecting":
		return
	state = "waiting"
	if mode == "create":
		Net.send({"t": "create"})
		msg_label.text = "جاري إنشاء اللعبة..."
	elif mode == "join":
		Net.send({"t": "join", "code": code})
		msg_label.text = "جاري الدخول..."
	else:
		Net.send({"t": "find"})
		msg_label.text = "نبحث عن خصم..."

func _on_disc() -> void:
	if state == "over" or state == "offline" or state == "error":
		return
	_fail("انقطع الاتصال")

func _on_msg(m: Dictionary) -> void:
	var t: String = str(m.get("t", ""))
	if t == "waiting":
		msg_label.text = "نبحث عن خصم..."
	elif t == "created":
		msg_label.size.y = 260.0
		msg_label.add_theme_color_override("font_color", GOLD)
		msg_label.text = "كود اللعبة: %s\nأعطه لصاحبك وانتظره" % str(m.get("code", ""))
	elif t == "error":
		state = "error"
		end_ms = Time.get_ticks_msec()
		msg_label.size.y = 200.0
		msg_label.text = "%s\nالمس للرجوع" % str(m.get("m", "خطأ"))
	elif t == "start":
		_start(m)
	elif state != "playing":
		return
	elif t == "drop":
		opp.blocks.append({"x": float(m["x"]), "w": float(m["w"]), "c": _color(opp, opp.blocks.size())})
		opp.score += 1
		_update_ui()
	elif t == "pos":
		opp.cur_x = float(m["x"])
		opp.cur_w = float(m["w"])
		opp.hit = bool(m["h"])
	elif t == "atk":
		if fx_me.shield:
			fx_me.shield = false
			Sfx.perfect()
			_say("درعك صدّ الهجوم!", 1.4, CYAN)
		else:
			player.attack += 1
			_hit_fx()
			_say("الخصم هاجمك!", 1.3, RED)
	elif t == "pw":
		_receive_power(str(m.get("id", "")))
	elif t == "dead":
		opp.dead = true
		_say("سقط برج الخصم!", 2.0, GOLD)
		_check_end()
	elif t == "left":
		_end(1, "الخصم انسحب")

func _fx(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		var k := clampf(shake_t / 0.45, 0.0, 1.0)
		position = Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)) * k
	else:
		position = Vector2.ZERO
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 2.5)

func _process(delta: float) -> void:
	_fx(delta)
	if state == "offline" or state == "error":
		_anim(player, delta)
		_anim(opp, delta)
		queue_redraw()
		return

	if state == "connecting":
		connect_t += delta
		if connect_t > CONNECT_TIMEOUT:
			_fail("تعذر الاتصال بالخادم\nتأكد من الإنترنت")

	if state == "playing":
		time_left -= delta
		fx_me.tick(delta)
		for k in cool.keys():
			cool[k] = maxf(0.0, float(cool[k]) - delta)
		hud.refresh(fx_me, cool)
		if not player.dead:
			_move(player, delta)
			pos_t -= delta
			if pos_t <= 0.0:
				pos_t = 0.1
				Net.send({"t": "pos", "x": player.cur_x, "w": player.cur_w, "h": player.hit})
		_check_end()
		var secs := int(ceil(maxf(time_left, 0.0)))
		timer_label.text = str(secs)
		timer_label.add_theme_color_override("font_color", RED if secs <= 10 else Color.WHITE)
		if secs != last_sec:
			last_sec = secs
			if secs <= 5 and secs > 0:
				Sfx.click()
				_pop(timer_label)

	_anim(player, delta)
	_anim(opp, delta)

	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0 and state == "playing":
			msg_label.text = ""
	queue_redraw()

func _move(t: Tower, delta: float) -> void:
	t.cur_x += t.dir * _speed(t) * delta
	if t.cur_x < 0.0:
		t.cur_x = 0.0
		t.dir = 1.0
	elif t.cur_x + t.cur_w > TW:
		t.cur_x = TW - t.cur_w
		t.dir = -1.0

func _anim(t: Tower, delta: float) -> void:
	var target_cam := maxf(0.0, (t.blocks.size() - 12) * BLOCK_H)
	t.cam = lerpf(t.cam, target_cam, minf(1.0, 6.0 * delta))
	for p in t.falling:
		p.vy += 1800.0 * delta
		p.y += p.vy * delta
	t.falling = t.falling.filter(func(p): return p.y + t.cam < vh + 200.0)
	if t.shake > 0.0:
		t.shake -= delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if state == "playing":
			if not player.dead:
				_drop()
		elif state == "error" or state == "offline":
			if Time.get_ticks_msec() - end_ms > 700:
				if state == "error":
					UI.go("res://friends.tscn")
				else:
					get_tree().reload_current_scene()

func _spawn_fall(t: Tower, x: float, y: float, w: float, c: Color) -> void:
	if w > 0.5:
		t.falling.append({"x": x, "y": y, "w": w, "vy": 0.0, "c": c})

func _drop() -> void:
	var t := player
	var top: Dictionary = t.blocks.back()
	if fx_me.magnet:
		fx_me.magnet = false
		t.cur_x = clampf(top.x + top.w / 2.0 - t.cur_w / 2.0, 0.0, TW - t.cur_w)
	var y := base_y - t.blocks.size() * BLOCK_H
	var col := _color(t, t.blocks.size())
	var left := maxf(t.cur_x, top.x)
	var right := minf(t.cur_x + t.cur_w, top.x + top.w)
	var ow := right - left

	if ow <= 0.0:
		_spawn_fall(t, t.cur_x, y, t.cur_w, col)
		t.dead = true
		grow_active = false
		hud.visible = false
		Sfx.hit()
		Net.send({"t": "dead"})
		_say("سقط برجك! ننتظر الخصم", 3.0, RED)
		_check_end()
		return

	var nx := left
	var nw := ow
	var cd: float = (t.cur_x + t.cur_w / 2.0) - (top.x + top.w / 2.0)

	if absf(cd) <= PERFECT_TOL:
		t.combo += 1
		nw = t.cur_w
		nx = top.x + top.w / 2.0 - nw / 2.0
		if t.combo >= 3:
			var grown := minf(nw + 8.0, START_W)
			nx -= (grown - nw) / 2.0
			nw = grown
			nx = clampf(nx, 0.0, TW - nw)
		Sfx.perfect()
		_say("مضبوط! x%d" % t.combo, 0.9, GOLD)
		if t.combo % 3 == 0:
			Net.send({"t": "atk"})
			_say("هجوم على الخصم!", 1.3, ORANGE)
	else:
		t.combo = 0
		Sfx.drop()
		if t.cur_x < top.x:
			_spawn_fall(t, t.cur_x, y, left - t.cur_x, col)
		else:
			_spawn_fall(t, right, y, (t.cur_x + t.cur_w) - right, col)

	if grow_active:
		grow_active = false
		if nw > top.w:
			nx += (nw - top.w) / 2.0
			nw = top.w

	t.blocks.append({"x": nx, "w": nw, "c": col})
	t.score += 1
	Net.send({"t": "drop", "x": nx, "w": nw})
	_spawn(t, nw)
	_update_ui()

func _check_end() -> void:
	if state != "playing":
		return
	if time_left <= 0.0:
		_finish_by_score("انتهى الوقت")
	elif player.dead and opp.dead:
		_finish_by_score("سقط البرجان")
	elif opp.dead and player.score > opp.score:
		_end(1, "سقط برج الخصم")
	elif player.dead and opp.score > player.score:
		_end(-1, "سقط برجك")

func _finish_by_score(reason: String) -> void:
	if player.score > opp.score:
		_end(1, reason)
	elif player.score < opp.score:
		_end(-1, reason)
	else:
		_end(0, reason)

func _end(result: int, reason: String) -> void:
	if state == "over":
		return
	state = "over"
	hud.visible = false
	end_ms = Time.get_ticks_msec()
	msg_t = 0.0
	msg_label.text = ""
	Net.send({"t": "result", "r": result})
	Net.send({"t": "leave", "done": true})
	var title := "تعادل"
	var col := CYAN
	if result > 0:
		title = "فزت!"
		col = GOLD
		Sfx.win()
	elif result < 0:
		title = "خسرت"
		col = RED
		Sfx.lose()
	else:
		Sfx.click()
	var again_text := "العب مرة ثانية" if mode == "random" else "تحدٍّ جديد"
	var ov := ResultOverlay.new()
	add_child(ov)
	ov.build(title, reason, col, player.score, opp.score, opp_name, again_text)
	ov.again_pressed.connect(_again)
	ov.menu_pressed.connect(_leave)

func _draw() -> void:
	draw_line(Vector2(TW, 0), Vector2(TW, vh), Color(1, 1, 1, 0.25), 3.0)
	_draw_tower(player)
	_draw_tower(opp)
	if flash > 0.0:
		draw_rect(Rect2(-40, -40, W + 80, vh + 80), Color(1.0, 0.1, 0.1, flash * 0.3))

func _draw_fx_outline(r: Rect2) -> void:
	var oc := Color(0, 0, 0, 0)
	if fx_me.active("slow"):
		oc = Color(0.4, 0.85, 1.0)
	elif fx_me.active("fast") or fx_me.active("jitter"):
		oc = Color(1.0, 0.6, 0.2)
	elif fx_me.magnet:
		oc = Color(0.75, 0.5, 1.0)
	elif grow_active:
		oc = Color(0.4, 1.0, 0.55)
	if oc.a > 0.0:
		draw_rect(r.grow(4.0), oc, false, 4.0)

func _draw_fog(ox: float, y2: float) -> void:
	var a := clampf(float(fx_me.timers["fog"]) / 0.5, 0.0, 1.0) * 0.9
	draw_rect(Rect2(ox, y2 - 120.0, TW, 230.0), Color(0.78, 0.86, 1.0, a))
	for i in 5:
		var cx := ox + fposmod(float(i) * 97.0 + fx_me.clock * 34.0, TW)
		draw_circle(Vector2(cx, y2 - 40.0 + float(i) * 22.0), 62.0, Color(1, 1, 1, a * 0.55))

func _draw_tower(t: Tower) -> void:
	var sx := 0.0
	if t.shake > 0.0:
		sx = randf_range(-6.0, 6.0)
	var ox := t.ox + sx
	for i in t.blocks.size():
		var b: Dictionary = t.blocks[i]
		var y := base_y - i * BLOCK_H + t.cam
		if y > vh + 100.0 or y < -100.0:
			continue
		draw_rect(Rect2(ox + b.x, y, b.w, BLOCK_H - 3.0), b.c)
		draw_rect(Rect2(ox + b.x, y, b.w, 6.0), b.c.lightened(0.3))
	for p in t.falling:
		draw_rect(Rect2(ox + p.x, p.y + t.cam, p.w, BLOCK_H - 3.0), p.c)
	if not t.dead and state == "playing":
		var y2 := base_y - t.blocks.size() * BLOCK_H + t.cam
		var c := _color(t, t.blocks.size())
		if t.hit:
			c = Color(1.0, 0.25, 0.25)
		var r := Rect2(ox + t.cur_x, y2, t.cur_w, BLOCK_H - 3.0)
		draw_rect(r, c)
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, 6.0), c.lightened(0.3))
		if t == player:
			_draw_fx_outline(r)
			if fx_me.active("fog"):
				_draw_fog(ox, y2)
