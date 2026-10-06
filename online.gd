extends Node2D

const SERVER_URL := "wss://towerwars-ios-production.up.railway.app"
const ResultOverlay = preload("res://result_overlay.gd")
const W := 720.0
const TW := 360.0
const BLOCK_H := 48.0
const START_W := 150.0
const PERFECT_TOL := 8.0
const ROUND_TIME := 90.0
const CONNECT_TIMEOUT := 10.0
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

var base_y := 1100.0
var vh := 1280.0
var player: Tower
var opp: Tower
var ws := WebSocketPeer.new()
var state := "connecting"
var mode := "random"
var code := ""
var time_left := ROUND_TIME
var pos_t := 0.0
var msg_t := 0.0
var end_ms := 0
var connect_t := 0.0
var shake_t := 0.0
var flash := 0.0
var last_sec := -1

var ui: CanvasLayer
var timer_label: Label
var opp_score: Label
var player_score: Label
var msg_label: Label

func _ready() -> void:
	vh = get_viewport_rect().size.y
	base_y = vh - 160.0
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
	_hud(0.0, 250.0, TW, 32, Color(1, 1, 1, 0.85)).text = "الخصم"
	_hud(TW, 250.0, TW, 32, Color(1, 1, 1, 0.85)).text = "أنت"
	msg_label = _hud(0.0, 330.0, W, 48, Color.WHITE)

	var back := UI.button("القائمة", Color(0.45, 0.35, 0.85), 70, 26)
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.pressed.connect(_leave)
	ui.add_child(back)

	_init_tower(player)
	_init_tower(opp)

	if SERVER_URL.contains("CHANGE-ME"):
		_fail("لم تضع دومين الخادم\nعدّل SERVER_URL في online.gd")
		return

	msg_label.text = "جاري الاتصال..."
	var err := ws.connect_to_url(SERVER_URL)
	if err != OK:
		_fail("تعذر الاتصال بالخادم\nرمز الخطأ: %d" % err)

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
	end_ms = Time.get_ticks_msec()
	msg_label.size.y = 220.0
	msg_label.text = text + "\nالمس للمحاولة من جديد"

func _leave() -> void:
	ws.close()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _again() -> void:
	if mode == "random":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://friends.tscn")

func _send(d: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(d))

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
	return Color.from_hsv(fmod(t.hue + i * 0.045, 1.0), 0.65, 0.95)

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

func _start() -> void:
	_init_tower(player)
	_init_tower(opp)
	time_left = ROUND_TIME
	last_sec = -1
	state = "playing"
	msg_label.size.y = 100.0
	_say("ابدأ! المس لإنزال الكتلة", 2.0, GOLD)
	Sfx.perfect()
	_update_ui()

func _on_open() -> void:
	state = "waiting"
	if mode == "create":
		_send({"t": "create"})
		msg_label.text = "جاري إنشاء اللعبة..."
	elif mode == "join":
		_send({"t": "join", "code": code})
		msg_label.text = "جاري الدخول..."
	else:
		_send({"t": "find"})
		msg_label.text = "نبحث عن خصم..."

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
		ws.close()
	elif t == "start":
		_start()
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
		player.attack += 1
		_hit_fx()
		_say("الخصم هاجمك!", 1.3, RED)
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

	ws.poll()
	var st := ws.get_ready_state()

	if st == WebSocketPeer.STATE_OPEN:
		if state == "connecting":
			_on_open()
		while ws.get_available_packet_count() > 0:
			var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if typeof(m) == TYPE_DICTIONARY:
				_on_msg(m)
	elif st == WebSocketPeer.STATE_CONNECTING:
		connect_t += delta
		if connect_t > CONNECT_TIMEOUT:
			ws.close()
			_fail("الخادم لا يستجيب\nتأكد من الدومين و Railway")
	elif st == WebSocketPeer.STATE_CLOSED and state != "over":
		var reason := "انقطع الاتصال"
		if state == "connecting":
			reason = "تعذر الاتصال بالخادم\nرمز الإغلاق: %d" % ws.get_close_code()
		_fail(reason)

	if state == "playing":
		time_left -= delta
		if not player.dead:
			_move(player, delta)
			pos_t -= delta
			if pos_t <= 0.0:
				pos_t = 0.1
				_send({"t": "pos", "x": player.cur_x, "w": player.cur_w, "h": player.hit})
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
					get_tree().change_scene_to_file("res://friends.tscn")
				else:
					get_tree().reload_current_scene()

func _spawn_fall(t: Tower, x: float, y: float, w: float, c: Color) -> void:
	if w > 0.5:
		t.falling.append({"x": x, "y": y, "w": w, "vy": 0.0, "c": c})

func _drop() -> void:
	var t := player
	var top: Dictionary = t.blocks.back()
	var y := base_y - t.blocks.size() * BLOCK_H
	var col := _color(t, t.blocks.size())
	var left := maxf(t.cur_x, top.x)
	var right := minf(t.cur_x + t.cur_w, top.x + top.w)
	var ow := right - left

	if ow <= 0.0:
		_spawn_fall(t, t.cur_x, y, t.cur_w, col)
		t.dead = true
		Sfx.hit()
		_send({"t": "dead"})
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
			_send({"t": "atk"})
			_say("هجوم على الخصم!", 1.3, ORANGE)
	else:
		t.combo = 0
		Sfx.drop()
		if t.cur_x < top.x:
			_spawn_fall(t, t.cur_x, y, left - t.cur_x, col)
		else:
			_spawn_fall(t, right, y, (t.cur_x + t.cur_w) - right, col)

	t.blocks.append({"x": nx, "w": nw, "c": col})
	t.score += 1
	_send({"t": "drop", "x": nx, "w": nw})
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
	end_ms = Time.get_ticks_msec()
	msg_t = 0.0
	msg_label.text = ""
	ws.close()
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
	ov.build(title, reason, col, player.score, opp.score, "الخصم", again_text)
	ov.again_pressed.connect(_again)
	ov.menu_pressed.connect(_leave)

func _draw() -> void:
	draw_line(Vector2(TW, 0), Vector2(TW, vh), Color(1, 1, 1, 0.25), 3.0)
	_draw_tower(player)
	_draw_tower(opp)
	if flash > 0.0:
		draw_rect(Rect2(-40, -40, W + 80, vh + 80), Color(1.0, 0.1, 0.1, flash * 0.3))

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
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, BLOCK_H - 3.0), c)
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, 6.0), c.lightened(0.3))
