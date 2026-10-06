extends Node2D

const W := 720.0
const BLOCK_H := 56.0
const START_W := 300.0
const PERFECT_TOL := 10.0
const SAVE_PATH := "user://save.cfg"

var base_y := 1000.0
var vh := 1280.0
var blocks: Array = []
var falling: Array = []
var cur_x := 0.0
var cur_w := START_W
var dir := 1.0
var over := false
var score := 0
var best := 0
var combo := 0
var cam := 0.0
var flash := 0.0

var score_label: Label
var msg_label: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.1, 0.25))
	vh = get_viewport_rect().size.y
	base_y = vh - 220.0
	_load_best()

	var ui := CanvasLayer.new()
	add_child(ui)

	score_label = _make_label(ui, 70.0, 80)
	msg_label = _make_label(ui, 200.0, 44)

	var back := Button.new()
	back.text = "القائمة"
	back.position = Vector2(20, 20)
	back.size = Vector2(170, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	ui.add_child(back)

	_reset()

func _make_label(parent: Node, y: float, font_size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.size = Vector2(W, font_size + 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func _reset() -> void:
	blocks.clear()
	falling.clear()
	blocks.append({"x": (W - START_W) / 2.0, "w": START_W, "c": _color(0)})
	score = 0
	combo = 0
	over = false
	cam = 0.0
	flash = 0.0
	_next_block(START_W)
	score_label.text = "0"
	msg_label.text = "المس الشاشة لإنزال الكتلة"

func _color(i: int) -> Color:
	return Color.from_hsv(fmod(i * 0.045, 1.0), 0.65, 0.95)

func _next_block(w: float) -> void:
	cur_w = w
	if score % 2 == 0:
		cur_x = 0.0
		dir = 1.0
	else:
		cur_x = W - cur_w
		dir = -1.0

func _speed() -> float:
	return 320.0 + minf(score * 10.0, 480.0)

func _process(delta: float) -> void:
	if not over:
		cur_x += dir * _speed() * delta
		if cur_x < 0.0:
			cur_x = 0.0
			dir = 1.0
		elif cur_x + cur_w > W:
			cur_x = W - cur_w
			dir = -1.0

	var target := maxf(0.0, (blocks.size() - 9) * BLOCK_H)
	cam = lerpf(cam, target, minf(1.0, 6.0 * delta))

	for p in falling:
		p.vy += 1800.0 * delta
		p.y += p.vy * delta
	falling = falling.filter(func(p): return p.y + cam < vh + 200.0)

	if flash > 0.0:
		flash -= delta
		if flash <= 0.0 and not over:
			msg_label.text = ""

	queue_redraw()

func _draw() -> void:
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		var y := base_y - i * BLOCK_H + cam
		if y > vh + 100.0 or y < -100.0:
			continue
		draw_rect(Rect2(b.x, y, b.w, BLOCK_H - 3.0), b.c)
		draw_rect(Rect2(b.x, y, b.w, 8.0), b.c.lightened(0.3))

	for p in falling:
		draw_rect(Rect2(p.x, p.y + cam, p.w, BLOCK_H - 3.0), p.c)

	if not over:
		var y2 := base_y - blocks.size() * BLOCK_H + cam
		var c := _color(blocks.size())
		draw_rect(Rect2(cur_x, y2, cur_w, BLOCK_H - 3.0), c)
		draw_rect(Rect2(cur_x, y2, cur_w, 8.0), c.lightened(0.3))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if over:
			_reset()
		else:
			_drop()

func _spawn_fall(x: float, y: float, w: float, c: Color) -> void:
	if w > 0.5:
		falling.append({"x": x, "y": y, "w": w, "vy": 0.0, "c": c})

func _drop() -> void:
	var top: Dictionary = blocks.back()
	var y := base_y - blocks.size() * BLOCK_H
	var col := _color(blocks.size())
	var left := maxf(cur_x, top.x)
	var right := minf(cur_x + cur_w, top.x + top.w)
	var ow := right - left

	if ow <= 0.0:
		_spawn_fall(cur_x, y, cur_w, col)
		_game_over()
		return

	var nx := left
	var nw := ow

	if absf(cur_x - top.x) <= PERFECT_TOL:
		combo += 1
		nx = top.x
		nw = top.w
		if combo >= 3:
			var grown := minf(nw + 14.0, START_W)
			nx = top.x - (grown - nw) / 2.0
			nw = grown
			nx = clampf(nx, 0.0, W - nw)
		msg_label.text = "مضبوط! x%d" % combo
		flash = 0.9
	else:
		combo = 0
		if cur_x < top.x:
			_spawn_fall(cur_x, y, left - cur_x, col)
		else:
			_spawn_fall(right, y, (cur_x + cur_w) - right, col)

	blocks.append({"x": nx, "w": nw, "c": col})
	score += 1
	score_label.text = str(score)
	_next_block(nw)

func _game_over() -> void:
	over = true
	if score > best:
		best = score
		_save_best()
	msg_label.text = "انتهت اللعبة\nالارتفاع: %d | الأفضل: %d\nالمس للإعادة" % [score, best]
	msg_label.size.y = 220.0

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = int(cf.get_value("game", "best", 0))

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best", best)
	cf.save(SAVE_PATH)
