extends CanvasLayer

var bg: Control
var blocks: Array = []
var stars: Array = []
var t := 0.0

func _ready() -> void:
	layer = -100
	bg = Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_bg)
	add_child(bg)
	var sz := _size()
	for i in 14:
		blocks.append({
			"x": randf() * sz.x, "y": randf() * sz.y,
			"w": randf_range(50.0, 140.0), "h": randf_range(28.0, 56.0),
			"s": randf_range(14.0, 42.0), "hue": randf(), "a": randf_range(0.08, 0.2)
		})
	for i in 45:
		stars.append({"x": randf(), "y": randf(), "r": randf_range(1.0, 2.6), "p": randf() * TAU})

func _size() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	if s.x < 10.0:
		return Vector2(720, 1280)
	return s

func _process(delta: float) -> void:
	t += delta
	var sz := _size()
	for b in blocks:
		b.y -= b.s * delta
		if b.y + b.h < -20.0:
			b.y = sz.y + 20.0
			b.x = randf() * sz.x
	bg.queue_redraw()

func _draw_bg() -> void:
	var sz := _size()
	var top := Color(0.20, 0.07, 0.42)
	var mid := Color(0.07, 0.17, 0.52)
	var bot := Color(0.02, 0.05, 0.22)
	var h2 := sz.y * 0.55
	bg.draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, h2), Vector2(0, h2)]),
		PackedColorArray([top, top, mid, mid]))
	bg.draw_polygon(
		PackedVector2Array([Vector2(0, h2), Vector2(sz.x, h2), Vector2(sz.x, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([mid, mid, bot, bot]))
	bg.draw_circle(Vector2(sz.x * 0.5, sz.y * 0.30), 420.0, Color(0.55, 0.3, 1.0, 0.07))
	bg.draw_circle(Vector2(sz.x * 0.5, sz.y * 0.30), 260.0, Color(0.55, 0.4, 1.0, 0.08))
	for s in stars:
		var a := 0.25 + 0.5 * (0.5 + 0.5 * sin(t * 2.0 + float(s.p)))
		bg.draw_circle(Vector2(float(s.x) * sz.x, float(s.y) * sz.y), float(s.r), Color(1, 1, 1, a))
	for b in blocks:
		var c := Color.from_hsv(float(b.hue), 0.6, 1.0, float(b.a))
		bg.draw_rect(Rect2(b.x, b.y, b.w, b.h), c)
		bg.draw_rect(Rect2(b.x, b.y, b.w, float(b.h) * 0.25), Color(1, 1, 1, float(b.a) * 0.6))

func style(color: Color, radius: int, depth: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = depth
	sb.border_color = color.darkened(0.35)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 6)
	return sb

func button(text: String, color: Color, height: float, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", style(color, 32, 12))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.1), 32, 12))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.12), 32, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.55))
	b.add_theme_constant_override("outline_size", 8)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.pressed.connect(func(): Sfx.click())
	return b

func label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.32))
		l.add_theme_constant_override("outline_size", outline)
	return l
