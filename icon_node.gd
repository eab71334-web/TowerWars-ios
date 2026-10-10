extends Control

var kind := "coin"
var col := Color.WHITE
var col2 := Color(0.15, 0.08, 0.35)
var badge := false
var _c := Vector2.ZERO
var _r := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

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
	match kind:
		"coin":
			draw_circle(_c, _r * 0.95, Color(0.9, 0.55, 0.05))
			draw_circle(_c, _r * 0.8, Color(1.0, 0.82, 0.2))
			draw_rect(Rect2(_p(-0.09, -0.4), Vector2(0.18, 0.8) * _r), Color(0.9, 0.55, 0.05))
			draw_arc(_c, _r * 0.8, deg_to_rad(200.0), deg_to_rad(290.0), 12, Color(1, 1, 0.85, 0.9), _r * 0.1)
		"gear":
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_circle(_p(cos(a) * 0.78, sin(a) * 0.78), _r * 0.2, col)
			draw_circle(_c, _r * 0.66, col)
			draw_circle(_c, _r * 0.3, col2)
		"trophy":
			draw_colored_polygon(PackedVector2Array([_p(-0.55, -0.7), _p(0.55, -0.7), _p(0.4, 0.0), _p(0.15, 0.2), _p(-0.15, 0.2), _p(-0.4, 0.0)]), col)
			draw_arc(_p(-0.58, -0.42), _r * 0.24, PI * 0.5, PI * 1.5, 10, col, _r * 0.11)
			draw_arc(_p(0.58, -0.42), _r * 0.24, -PI * 0.5, PI * 0.5, 10, col, _r * 0.11)
			draw_rect(Rect2(_p(-0.1, 0.2), Vector2(0.2, 0.3) * _r), col)
			draw_rect(Rect2(_p(-0.4, 0.5), Vector2(0.8, 0.2) * _r), col)
		"shop":
			draw_rect(Rect2(_p(-0.6, -0.3), Vector2(1.2, 1.0) * _r), col)
			draw_arc(_p(0.0, -0.3), _r * 0.3, PI, TAU, 12, col, _r * 0.13)
			draw_circle(_p(0.0, 0.2), _r * 0.16, col2)
		"friends":
			for x in [-0.42, 0.42]:
				draw_circle(_p(float(x), -0.38), _r * 0.24, col)
				draw_colored_polygon(_half(float(x), 0.7, 0.42, 0.55), col)
		"home":
			draw_colored_polygon(PackedVector2Array([_p(-0.85, 0.0), _p(0.0, -0.8), _p(0.85, 0.0)]), col)
			draw_rect(Rect2(_p(-0.6, 0.0), Vector2(1.2, 0.8) * _r), col)
			draw_rect(Rect2(_p(-0.15, 0.3), Vector2(0.3, 0.5) * _r), col2)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + TAU * float(i) / 10.0
				var rr := 0.95 if i % 2 == 0 else 0.4
				pts.append(_p(cos(a) * rr, sin(a) * rr))
			draw_colored_polygon(pts, col)
		"target":
			draw_circle(_c, _r * 0.92, col)
			draw_circle(_c, _r * 0.66, col2)
			draw_circle(_c, _r * 0.42, col)
			draw_circle(_c, _r * 0.18, col2)
		"crown":
			draw_colored_polygon(PackedVector2Array([_p(-0.8, 0.5), _p(-0.8, -0.45), _p(-0.4, 0.0), _p(0.0, -0.65), _p(0.4, 0.0), _p(0.8, -0.45), _p(0.8, 0.5)]), col)
			draw_rect(Rect2(_p(-0.8, 0.55), Vector2(1.6, 0.18) * _r), col)
		"bolt":
			draw_colored_polygon(PackedVector2Array([_p(0.15, -0.95), _p(-0.5, 0.1), _p(-0.05, 0.1), _p(-0.2, 0.95), _p(0.5, -0.15), _p(0.05, -0.15)]), col)
		"user":
			draw_circle(_p(0.0, -0.4), _r * 0.3, col)
			draw_colored_polygon(_half(0.0, 0.85, 0.65, 0.75), col)
		"flame":
			draw_circle(_p(0.0, 0.25), _r * 0.58, Color(1.0, 0.45, 0.1))
			draw_colored_polygon(PackedVector2Array([_p(-0.5, 0.05), _p(0.0, -0.95), _p(0.5, 0.05)]), Color(1.0, 0.45, 0.1))
			draw_circle(_p(0.0, 0.38), _r * 0.32, Color(1.0, 0.85, 0.25))
		"lock":
			draw_rect(Rect2(_p(-0.6, -0.1), Vector2(1.2, 0.9) * _r), col)
			draw_arc(_p(0.0, -0.1), _r * 0.38, PI, TAU, 12, col, _r * 0.14)
			draw_circle(_p(0.0, 0.35), _r * 0.14, col2)
		"check":
			draw_polyline(PackedVector2Array([_p(-0.6, 0.05), _p(-0.15, 0.5), _p(0.65, -0.45)]), col, _r * 0.22)
		"bot":
			draw_line(_p(0.0, -0.85), _p(0.0, -0.5), col, _r * 0.1)
			draw_circle(_p(0.0, -0.85), _r * 0.12, col)
			draw_rect(Rect2(_p(-0.7, -0.5), Vector2(1.4, 1.2) * _r), col)
			draw_circle(_p(-0.3, 0.0), _r * 0.2, col2)
			draw_circle(_p(0.3, 0.0), _r * 0.2, col2)
			draw_rect(Rect2(_p(-0.3, 0.38), Vector2(0.6, 0.12) * _r), col2)
		"swords":
			draw_line(_p(-0.75, -0.75), _p(0.55, 0.55), col, _r * 0.18)
			draw_line(_p(0.75, -0.75), _p(-0.55, 0.55), col, _r * 0.18)
			draw_line(_p(0.3, 0.8), _p(0.8, 0.3), col, _r * 0.14)
			draw_line(_p(-0.3, 0.8), _p(-0.8, 0.3), col, _r * 0.14)
		"heart":
			draw_circle(_p(-0.3, -0.2), _r * 0.38, col)
			draw_circle(_p(0.3, -0.2), _r * 0.38, col)
			draw_colored_polygon(PackedVector2Array([_p(-0.66, -0.02), _p(0.66, -0.02), _p(0.0, 0.8)]), col)
		"tower":
			for i in 4:
				var w := 1.6 - float(i) * 0.35
				draw_rect(Rect2(_p(-w / 2.0, 0.55 - float(i) * 0.45), Vector2(w, 0.4) * _r), col)
	if badge:
		draw_circle(_p(0.8, -0.8), _r * 0.3, Color(1.0, 0.2, 0.25))
