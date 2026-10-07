extends Node

signal message(m: Dictionary)
signal connected
signal disconnected
signal profile_changed
signal friends_changed

const SERVER_URL := "wss://towerwars-ios-production.up.railway.app"
const SAVE_PATH := "user://auth.cfg"

var ws := WebSocketPeer.new()
var is_open := false
var token := ""
var skipped_login := false
var profile: Dictionary = {}
var friends: Array = []
var requests: Array = []
var start_pending := false
var start_msg: Dictionary = {}
var in_match_scene := false
var retry_t := 0.0
var ping_t := 0.0
var invite_cid := -1

var layer: CanvasLayer
var banner: PanelContainer
var banner_label: Label
var toast_label: Label
var toast_tween: Tween

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		token = str(cf.get_value("auth", "token", ""))
		skipped_login = bool(cf.get_value("auth", "skipped", false))
	_build_ui()

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("auth", "token", token)
	cf.set_value("auth", "skipped", skipped_login)
	cf.save(SAVE_PATH)

func logged_in() -> bool:
	return not profile.is_empty()

func send(d: Dictionary) -> void:
	if is_open:
		ws.send_text(JSON.stringify(d))

func logout() -> void:
	send({"t": "logout", "token": token})
	token = ""
	profile = {}
	friends = []
	requests = []
	skipped_login = true
	save()
	profile_changed.emit()
	friends_changed.emit()

func _connect() -> void:
	ws = WebSocketPeer.new()
	var err := ws.connect_to_url(SERVER_URL)
	if err != OK:
		print("connect error ", err)

func _process(delta: float) -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not is_open:
			is_open = true
			retry_t = 0.0
			if token != "":
				send({"t": "auth", "token": token})
			connected.emit()
		while ws.get_available_packet_count() > 0:
			var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if typeof(m) == TYPE_DICTIONARY:
				_on(m)
		ping_t += delta
		if ping_t > 20.0:
			ping_t = 0.0
			send({"t": "ping"})
	elif st == WebSocketPeer.STATE_CLOSED:
		if is_open:
			is_open = false
			disconnected.emit()
		retry_t -= delta
		if retry_t <= 0.0:
			retry_t = 3.0
			_connect()

func _on(m: Dictionary) -> void:
	var t := str(m.get("t", ""))
	match t:
		"authed":
			token = str(m["token"])
			profile = m["profile"]
			save()
			profile_changed.emit()
		"auth_fail":
			token = ""
			profile = {}
			save()
			profile_changed.emit()
		"profile":
			profile = m["profile"]
			profile_changed.emit()
		"friends":
			friends = m["friends"]
			requests = m["requests"]
			friends_changed.emit()
		"fr_in":
			var f: Dictionary = m["from"]
			toast("%s أرسل لك طلب صداقة" % str(f.get("name", "")))
		"ch_in":
			_show_invite(m)
		"ch_cancel":
			_hide_invite()
		"toast":
			toast(str(m.get("m", "")))
		"start":
			if not in_match_scene:
				start_pending = true
				start_msg = m
				_hide_invite()
				Engine.set_meta("mode", "invited")
				get_tree().change_scene_to_file("res://online.tscn")
				return
	message.emit(m)

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	banner = PanelContainer.new()
	banner.custom_minimum_size = Vector2(672, 0)
	var sb := UI.style(Color(0.12, 0.07, 0.4, 0.97), 36, 10)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	banner.add_theme_stylebox_override("panel", sb)
	banner.position = Vector2(24, -400)
	banner.visible = false
	layer.add_child(banner)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	banner.add_child(vb)
	banner_label = UI.label("", 38, Color(1.0, 0.86, 0.2), 8)
	vb.add_child(banner_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	var yes := UI.button("موافق", Color(0.15, 0.75, 0.42), 90, 36)
	yes.pressed.connect(_reply.bind(true))
	var no := UI.button("رفض", Color(0.9, 0.3, 0.35), 90, 36)
	no.pressed.connect(_reply.bind(false))
	row.add_child(yes)
	row.add_child(no)

	toast_label = UI.label("", 32, Color.WHITE, 0)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 80.0
	toast_label.offset_right = -80.0
	toast_label.offset_top = -190.0
	toast_label.offset_bottom = -110.0
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", UI.style(Color(0.1, 0.05, 0.3, 0.94), 30, 0))
	toast_label.modulate.a = 0.0
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_label)

func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)

func _show_invite(m: Dictionary) -> void:
	var f: Dictionary = m["from"]
	invite_cid = int(m["cid"])
	banner_label.text = "%s يتحداك! (م%d)" % [str(f.get("name", "")), int(f.get("level", 1))]
	banner.visible = true
	banner.position.y = -400.0
	Sfx.perfect()
	Input.vibrate_handheld(200)
	create_tween().tween_property(banner, "position:y", 70.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_invite() -> void:
	invite_cid = -1
	if banner.visible:
		var tw := create_tween()
		tw.tween_property(banner, "position:y", -400.0, 0.25)
		tw.finished.connect(func(): banner.visible = false)

func _reply(ok: bool) -> void:
	send({"t": "ch_reply", "cid": invite_cid, "ok": ok})
	_hide_invite()
