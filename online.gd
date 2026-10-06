extends Node2D

const SERVER_URL := "wss://CHANGE-ME.up.railway.app"
const W := 720.0
const TW := 360.0
const BLOCK_H := 48.0
const START_W := 150.0
const PERFECT_TOL := 8.0
const ROUND_TIME := 90.0

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
var time_left := ROUND_TIME
var pos_t := 0.0
var msg_t := 0.0
var end_ms := 0

var timer_label: Label
var opp_score: Label
var player_score: Label
var msg_label: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.1, 0.25))
	vh = get_viewport_rect().size.y
	base_y = vh - 160.0

	player = Tower.new()
	player.ox = TW
	player.hue = 0.0
	opp = Tower.new()
	opp.ox = 0.0
	opp.hue = 0.5

	var ui := CanvasLayer.new()
	add_child(ui)
	timer_label = _label(ui, 0.0, 20.0, W, 56)
	opp_score = _label(ui, 0.0, 100.0, TW, 64)
	player_score = _label(ui, TW, 100.0, TW, 64)
	_label(ui, 0.0, 190.0, TW, 28).text = "الخصم"
	_label(ui, TW, 190.0, TW, 28).text = "أنت"
	msg_label = _label(ui, 0.0, 260.0, W, 40)

	var back := Button.new()
	back.text = "القائمة"
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_leave)
	ui.add_child(back)

	_init_tower(player)
	_init_tower(opp)
	timer_label.text = ""
	msg_label.text = "جاري الاتصال..."
	var err := ws.connect_to_url(SERVER_URL)
	if err != OK:
		state = "offline"
		msg_label.text = "تعذر الاتصال بالخادم"

func _leave() -> void:
	ws.close()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _label(parent: Node, x: float, y: float, w: float, fs: int) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.size = Vector2(w, fs + 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	parent.add_child(l)
	return l

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

func _say(text: String, secs: float) -> void:
	msg_label.text = text
	msg_t = secs

func _update_ui() -> void:
	player_score.text = str(player.score)
	opp_score.text = str(opp.score)

func _start() -> void:
	_init_tower(player)
	_init_tower(opp)
	time_left = ROUND_TIME
	state = "playing"
	msg_label.size.y = 80.0
	_say("ابدأ! المس لإنزال الكتلة", 2.0)
	_update_ui()

func _on_msg(m: Dictionary) -> void:
	var t: String = str(m.get("t", ""))
	if t == "waiting":
		msg_label.text = "نبحث عن خصم..."
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
		_say("الخصم هاجمك!", 1.2)
	elif t == "dead":
		opp.dead = true
		_check_end()
	elif t == "left":
		_end("الخصم انسحب: فزت!")

func _process(delta: float) -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if state == "connecting":
			state = "waiting"
			_send({"t": "find"})
			msg_label.text = "نبحث عن خصم..."
		while ws.get_available_packet_count() > 0:
			var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if typeof(m) == TYPE_DICTIONARY:
				_on_msg(m)
	elif st == WebSocketPeer.STATE_CLOSED and state != "over" and state != "offline":
		state = "offline"
		end_ms = Time.get_ticks_msec()
		msg_label.size.y = 160.0
		msg_label.text = "انقطع الاتصال\nالمس للمحاولة من جديد"

	if state == "playing":
		time_left -= delta
		if not player.dead:
			_move(player, delta)
			pos_t -= delta
			if pos_t <= 0.0:
				pos_t = 0.1
				_send({"t": "pos", "x": player.cur_x, "w": player.cur_w, "h": player.hit})
		_check_end()
		timer_label.text = str(int(ceil(maxf(time_left, 0.0))))

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
		elif state == "over" or state == "offline":
			if Time.get_ticks_msec() - end_ms > 700:
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
		_send({"t": "dead"})
		_say("سقط برجك! ننتظر الخصم", 3.0)
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
		if t.combo % 3 == 0:
			_send({"t": "atk"})
			_say("هجوم على الخصم!", 1.2)
	else:
		t.combo = 0
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
	if time_left <= 0.0 or (player.dead and opp.dead):
		_finish_by_score("انتهت الجولة: ")
	elif opp.dead and player.score > opp.score:
		_end("فزت!")
	elif player.dead and opp.score > player.score:
		_end("خسرت")

func _finish_by_score(prefix: String) -> void:
	if player.score > opp.score:
		_end(prefix + "فزت!")
	elif player.score < opp.score:
		_end(prefix + "خسرت")
	else:
		_end("تعادل")

func _end(title: String) -> void:
	state = "over"
	end_ms = Time.get_ticks_msec()
	msg_t = 0.0
	msg_label.size.y = 240.0
	msg_label.text = "%s\nأنت: %d | الخصم: %d\nالمس للعب مرة ثانية" % [title, player.score, opp.score]
	ws.close()

func _draw() -> void:
	draw_line(Vector2(TW, 0), Vector2(TW, vh), Color(1, 1, 1, 0.25), 3.0)
	_draw_tower(player)
	_draw_tower(opp)

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
