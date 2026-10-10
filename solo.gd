extends Node2D

const ResultOverlay = preload("res://result_overlay.gd")
const W := 720.0
const BLOCK_H := 56.0
const GOLD := Color(1.0, 0.86, 0.2)
const RED := Color(1.0, 0.4, 0.45)

var mode: Dictionary
var start_w := 300.0
var tol := 10.0
var base_y := 1000.0
var vh := 1280.0
var blocks: Array = []
var falling: Array = []
var cur_x := 0.0
var cur_w := 300.0
var dir := 1.0
var over := false
var score := 0
var combo := 0
var max_lives := 1
var lives := 1
var time_left := 0.0
var cam := 0.0
var msg_t := 0.0
var shake_t := 0.0
var flash := 0.0
var last_sec := -1

var ui: CanvasLayer
var score_label: Label
var msg_label: Label
var timer_label: Label

func _ready() -> void:
	mode = Data.mode_def(str(Engine.get_meta("solo_mode", "classic")))
	start_w = float(mode.start_w)
	tol = float(mode.tol)
	max_lives = int(mode.lives)
	lives = max_lives
	time_left = float(mode.time)
	vh = get_viewport_rect().size.y
	base_y = vh - 200.0

	ui = CanvasLayer.new()
	add_child(ui)
	score_label = _hud(0.0, 60.0, 120, Color.WHITE)
	score_label.text = "0"
	var name_l := _hud(0.0, 205.0, 30, Color(1, 1, 1, 0.75))
	name_l.text = str(mode.name)
	timer_label = _hud(0.0, 255.0, 54, GOLD)
	timer_label.text = ""
	msg_label = _hud(0.0, 340.0, 50, Color.WHITE)

	var back := UI.button("القائمة", Color(0.45, 0.35, 0.85), 70, 26)
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://modes.tscn"))
	ui.add_child(back)

	blocks.append({"x": (W - start_w) / 2.0, "w": start_w})
	_next_block(start_w)
	_say("المس الشاشة لإنزال الكتلة", 2.0, Color.WHITE)

func _hud(x: float, y: float, fs: int, color: Color) -> Label:
	var l := UI.label("", fs, color, 12)
	l.position = Vector2(x, y)
	l.size = Vector2(W, float(fs) + 30.0)
	ui.add_child(l)
	return l

func _pop(l: Label) -> void:
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.2)

func _say(text: String, secs: float, color: Color) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	msg_t = secs

func _next_block(w: float) -> void:
	cur_w = w
	if score % 2 == 0:
		cur_x = 0.0
		dir = 1.0
	else:
		cur_x = W - cur_w
		dir = -1.0

func _speed() -> float:
	var b := float(mode.base)
	return b + minf(float(score) * float(mode.grow), b * 1.5)

func _process(delta: float) -> void:
	if not over:
		cur_x += dir * _speed() * delta
		if cur_x < 0.0:
			cur_x = 0.0
			dir = 1.0
		elif cur_x + cur_w > W:
			cur_x = W - cur_w
			dir = -1.0
		if float(mode.time) > 0.0:
			time_left -= delta
			var secs := int(ceil(maxf(time_left, 0.0)))
			if secs != last_sec:
				last_sec = secs
				timer_label.text = str(secs)
				timer_label.add_theme_color_override("font_color", RED if secs <= 10 else GOLD)
				if secs <= 5 and secs > 0:
					Sfx.click()
					_pop(timer_label)
			if time_left <= 0.0:
				_end("انتهى الوقت")

	var target := maxf(0.0, float(blocks.size() - 9) * BLOCK_H)
	cam = lerpf(cam, target, minf(1.0, 6.0 * delta))
	for p in falling:
		p.vy += 1800.0 * delta
		p.y += p.vy * delta
	falling = falling.filter(func(p): return p.y + cam < vh + 200.0)

	if shake_t > 0.0:
		shake_t -= delta
		var k := clampf(shake_t / 0.4, 0.0, 1.0)
		position = Vector2(randf_range(-10.0, 10.0), randf_range(-7.0, 7.0)) * k
	else:
		position = Vector2.ZERO
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 2.5)
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0 and not over:
			msg_label.text = ""
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not over:
		_drop()

func _spawn_fall(x: float, y: float, w: float, c: Color) -> void:
	if w > 0.5:
		falling.append({"x": x, "y": y, "w": w, "vy": 0.0, "c": c})

