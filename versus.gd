extends Node2D

const ResultOverlay = preload("res://result_overlay.gd")
const W := 720.0
const TW := 360.0
const BLOCK_H := 48.0
const START_W := 150.0
const PERFECT_TOL := 8.0
const ROUND_TIME := 90.0
# صعوبة البوت: 40 سهل، 22 متوسط، 8 صعب
const BOT_ERR := 22.0
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
var msg_t := 0.0
var shake_t := 0.0
var flash := 0.0
var last_sec := -1

var ui: CanvasLayer
var timer_label: Label
var bot_score: Label
var player_score: Label
var msg_label: Label

func _ready() -> void:
	vh = get_viewport_rect().size.y
	base_y = vh - 160.0

	player = Tower.new()
	player.ox = TW
	player.hue = 0.0
	bot = Tower.new()
	bot.ox = 0.0
	bot.hue = 0.5

	ui = CanvasLayer.new()
	add_child(ui)
	timer_label = _hud(0.0, 8.0, W, 84, Color.WHITE)
	bot_score = _hud(0.0, 120.0, TW, 110, CYAN)
	player_score = _hud(TW, 120.0, TW, 110, GOLD)
	_hud(0.0, 250.0, TW, 32, Color(1, 1, 1, 0.85)).text = "الخصم (بوت)"
	_hud(TW, 250.0, TW, 32, Color(1, 1, 1, 0.85)).text = "أنت"
	msg_label = _hud(0.0, 330.0, W, 48, Color.WHITE)

	var back := UI.button("القائمة", Color(0.45, 0.35, 0.85), 70, 26)
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	ui.add_child(back)

	_init_tower(player)
	_init_tower(bot)
	_say("المس الشاشة لإنزال الكتلة", 2.5, GOLD)
	_update_ui()

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
	var bs := str(bot.score)
	if bot_score.text != bs:
		bot_score.text = bs
		_pop(bot_score)

func _process(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		var k := clampf(shake_t / 0.45, 0.0, 1.0)
		position = Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)) * k
	else:
		position = Vector2.ZERO
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 2.5)

	if not over:
		time_left -= delta
		var prev := bot.cur_x
		_move(player, delta)
		_move(bot, delta)
		if not over and not bot.dead and bot.age > 0.5:
			if (prev - bot.target) * (bot.cur_x - bot.target) <= 0.0:
				_drop(bot, player)
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
	_anim(bot, delta)

	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0 and not over:
			msg_label.text = ""
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
		if not over and not player.dead:
			_drop(player, bot)

func _spawn_fall(t: Tower, x: float, y: float, w: float, c: Color) -> void:
	if w > 0.5:
		t.falling.append({"x": x, "y": y, "w": w, "vy": 0.0, "c": c})

func _drop(t: Tower, o: Tower) -> void:
	var is_player := t == player
	var top: Dictionary = t.blocks.back()
	var y := base_y - t.blocks.size() * BLOCK_H
	var col := _color(t, t.blocks.size())
	var left := maxf(t.cur_x, top.x)
	var right := minf(t.cur_x + t.cur_w, top.x + top.w)
	var ow := right - left

	if ow <= 0.0:
		_spawn_fall(t, t.cur_x, y, t.cur_w, col)
		t.dead = true
		if is_player:
			Sfx.hit()
			_say("سقط برجك!", 2.0, RED)
		else:
			_say("سقط برج الخصم!", 2.0, GOLD)
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
		if is_player:
			Sfx.perfect()
			_say("مضبوط! x%d" % t.combo, 0.9, GOLD)
		if t.combo % 3 == 0:
			o.attack += 1
			if is_player:
				_say("هجوم على الخصم!", 1.3, ORANGE)
			else:
				_hit_fx()
				_say("الخصم هاجمك!", 1.3, RED)
	else:
		t.combo = 0
		if is_player:
			Sfx.drop()
		if t.cur_x < top.x:
			_spawn_fall(t, t.cur_x, y, left - t.cur_x, col)
		else:
			_spawn_fall(t, right, y, (t.cur_x + t.cur_w) - right, col)

	t.blocks.append({"x": nx, "w": nw, "c": col})
	t.score += 1
	_spawn(t, nw)
	_update_ui()

func _check_end() -> void:
	if over:
		return
	if time_left <= 0.0:
		_finish_by_score("انتهى الوقت")
	elif player.dead and bot.dead:
		_finish_by_score("سقط البرجان")
	elif bot.dead and player.score > bot.score:
		_end(1, "سقط برج الخصم")
	elif player.dead and bot.score > player.score:
		_end(-1, "سقط برجك")

func _finish_by_score(reason: String) -> void:
	if player.score > bot.score:
		_end(1, reason)
	elif player.score < bot.score:
		_end(-1, reason)
	else:
		_end(0, reason)

func _end(result: int, reason: String) -> void:
	if over:
		return
	over = true
	msg_t = 0.0
	msg_label.text = ""
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
	var ov := ResultOverlay.new()
	add_child(ov)
	ov.build(title, reason, col, player.score, bot.score, "البوت", "العب مرة ثانية")
	ov.again_pressed.connect(func(): get_tree().reload_current_scene())
	ov.menu_pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))

func _draw() -> void:
	draw_line(Vector2(TW, 0), Vector2(TW, vh), Color(1, 1, 1, 0.25), 3.0)
	_draw_tower(player)
	_draw_tower(bot)
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
	if not t.dead and not over:
		var y2 := base_y - t.blocks.size() * BLOCK_H + t.cam
		var c := _color(t, t.blocks.size())
		if t.hit:
			c = Color(1.0, 0.25, 0.25)
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, BLOCK_H - 3.0), c)
		draw_rect(Rect2(ox + t.cur_x, y2, t.cur_w, 6.0), c.lightened(0.3))
