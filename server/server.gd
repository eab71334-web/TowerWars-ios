extends SceneTree

const RELAY := ["drop", "pos", "atk", "dead"]
const GOOGLE_DEVICE := "https://oauth2.googleapis.com/device/code"
const GOOGLE_TOKEN := "https://oauth2.googleapis.com/token"
const CH_TIMEOUT_MS := 30000
const MIN_MATCH_MS := 15000

var tcp := TCPServer.new()
var clients := {}
var rooms := {}
var pending := {}
var waiting := -1
var next_id := 1
var db := {"next": 100000, "users": {}, "google": {}, "tokens": {}, "accounts": {}}
var db_path := ""
var g_id := ""
var g_secret := ""

func _initialize() -> void:
	randomize()
	g_id = OS.get_environment("GOOGLE_CLIENT_ID")
	g_secret = OS.get_environment("GOOGLE_CLIENT_SECRET")
	var dir := OS.get_environment("DATA_DIR")
	if dir == "":
		dir = "/data"
	if not DirAccess.dir_exists_absolute(dir):
		print("WARNING: no volume at ", dir, " - accounts are lost on redeploy")
		dir = "user://"
	db_path = dir.path_join("accounts.json")
	_load_db()
	var port := int(OS.get_environment("PORT"))
	if port == 0:
		port = 8080
	var err := tcp.listen(port)
	print("Server listening on port ", port, " err=", err)
	print("google configured: ", g_id != "" and g_secret != "")
	print("db: ", db_path, " users=", db.users.size())

