extends Control

const PW = preload("res://powers.gd")

signal tapped

var pid := "slow"
var count := 0
var show_count := false
var ring := 0.0
var enabled := true
var _down := false
var _c := Vector2.ZERO
var _r := 1.0

func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(_on_resized)

func _on_resized() -> void:
	pivot_offset = size / 2.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			create_tween().tween_property(self, "scale", Vector2(0.9, 0.9), 0.06)
		else:
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.1)
			if _down and UI.tapped():
				tapped.emit()
			_down = false

func _p(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y) * _r

func _half(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(_p(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return
	_c = size / 2.0
	_r = s / 2.0
	var info: Dictionary = PW.def(pid)
	var col := Color(0.5, 0.5, 0.6)
	var is_self := true
	if not info.is_empty():
		col = info["color"]
		is_self = str(info["kind"]) == "self"
	var live := enabled and (not show_count or count > 0)
	if not live:
		col = Color(0.42, 0.42, 0.52)
	var rim := Color(1.0, 0.4, 0.4)
	if is_self:
		rim = Color(0.3, 0.9, 0.5)
	if not live:
		rim = Color(0.35, 0.35, 0.45)
	draw_circle(_c + Vector2(0, _r * 0.07), _r * 0.97, Color(0, 0, 0, 0.32))
	draw_circle(_c, _r * 0.97, rim)
	draw_circle(_c, _r * 0.86, col.darkened(0.4))
	draw_circle(_c, _r * 0.8, col)
	draw_circle(_c + Vector2(-_r * 0.22, -_r * 0.3), _r * 0.3, Color(1, 1, 1, 0.16))
	_glyph(pid, live)
	if ring > 0.0:
		draw_arc(_c, _r * 0.97, -PI / 2.0, -PI / 2.0 + TAU * clampf(ring, 0.0, 1.0), 40, Color(1, 1, 1, 0.95), _r * 0.12)
	if show_count:
		var bc := _c + Vector2(_r * 0.72, _r * 0.72)
		draw_circle(bc, _r * 0.33, Color(0.08, 0.04, 0.28))
		var bcol := Color(0.6, 0.6, 0.7)
		if count > 0:
			bcol = Color(1.0, 0.86, 0.2)
		draw_circle(bc, _r * 0.27, bcol)
		var f := ThemeDB.fallback_font
		draw_string(f, bc + Vector2(-_r * 0.3, _r * 0.15), str(count), HORIZONTAL_ALIGNMENT_CENTER, _r * 0.6, int(_r * 0.42), Color(0.15, 0.08, 0.3))

func _glyph(gid: String, live: bool) -> void:
	var w := Color(1, 1, 1, 0.55)
	if live:
		w = Color(1, 1, 1, 0.97)
	var lw := _r * 0.12
	match gid:
		"slow":
			draw_colored_polygon(PackedVector2Array([_p(-0.42, -0.58), _p(0.42, -0.58), _p(0.0, 0.0)]), w)
			draw_colored_polygon(PackedVector2Array([_p(-0.42, 0.58), _p(0.42, 0.58), _p(0.0, 0.0)]), w)
			draw_line(_p(-0.52, -0.58), _p(0.52, -0.58), w, lw)
			draw_line(_p(-0.52, 0.58), _p(0.52, 0.58), w, lw)
		"grow":
			draw_line(_p(-0.5, 0.0), _p(0.5, 0.0), w, lw)
			draw_colored_polygon(PackedVector2Array([_p(-0.72, 0.0), _p(-0.36, -0.3), _p(-0.36, 0.3)]), w)
			draw_colored_polygon(PackedVector2Array([_p(0.72, 0.0), _p(0.36, -0.3), _p(0.36, 0.3)]), w)
		"fast":
			draw_colored_polygon(PackedVector2Array([_p(0.15, -0.8), _p(-0.4, 0.1), _p(-0.05, 0.1), _p(-0.2, 0.8), _p(0.42, -0.15), _p(0.05, -0.15)]), w)
		"magnet":
			draw_arc(_p(0.0, -0.05), _r * 0.4, PI, TAU, 24, w, _r * 0.2)
			draw_line(_p(-0.4, -0.05), _p(-0.4, 0.5), w, _r * 0.2)
			draw_line(_p(0.4, -0.05), _p(0.4, 0.5), w, _r * 0.2)
			draw_line(_p(-0.4, 0.3), _p(-0.4, 0.52), Color(1.0, 0.35, 0.4), _r * 0.2)
			draw_line(_p(0.4, 0.3), _p(0.4, 0.52), Color(1.0, 0.35, 0.4), _r * 0.2)
		"shield":
			draw_colored_polygon(PackedVector2Array([_p(-0.5, -0.55), _p(0.5, -0.55), _p(0.5, 0.1), _p(0.0, 0.72), _p(-0.5, 0.1)]), w)
			var inner := Color(0.35, 0.5, 0.95)
			if not live:
				inner = Color(0.42, 0.42, 0.52)
			draw_colored_polygon(PackedVector2Array([_p(-0.3, -0.38), _p(0.3, -0.38), _p(0.3, 0.04), _p(0.0, 0.44), _p(-0.3, 0.04)]), inner)
		"narrow":
			draw_colored_polygon(PackedVector2Array([_p(-0.12, 0.0), _p(-0.56, -0.3), _p(-0.56, 0.3)]), w)
			draw_colored_polygon(PackedVector2Array([_p(0.12, 0.0), _p(0.56, -0.3), _p(0.56, 0.3)]), w)
			draw_line(_p(-0.56, 0.0), _p(-0.8, 0.0), w, lw)
			draw_line(_p(0.56, 0.0), _p(0.8, 0.0), w, lw)
		"fog":
			draw_circle(_p(-0.3, 0.1), _r * 0.28, w)
			draw_circle(_p(0.0, -0.15), _r * 0.36, w)
			draw_circle(_p(0.3, 0.1), _r * 0.28, w)
			draw_rect(Rect2(_p(-0.52, 0.1), Vector2(1.04, 0.28) * _r), w)
		"jitter":
			var zig := PackedVector2Array([_p(-0.62, 0.15), _p(-0.3, -0.4), _p(0.0, 0.35), _p(0.3, -0.4), _p(0.62, 0.15)])
			draw_polyline(zig, w, lw)
			for q in zig:
				draw_circle(q, lw * 0.5, w)
