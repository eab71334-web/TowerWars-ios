extends Control

const NavBar = preload("res://navbar.gd")
const GOLD := Color(1.0, 0.86, 0.2)
const GREEN := Color(0.15, 0.75, 0.42)

var vb: VBoxContainer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 175)
	add_child(margin)
	var nav = NavBar.new()
	nav.current = "challenges"
	add_child(nav)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	scroll.add_child(vb)
	_build()

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.style(Color(0.12, 0.08, 0.4, 0.95), 34, 10)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 24.0
	p.add_theme_stylebox_override("panel", sb)
	return p

func _label(text: String, fs: int, color: Color, outline: int) -> Label:
	var l := UI.label(text, fs, color, outline)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

func _build() -> void:
	for c in vb.get_children():
		c.queue_free()

	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(NavBar.coin_pill())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_label("التحديات", 60, GOLD, 12))

	# ----- المكافأة اليومية -----
	var dc := _panel()
	vb.add_child(dc)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 14)
	dc.add_child(dv)
	var dh := HBoxContainer.new()
	dh.alignment = BoxContainer.ALIGNMENT_CENTER
	dh.add_theme_constant_override("separation", 10)
	dv.add_child(dh)
	dh.add_child(NavBar.icon("flame", 44))
	dh.add_child(_label("المكافأة اليومية", 38, Color.WHITE, 8))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	dv.add_child(chips)
	var idx := Data.daily_idx()
	var avail := Data.daily_available()
	for d in range(6, -1, -1):
		chips.add_child(_chip(d, idx, avail))
	if avail:
		var b := UI.button("استلم %d عملة" % int(Data.DAILY[idx]), GREEN, 96, 36)
		b.pressed.connect(_claim_daily)
		dv.add_child(b)
	else:
		dv.add_child(_label("عد غداً لمكافأة أكبر", 28, Color(1, 1, 1, 0.7), 0))

	# ----- تحديات اليوم -----
	vb.add_child(_label("تحديات اليوم", 38, Color(0.75, 0.95, 1.0), 8))
	for ch in Data.daily_challenges():
		vb.add_child(_challenge(ch))
	vb.add_child(_label("تتجدد التحديات كل يوم", 24, Color(1, 1, 1, 0.55), 0))

func _chip(d: int, idx: int, avail: bool) -> Control:
	var done := d < idx or (d == idx and not avail)
	var cur := d == idx and avail
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Color(0.2, 0.15, 0.5, 0.9)
	if done:
		col = Color(0.15, 0.55, 0.35, 0.95)
	elif cur:
		col = GOLD.darkened(0.15)
	var sb := UI.style(col, 20, 6)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(_label(str(d + 1), 24, Color.WHITE, 4))
	var ic := NavBar.icon("check" if done else "coin", 36, Color.WHITE)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(_label(str(Data.DAILY[d]), 22, Color.WHITE, 4))
	return p

func _pill(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(150, 76)
	var sb := UI.style(color, 28, 6)
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 26, Color.WHITE, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	return p

func _challenge(ch: Dictionary) -> Control:
	var i := int(ch.i)
	var target := int(ch.target)
	var prog := Data.progress_of(str(ch.kind))
	var done := prog >= target
	var claimed := Data.is_claimed(i)

	var p := _panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)

	if claimed:
		h.add_child(_pill("تم ✓", Color(0.3, 0.3, 0.5)))
	elif done:
		var b := UI.button("استلم", GREEN, 76, 30)
		b.custom_minimum_size = Vector2(150, 76)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(_claim.bind(i))
		h.add_child(b)
	else:
		h.add_child(_pill("%d/%d" % [mini(prog, target), target], Color(0.25, 0.2, 0.55)))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	h.add_child(info)
	info.add_child(UI.label(str(ch.text), 28, Color.WHITE, 6))
	info.add_child(NavBar.bar(float(mini(prog, target)), float(target), GREEN if done else GOLD, 20.0))
	var rr := HBoxContainer.new()
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_theme_constant_override("separation", 8)
	info.add_child(rr)
	rr.add_child(NavBar.icon("coin", 32))
	rr.add_child(_label("+%d" % int(ch.reward), 26, GOLD, 4))
	return p

func _claim_daily() -> void:
	var n := Data.claim_daily()
	if n > 0:
		Sfx.win()
		Net.toast("+%d عملة" % n)
	_build()

func _claim(i: int) -> void:
	var n := Data.claim_challenge(i)
	if n > 0:
		Sfx.win()
		Net.toast("+%d عملة" % n)
	_build()