func _load_db() -> void:
	if not FileAccess.file_exists(db_path):
		return
	var f := FileAccess.open(db_path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		for k in ["next", "users", "google", "tokens", "accounts"]:
			if d.has(k):
				db[k] = d[k]

func _save_db() -> void:
	var f := FileAccess.open(db_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(db))

func _process(_delta: float) -> bool:
	while tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(tcp.take_connection())
		clients[next_id] = {"ws": ws, "peer": -1, "room": "", "user": "", "matched": false, "reported": false, "t0": 0, "gflow": 0, "fails": 0}
		next_id += 1

	for id in clients.keys():
		if not clients.has(id):
			continue
		var ws: WebSocketPeer = clients[id].ws
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0 and clients.has(id):
				_handle(id, ws.get_packet().get_string_from_utf8())
		elif st == WebSocketPeer.STATE_CLOSED:
			_remove(id)

	var now := Time.get_ticks_msec()
	for cid in pending.keys():
		var p: Dictionary = pending[cid]
		if now - int(p.t0) > CH_TIMEOUT_MS:
			pending.erase(cid)
			_send(int(cid), {"t": "ch_timeout"})
			_send(int(p.to), {"t": "ch_cancel"})
	return false

func _send(id: int, d: Dictionary) -> void:
	if clients.has(id):
		clients[id].ws.send_text(JSON.stringify(d))

func _uid(id: int) -> String:
	if not clients.has(id):
		return ""
	return str(clients[id].user)

func _level(xp: int) -> int:
	return 1 + int(sqrt(float(xp) / 40.0))

func _pub(pid: String) -> Dictionary:
	if not db.users.has(pid):
		return {}
	var u: Dictionary = db.users[pid]
	var xp := int(u.xp)
	var lv := _level(xp)
	var base := (lv - 1) * (lv - 1) * 40
	var nxt := lv * lv * 40
	return {"id": pid, "name": str(u.name), "level": lv, "xp": xp - base, "need": nxt - base, "wins": int(u.wins), "losses": int(u.losses), "online": _online_cid(pid) != -1}

func _online_cid(pid: String) -> int:
	for cid in clients:
		if str(clients[cid].user) == pid:
			return int(cid)
	return -1

func _notify_user(pid: String, d: Dictionary) -> void:
	for cid in clients:
		if str(clients[cid].user) == pid:
			_send(int(cid), d)

func _friends_payload(pid: String) -> Dictionary:
	var u: Dictionary = db.users[pid]
	var fl: Array = []
	var rq: Array = []
	for f in u.friends:
		fl.append(_pub(str(f)))
	for r in u.req:
		rq.append(_pub(str(r)))
	fl.sort_custom(func(a, b): return a.online and not b.online)
	return {"t": "friends", "friends": fl, "requests": rq}

func _push_user(pid: String) -> void:
	if not db.users.has(pid):
		return
	_notify_user(pid, _friends_payload(pid))

func _clean(s: String) -> String:
	var n := s.strip_edges().substr(0, 16)
	if n == "":
		return "لاعب"
	return n

func _new_token() -> String:
	return Crypto.new().generate_random_bytes(24).hex_encode()

func _handle(id: int, text: String) -> void:
	var m = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY:
		return
	var t := str(m.get("t", ""))
	if t in RELAY:
		var peer: int = clients[id].peer
		if peer != -1:
			_send(peer, m)
		return
	match t:
		"ping":
			pass
		"auth":
			_auth(id, str(m.get("token", "")))
		"register":
			_register(id, str(m.get("user", "")), str(m.get("pass", "")), str(m.get("name", "")))
		"login":
			_login(id, str(m.get("user", "")), str(m.get("pass", "")))
		"g_start":
			_g_start(id)
		"logout":
			db.tokens.erase(str(m.get("token", "")))
			clients[id].user = ""
			_save_db()
		"set_name":
			_set_name(id, str(m.get("name", "")))
		"friends":
			var me := _uid(id)
			if me != "":
				_send(id, _friends_payload(me))
		"search":
			_send(id, {"t": "search_res", "res": _search(str(m.get("q", "")), _uid(id))})
		"fr_add":
			_fr_add(id, str(m.get("id", "")))
		"fr_accept":
			_fr_accept(id, str(m.get("id", "")))
		"fr_decline":
			_fr_decline(id, str(m.get("id", "")))
		"fr_del":
			_fr_del(id, str(m.get("id", "")))
		"ch_send":
			_ch_send(id, str(m.get("id", "")))
		"ch_cancel":
			_ch_cancel(id)
		"ch_reply":
			_ch_reply(id, int(m.get("cid", -1)), bool(m.get("ok", false)))
		"find":
			_find(id)
		"create":
			_create(id)
		"join":
			_join(id, str(m.get("code", "")))
		"leave":
			_leave(id, bool(m.get("done", false)))
		"result":
			_result(id, int(m.get("r", 0)))

# ---------- الحسابات ----------

func _auth(id: int, tok: String) -> void:
	if db.tokens.has(tok) and db.users.has(str(db.tokens[tok])):
		var pid := str(db.tokens[tok])
		clients[id].user = pid
		_send(id, {"t": "authed", "token": tok, "profile": _pub(pid)})
		_send(id, _friends_payload(pid))
	else:
		_send(id, {"t": "auth_fail"})

func _set_name(id: int, n: String) -> void:
	var me := _uid(id)
	if me == "":
		return
	db.users[me].name = _clean(n)
	_save_db()
	_send(id, {"t": "profile", "profile": _pub(me)})

func _issue(id: int, pid: String) -> void:
	var tok := _new_token()
	db.tokens[tok] = pid
	_save_db()
	clients[id].user = pid
	_send(id, {"t": "authed", "token": tok, "profile": _pub(pid)})
	_send(id, _friends_payload(pid))

# ---------- حسابات اسم المستخدم (مؤقتة) ----------

func _hash_pw(pw: String, salt: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((salt + pw).to_utf8_buffer())
	return ctx.finish().hex_encode()

func _valid_user(u: String) -> bool:
	if u.length() < 3 or u.length() > 16:
		return false
	for i in u.length():
		var c := u.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 97 and c <= 122) or c == 95
		if not ok:
			return false
	return true

func _register(id: int, user: String, pw: String, disp: String) -> void:
	user = user.strip_edges().to_lower()
	if not _valid_user(user):
		_send(id, {"t": "acc_err", "m": "اسم المستخدم: 3 إلى 16 حرف إنجليزي صغير أو رقم أو _"})
		return
	if pw.length() < 4 or pw.length() > 40:
		_send(id, {"t": "acc_err", "m": "كلمة السر: 4 أحرف على الأقل"})
		return
	if db.accounts.has(user):
		_send(id, {"t": "acc_err", "m": "اسم المستخدم محجوز، اختر غيره"})
		return
	db.next = int(db.next) + 1
	var pid := str(int(db.next))
	var salt := _new_token().substr(0, 16)
	var shown := disp.strip_edges()
	if shown == "":
		shown = user
	db.users[pid] = {"id": pid, "name": _clean(shown), "xp": 0, "wins": 0, "losses": 0, "friends": [], "req": []}
	db.accounts[user] = {"pid": pid, "salt": salt, "hash": _hash_pw(pw, salt)}
	_issue(id, pid)

func _login(id: int, user: String, pw: String) -> void:
	user = user.strip_edges().to_lower()
	var c: Dictionary = clients[id]
	if int(c.get("fails", 0)) >= 5:
		_send(id, {"t": "acc_err", "m": "محاولات كثيرة، أعد فتح اللعبة"})
		return
	var good := false
	if db.accounts.has(user):
		var a: Dictionary = db.accounts[user]
		good = _hash_pw(pw, str(a.salt)) == str(a.hash)
	if not good:
		c["fails"] = int(c.get("fails", 0)) + 1
		_send(id, {"t": "acc_err", "m": "اسم المستخدم أو كلمة السر خطأ"})
		return
	_issue(id, str(db.accounts[user].pid))

# ---------- Google (للمستقبل) ----------

func _post_form(url: String, fields: Dictionary) -> Dictionary:
	var req := HTTPRequest.new()
	root.add_child(req)
	var parts := PackedStringArray()
	for k in fields:
		parts.append("%s=%s" % [str(k).uri_encode(), str(fields[k]).uri_encode()])
	var err := req.request(url, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, "&".join(parts))
	if err != OK:
		req.queue_free()
		return {"_err": "request %d" % err}
	var res = await req.request_completed
	req.queue_free()
	var body: PackedByteArray = res[3]
	var d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return {"_err": "bad response %d" % int(res[1])}
	return d

func _jwt_claims(jwt: String) -> Dictionary:
	var parts := jwt.split(".")
	if parts.size() < 2:
		return {}
	var p: String = parts[1].replace("-", "+").replace("_", "/")
	while p.length() % 4 != 0:
		p += "="
	var d = JSON.parse_string(Marshalls.base64_to_raw(p).get_string_from_utf8())
	if typeof(d) == TYPE_DICTIONARY:
		return d
	return {}

func _g_start(id: int) -> void:
	if g_id == "" or g_secret == "":
		_send(id, {"t": "g_err", "m": "الخادم غير مهيأ لـ Google"})
		return
	clients[id].gflow += 1
	var flow: int = clients[id].gflow
	var d: Dictionary = await _post_form(GOOGLE_DEVICE, {"client_id": g_id, "scope": "openid email profile"})
	if not clients.has(id) or clients[id].gflow != flow:
		return
	if not d.has("device_code"):
		print("google device error: ", d)
		_send(id, {"t": "g_err", "m": "تعذر بدء الدخول: %s" % str(d.get("error", d.get("_err", "?")))})
		return
	_send(id, {"t": "g_code", "code": str(d.user_code), "url": str(d.get("verification_url", "https://www.google.com/device"))})
	var interval := float(d.get("interval", 5))
	var left := float(d.get("expires_in", 600))
	while left > 0.0:
		await create_timer(interval).timeout
		left -= interval
		if not clients.has(id) or clients[id].gflow != flow:
			return
		var r: Dictionary = await _post_form(GOOGLE_TOKEN, {
			"client_id": g_id, "client_secret": g_secret,
			"device_code": str(d.device_code),
			"grant_type": "urn:ietf:params:oauth:grant-type:device_code"})
		if not clients.has(id) or clients[id].gflow != flow:
			return
		if r.has("id_token"):
			var claims := _jwt_claims(str(r.id_token))
			if claims.has("sub"):
				_finish_login(id, claims)
			else:
				_send(id, {"t": "g_err", "m": "رد غير صالح من Google"})
			return
		var e := str(r.get("error", ""))
		if e == "authorization_pending":
			continue
		if e == "slow_down":
			interval += 5.0
			continue
		print("google token error: ", r)
		_send(id, {"t": "g_err", "m": "فشل الدخول: %s" % (e if e != "" else str(r.get("_err", "")))})
		return
	_send(id, {"t": "g_err", "m": "انتهت مهلة الكود، حاول من جديد"})

func _finish_login(id: int, claims: Dictionary) -> void:
	var sub := str(claims.sub)
	var pid := ""
	if db.google.has(sub):
		pid = str(db.google[sub])
	else:
		db.next = int(db.next) + 1
		pid = str(int(db.next))
		db.users[pid] = {"id": pid, "name": _clean(str(claims.get("name", "لاعب"))), "xp": 0, "wins": 0, "losses": 0, "friends": [], "req": []}
		db.google[sub] = pid
	_issue(id, pid)

# ---------- الأصدقاء ----------

func _search(q: String, me: String) -> Array:
	var out: Array = []
	q = q.strip_edges().to_lower()
	if q == "":
		return out
	if q != me and db.users.has(q):
		out.append(_pub(q))
	for pid in db.users:
		if out.size() >= 15:
			break
		if pid == me or pid == q:
			continue
		if str(db.users[pid].name).to_lower().contains(q):
			out.append(_pub(str(pid)))
	return out

func _fr_add(id: int, target: String) -> void:
	var me := _uid(id)
	if me == "":
		_send(id, {"t": "toast", "m": "سجّل الدخول أولاً"})
		return
	if target == me or not db.users.has(target):
		_send(id, {"t": "toast", "m": "اللاعب غير موجود"})
		return
	var u: Dictionary = db.users[me]
	var o: Dictionary = db.users[target]
	if u.friends.has(target):
		_send(id, {"t": "toast", "m": "هو صديقك بالفعل"})
	elif u.req.has(target):
		_link(me, target)
	else:
		if not o.req.has(me):
			o.req.append(me)
			_save_db()
		_notify_user(target, {"t": "fr_in", "from": _pub(me)})
		_push_user(target)
		_send(id, {"t": "toast", "m": "تم إرسال طلب الصداقة"})

func _link(a: String, b: String) -> void:
	var ua: Dictionary = db.users[a]
	var ub: Dictionary = db.users[b]
	ua.req.erase(b)
	ub.req.erase(a)
	if not ua.friends.has(b):
		ua.friends.append(b)
	if not ub.friends.has(a):
		ub.friends.append(a)
	_save_db()
	_push_user(a)
	_push_user(b)
	_notify_user(b, {"t": "toast", "m": "%s صار صديقك" % str(ua.name)})

func _fr_accept(id: int, other: String) -> void:
	var me := _uid(id)
	if me == "" or not db.users.has(other):
		return
	if db.users[me].req.has(other):
		_link(me, other)

func _fr_decline(id: int, other: String) -> void:
	var me := _uid(id)
	if me == "":
		return
	db.users[me].req.erase(other)
	_save_db()
	_push_user(me)

func _fr_del(id: int, other: String) -> void:
	var me := _uid(id)
	if me == "" or not db.users.has(other):
		return
	db.users[me].friends.erase(other)
	db.users[other].friends.erase(me)
	_save_db()
	_push_user(me)
	_push_user(other)

func _ch_send(id: int, target: String) -> void:
	var me := _uid(id)
	if me == "":
		_send(id, {"t": "ch_fail", "m": "سجّل الدخول أولاً"})
		return
	if not db.users[me].friends.has(target):
		_send(id, {"t": "ch_fail", "m": "ليس صديقك"})
		return
	var tcid := _online_cid(target)
	if tcid == -1:
		_send(id, {"t": "ch_fail", "m": "صديقك غير متصل"})
		return
	if int(clients[tcid].peer) != -1:
		_send(id, {"t": "ch_fail", "m": "صديقك في مباراة الآن"})
		return
	_ch_cancel(id)
	pending[id] = {"to": tcid, "t0": Time.get_ticks_msec()}
	_send(tcid, {"t": "ch_in", "from": _pub(me), "cid": id})
	_send(id, {"t": "ch_wait"})

func _ch_cancel(id: int) -> void:
	if pending.has(id):
		var target := int(pending[id].to)
		pending.erase(id)
		_send(target, {"t": "ch_cancel"})

func _ch_reply(id: int, cid: int, ok: bool) -> void:
	if not pending.has(cid) or int(pending[cid].to) != id:
		return
	pending.erase(cid)
	if not clients.has(cid):
		return
	if not ok:
		_send(cid, {"t": "ch_declined"})
		return
	if int(clients[id].peer) != -1 or int(clients[cid].peer) != -1:
		_send(cid, {"t": "ch_fail", "m": "أحدكم في مباراة"})
		return
	_leave(id, true)
	_leave(cid, true)
	_pair(cid, id)

# ---------- المباريات ----------

func _opp_info(cid: int) -> Dictionary:
	var pid := _uid(cid)
	if pid == "":
		return {"name": "ضيف", "level": 1}
	var p := _pub(pid)
	return {"name": p.name, "level": p.level}

func _pair(a: int, b: int) -> void:
	for pr in [[a, b], [b, a]]:
		var x: int = pr[0]
		var y: int = pr[1]
		clients[x].peer = y
		clients[x].matched = true
		clients[x].reported = false
		clients[x].t0 = Time.get_ticks_msec()
		_send(x, {"t": "start", "opp": _opp_info(y)})
	print("Match: ", a, " vs ", b)

func _cancel_wait(id: int) -> void:
	if waiting == id:
		waiting = -1
	if clients.has(id) and str(clients[id].room) != "":
		rooms.erase(str(clients[id].room))
		clients[id].room = ""

func _leave(id: int, done: bool) -> void:
	if not clients.has(id):
		return
	var c: Dictionary = clients[id]
	_cancel_wait(id)
	_ch_cancel(id)
	var peer: int = c.peer
	if peer != -1 and clients.has(peer):
		if not done:
			_send(peer, {"t": "left"})
		clients[peer].peer = -1
	c.peer = -1
	c.matched = false

func _find(id: int) -> void:
	_leave(id, true)
	if waiting != -1 and waiting != id and clients.has(waiting):
		var other := waiting
		waiting = -1
		_pair(id, other)
	else:
		waiting = id
		_send(id, {"t": "waiting"})

func _create(id: int) -> void:
	_leave(id, true)
	var code := str(randi_range(1000, 9999))
	while rooms.has(code):
		code = str(randi_range(1000, 9999))
	rooms[code] = id
	clients[id].room = code
	_send(id, {"t": "created", "code": code})

func _join(id: int, code: String) -> void:
	_leave(id, true)
	if not rooms.has(code) or int(rooms[code]) == id or not clients.has(int(rooms[code])):
		_send(id, {"t": "error", "m": "الكود غير صحيح"})
		return
	var host := int(rooms[code])
	rooms.erase(code)
	clients[host].room = ""
	_pair(id, host)

func _result(id: int, r: int) -> void:
	var c: Dictionary = clients[id]
	if not c.matched or c.reported:
		return
	c.reported = true
	var me := str(c.user)
	if me == "" or Time.get_ticks_msec() - int(c.t0) < MIN_MATCH_MS:
		return
	var u: Dictionary = db.users[me]
	if r > 0:
		u.wins = int(u.wins) + 1
		u.xp = int(u.xp) + 30
	elif r < 0:
		u.losses = int(u.losses) + 1
		u.xp = int(u.xp) + 10
	else:
		u.xp = int(u.xp) + 15
	_save_db()
	_send(id, {"t": "profile", "profile": _pub(me)})

func _remove(id: int) -> void:
	if not clients.has(id):
		return
	for cid in pending.keys():
		if int(pending[cid].to) == id:
			pending.erase(cid)
			_send(int(cid), {"t": "ch_fail", "m": "صديقك خرج"})
	_leave(id, false)
	clients.erase(id)
