extends Control

const GOLD := Color(1.0, 0.86, 0.2)
const SLOTS := 7
const WIDTHS := [260.0, 240.0, 226.0, 204.0, 182.0, 154.0, 124.0]

var t := 0.0
var vw := 720.0
var vh := 1280.0
var base := 0.0
var bh := 60.0
var landed: Array = []
var parts: Array = []
var title: Label
var sub: Label
var load_label: Label
var flash_t := -1.0
var revealed := false
var went := false

func _ready() -> void:
	var s := get_viewport_rect().size
	vw = s.x
	vh = s.y
	base = vh * 0.50
	bh = clampf(vh * 0.048, 46.0, 66.0)
	for i in SLOTS:
		landed.append(false)

	title = UI.label(Data.GAME_NAME, 128, GOLD, 26)
	title.position = Vector2(0, vh * 0.56)
	title.size = Vector2(vw, 200)
	title.pivot_offset = Vector2(vw / 2.0, 100.0)
	title.modulate.a = 0.0
	add_child(title)

	sub = UI.label(Data.GAME_SUB, 40, Color(0.55, 0.9, 1.0), 8)
	sub.position = Vector2(0, vh * 0.56 + 175.0)
	sub.size = Vector2(vw, 70)
	sub.modulate.a = 0.0
	add_child(sub)

	load_label = UI.label("جاري التحميل...", 26, Color(1, 1, 1, 0.7), 0)
	load_label.position = Vector2(0, vh * 0.93 - 56.0)
	load_label.size = Vector2(vw, 44)
	add_child(load_label)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and t > 0.6:
		_next()

func _next() -> void:
	if went:
		return
	went = true
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _burst(pos: Vector2, n: int, c: Color, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.4, 1.0) * spd
		parts.append({"p": pos, "v": Vector2(cos(a), sin(a) - 0.6) * sp, "life": randf_range(0.5, 1.0), "c": c, "r": randf_range(3.0, 7.0)})

func _reveal() -> void:
	revealed = true
	flash_t = 0.0
	Sfx.win()
	_burst(Vector2(vw / 2.0, vh * 0.56 + 80.0), 40, GOLD, 520.0)
	title.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a", 1.0, 0.4)

func _process(delta: float) -> void:
	t += delta
	for i in SLOTS:
		if not landed[i] and t >= 0.5 + float(i) * 0.3 + 0.4:
			landed[i] = true
			Sfx.drop()
			var y := base - float(i + 1) * bh + bh * 0.5
			_burst(Vector2(vw / 2.0, y + bh * 0.4), 8, Data.block_color(i, 0.0), 160.0)
	if not revealed and t >= 2.75:
		_reveal()
	if t >= 4.6:
		_next()
	if flash_t >= 0.0:
		flash_t += delta
	var alive: Array = []
	for p in parts:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) > 0.0:
			var v: Vector2 = p["v"]
			v.y += 700.0 * delta
			p["v"] = v
			p["p"] = (p["p"] as Vector2) + v * delta
			alive.append(p)
	parts = alive
	queue_redraw()

func _draw() -> void:
	var cx := vw / 2.0
	draw_circle(Vector2(cx, base - bh * 3.0), vw * 0.55, Color(0.55, 0.35, 1.0, 0.07))
	draw_circle(Vector2(cx, base - bh * 3.0), vw * 0.38, Color(0.6, 0.45, 1.0, 0.08))
	draw_rect(Rect2(cx - 190.0, base + 6.0, 380.0, 10.0), Color(1, 1, 1, 0.25))

	for i in SLOTS:
		var st := 0.5 + float(i) * 0.3
		if t < st:
			continue
		var k := clampf((t - st) / 0.4, 0.0, 1.0)
		var ty := base - float(i + 1) * bh
		var h := bh - 5.0
		var y := ty
		if k < 1.0:
			y = lerpf(-bh * 2.0, ty, k * k)
		else:
			var s := t - st - 0.4
			var sq := exp(-s * 8.0) * cos(s * 26.0) * 0.2
			h = h * (1.0 - sq)
			y = ty + (bh - 5.0) - h
		var w: float = WIDTHS[i]
		var x := cx - w / 2.0 + (8.0 if i % 2 == 0 else -8.0)
		var c := Data.block_color(i, 0.0)
		draw_rect(Rect2(x + 5.0, y + 7.0, w, h), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(x, y, w, h), c)
		draw_rect(Rect2(x, y, w, h * 0.28), c.lightened(0.35))
		draw_rect(Rect2(x, y + h - 5.0, w, 5.0), c.darkened(0.25))

	for p in parts:
		var a := clampf(float(p["life"]), 0.0, 1.0)
		var col: Color = p["c"]
		draw_circle(p["p"], float(p["r"]) * (0.4 + a), Color(col.r, col.g, col.b, a))

	if flash_t >= 0.0:
		var fa := clampf(1.0 - flash_t * 2.5, 0.0, 1.0)
		if fa > 0.0:
			draw_rect(Rect2(0, 0, vw, vh), Color(1, 1, 1, fa * 0.5))
			draw_arc(Vector2(cx, vh * 0.56 + 80.0), flash_t * 1100.0, 0.0, TAU, 64, Color(1.0, 0.9, 0.5, fa), 10.0)

	var by := vh * 0.93
	var bw := vw * 0.6
	draw_rect(Rect2(cx - bw / 2.0, by, bw, 12.0), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(cx - bw / 2.0, by, bw * clampf(t / 4.4, 0.0, 1.0), 12.0), GOLD)

	if t < 0.6:
		draw_rect(Rect2(0, 0, vw, vh), Color(0.02, 0.0, 0.1, 1.0 - t / 0.6))