func _drop() -> void:
	var top: Dictionary = blocks.back()
	var tx := float(top.x)
	var tw := float(top.w)
	var y := base_y - float(blocks.size()) * BLOCK_H
	var col := Data.block_color(blocks.size(), 0.0)
	var left := maxf(cur_x, tx)
	var right := minf(cur_x + cur_w, tx + tw)
	var ow := right - left

	if ow < 6.0:
		_spawn_fall(cur_x, y, cur_w, col)
		_lose_life()
		return

	var nx := left
	var nw := ow
	var cd := (cur_x + cur_w / 2.0) - (tx + tw / 2.0)
	if absf(cd) <= tol:
		combo += 1
		nw = cur_w
		nx = tx + tw / 2.0 - nw / 2.0
		if combo >= 3:
			var grown := minf(nw + 14.0, start_w)
			nx -= (grown - nw) / 2.0
			nw = grown
			nx = clampf(nx, 0.0, W - nw)
		Sfx.perfect()
		_say("مضبوط! x%d" % combo, 0.9, GOLD)
		Data.add_progress("perfect", 1, false)
		Data.add_progress("combo", combo, true)
	else:
		combo = 0
		Sfx.drop()
		if cur_x < tx:
			_spawn_fall(cur_x, y, left - cur_x, col)
		else:
			_spawn_fall(right, y, (cur_x + cur_w) - right, col)

	blocks.append({"x": nx, "w": nw})
	score += 1
	Data.add_progress("blocks", 1, false)
	score_label.text = str(score)
	_pop(score_label)
	_next_block(nw)

func _lose_life() -> void:
	lives -= 1
	combo = 0
	Sfx.hit()
	shake_t = 0.4
	flash = 1.0
	Input.vibrate_handheld(150)
	if lives <= 0:
		_end("سقط البرج")
	else:
		var top: Dictionary = blocks.back()
		_say("خسرت روحاً!", 1.0, RED)
		_next_block(float(top.w))

func _end(reason: String) -> void:
	if over:
		return
	over = true
	msg_label.text = ""
	var prev_best := int(Data.best.get(str(mode.id), 0))
	Data.reward_run(str(mode.id), score)
	var sub := reason
	if score > prev_best and score > 0:
		sub = "رقم قياسي جديد! " + reason
		Sfx.win()
	else:
		Sfx.lose()
	var ov := ResultOverlay.new()
	add_child(ov)
	ov.build("انتهت اللعبة", sub, GOLD, score, maxi(prev_best, score), "الأفضل", "العب مرة ثانية")
	ov.again_pressed.connect(func(): get_tree().reload_current_scene())
	ov.menu_pressed.connect(func(): get_tree().change_scene_to_file("res://modes.tscn"))

func _heart(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p + Vector2(-r * 0.5, -r * 0.3), r * 0.55, c)
	draw_circle(p + Vector2(r * 0.5, -r * 0.3), r * 0.55, c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r, 0.0), p + Vector2(r, 0.0), p + Vector2(0.0, r * 1.1)]), c)

func _draw() -> void:
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		var y := base_y - float(i) * BLOCK_H + cam
		if y > vh + 100.0 or y < -100.0:
			continue
		var c := Data.block_color(i, 0.0)
		var bx := float(b.x)
		var bw := float(b.w)
		draw_rect(Rect2(bx + 4.0, y + 6.0, bw, BLOCK_H - 3.0), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(bx, y, bw, BLOCK_H - 3.0), c)
		draw_rect(Rect2(bx, y, bw, 8.0), c.lightened(0.3))
	for p in falling:
		draw_rect(Rect2(p.x, p.y + cam, p.w, BLOCK_H - 3.0), p.c)
	if not over:
		var y2 := base_y - float(blocks.size()) * BLOCK_H + cam
		var c2 := Data.block_color(blocks.size(), 0.0)
		draw_rect(Rect2(cur_x, y2, cur_w, BLOCK_H - 3.0), c2)
		draw_rect(Rect2(cur_x, y2, cur_w, 8.0), c2.lightened(0.3))
	if max_lives > 1 and max_lives <= 5:
		for i in max_lives:
			var hx := W / 2.0 + (float(i) - float(max_lives - 1) / 2.0) * 64.0
			_heart(Vector2(hx, 262.0), 22.0, Color(1.0, 0.3, 0.4) if i < lives else Color(1, 1, 1, 0.2))
	if flash > 0.0:
		draw_rect(Rect2(-40, -40, W + 80, vh + 80), Color(1.0, 0.1, 0.1, flash * 0.28))
