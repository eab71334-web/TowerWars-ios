extends Node2D

const W := 720.0
const TW := 360.0
const BLOCK_H := 48.0
const START_W := 150.0
const PERFECT_TOL := 8.0
const ROUND_TIME := 90.0
# صعوبة البوت: 40 سهل، 22 متوسط، 8 صعب
const BOT_ERR := 22.0

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
	var age := 0.0
	var target := 0.0
	var ox := 0.0
	var hue := 0.0

var base_y := 1100.0
var vh := 1280.0
var player: Tower
var bot: Tower
var time_left := ROUND_TIME
var over := false
var over_t := 0.0
var msg_t := 0.0

var timer_label: Label
var bot_score: Label
var player_score: Label
var msg_label: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.1, 0.25))
	vh = get_viewport_rect().size.y
	base_y = vh - 160.0

	player = Tower.new()
	player.ox = TW
	player.hue = 0.0
	bot = Tower.new()
	bot.ox = 0.0
	bot.hue = 0.5

	var ui := CanvasLayer.new()
	add_child(ui)

	timer_label = _label(ui, 0.0, 20.0, W, 56)
	bot_score = _label(ui, 0.0, 100.0, TW, 64)
	player_score = _label(ui, TW, 100.0, TW, 64)
	var bn := _label(ui, 0.0, 190.0, TW, 28)
	bn.text = "الخصم (بوت)"
	var pn := _label(ui, TW, 190.0, TW, 28)
	pn.text = "أنت"
	msg_label = _label(ui, 0.0, 260.0, W, 40)

	var back := Button.new()
	back.text = "القائمة"
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	ui.add_child(back)

	_reset()

func _label(parent: Node, x: float, y: float, w: float, fs: int) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.size = Vector2(w, fs + 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	parent.add_child(l)
	return l

func _reset() -> void:
	_init_tower(player)
	_init_tower(bot)
	time_left = ROUND_TIME
	over = false
	over_t = 0.0
	msg_label.size.y = 80.0
	_say("المس الشاشة لإنزال الكتلة", 2.5)
	_update_ui()

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
	_spawn(t, START_W)

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
	t.age = 0.0
	if t.score % 2 == 0:
		t.cur_x = 0.0
		t.dir = 1.0
	else:
		t.cur_x = TW - t.cur_w
		t.dir = -1.0
	var top: Dictionary = t.blocks.back()
	var center: float = top.x + top.w / 2.0
	t.target = clampf(center - t.cur_w / 2.0 + randf_range(-BOT_ERR, BOT_ERR), 0.0, TW - t.cur_w)

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
	bot_score.text = str(bot.score)

func _process(delta: float) -> void:
	if not over:
		time_left -= delta
		var prev := bot.cur_x
		_move(player, delta)
		_move(bot, delta)
		if not over and not bot.dead and bot.age > 0.5:
			if (prev - bot.target) * (bot.cur_x - bot.target) <= 0.0:
				_drop(bot, player)
		if not over and time_left <= 0.0:
			time_left = 0.0
			_time_up()
	else:
		over_t += delta

	_anim(player, delta)
	_anim(bot, delta)

	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0 and not over:
			msg_label.text = ""

	timer_label.text = str(int(ceil(time_left)))
	queue_redraw()

func _move(t: Tower, delta: float) -> void:
	if t.dead:
		return
	t.age += delta
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
		if over:
			if over_t > 0.6:
				_reset()
		elif not player.dead:
			_drop(player, bot)

func _spawn_fall(t: Tower, x: float, y: float, w: float, c: Color) -> void:
	if w > 0.5:
		t.falling.append({"x": x, "y": y, "w": w, "vy": 0.0, "c": c})

func _drop(t: Tower, o: Tower) -> void:
	var top: Dictionary = t.blocks.back()
	var y := base_y - t.blocks.size() * BLOCK_H
	var col := _color(t, t.blocks.size())
	var left := maxf(t.cur_x, top.x)
	var right := minf(t.cur_x + t.cur_w, top.x + top.w)
	var ow := right - left

	if ow <= 0.0:
		_spawn_fall(t, t.cur_x, y, t.cur_w, col)
		t.dead = true
		_finish(t)
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
			o.attack += 1
			if t == player:
				_say("هجوم على الخصم!", 1.2)
			else:
				_say("الخصم هاجمك!", 1.2)
	else:
		t.combo = 0
		if t.cur_x < top.x:
			_spawn_fall(t, t.cur_x, y, left - t.cur_x, col)
		else:
			_spawn_fall(t, right, y, (t.cur_x + t.cur_w) - right, col)

	t.blocks.append({"x": nx, "w": nw, "c": col})
	t.score += 1
	_spawn(t, nw)
	_update_ui()

func _finish(loser: Tower) -> void:
	if loser == bot:
		_end("فزت!")
	else:
		_end("خسرت")

func _time_up() -> void:
	if player.score > bot.score:
		_end("انتهى الوقت: فزت!")
	elif player.score < bot.score:
		_end("انتهى الوقت: خسرت")
	else:
		_end("تعادل")

func _end(title: String) -> void:
	over = true
	over_t = 0.0
	msg_t = 0.0
	msg_label.size.y = 240.0
	msg_label.text = "%s\nأنت: %d | الخصم: %d\nالمس للإعادة" % [title, player.score, bot.score]

func _draw() -> void:
	draw_line(Vector2(TW, 0), Vector2(TW, vh), Color(1, 1, 1, 0.25), 3.0)
	_draw_tower(player)
	_draw_tower(bot)

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

	if not t.dead and not over:
		var y2 := base_y - t.blocks.size() * BLOCK_H + t.cam
		var c := _color(t, t.blocks.size())
		if t.hit:
			c = Color(1.0, 0.25, 0.25)
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, BLOCK_H - 3.0), c)
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, 6.0), c.lightened(0.3))
