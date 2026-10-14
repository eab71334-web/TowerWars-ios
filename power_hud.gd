extends Control

const PW = preload("res://powers.gd")
const PowerIcon = preload("res://power_icon.gd")

signal pressed(id: String)

var icons: Dictionary = {}

func build(vw: float, y: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	var ids: Array = PW.get_loadout()
	var d := 108.0
	var gap := 44.0
	var total := float(ids.size()) * d + float(maxi(ids.size() - 1, 0)) * gap
	var x := (vw - total) / 2.0
	for id in ids:
		var ic = PowerIcon.new()
		ic.pid = str(id)
		ic.show_count = true
		ic.position = Vector2(x, y)
		ic.size = Vector2(d, d)
		ic.tapped.connect(_on_tap.bind(str(id)))
		add_child(ic)
		icons[str(id)] = ic
		x += d + gap

func _on_tap(id: String) -> void:
	pressed.emit(id)

func refresh(fx, cool: Dictionary) -> void:
	for id in icons:
		var ic = icons[id]
		ic.count = PW.count(str(id))
		var d: Dictionary = PW.def(str(id))
		if str(d.kind) == "self":
			ic.ring = fx.frac(str(id))
		else:
			ic.ring = clampf(float(cool.get(id, 0.0)) / 3.0, 0.0, 1.0)
		ic.queue_redraw()
