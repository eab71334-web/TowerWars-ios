extends SceneTree

const RELAY := ["drop", "pos", "atk", "dead"]

var tcp := TCPServer.new()
var clients := {}
var rooms := {}
var waiting := -1
var next_id := 1

func _initialize() -> void:
	var port := int(OS.get_environment("PORT"))
	if port == 0:
		port = 8080
	var err := tcp.listen(port)
	print("Server listening on port ", port, " err=", err)

func _process(_delta: float) -> bool:
	while tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(tcp.take_connection())
		clients[next_id] = {"ws": ws, "peer": -1, "room": ""}
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
	return false

func _send(id: int, d: Dictionary) -> void:
	if clients.has(id):
		clients[id].ws.send_text(JSON.stringify(d))

func _pair(a: int, b: int) -> void:
	clients[a].peer = b
	clients[b].peer = a
	_send(a, {"t": "start"})
	_send(b, {"t": "start"})
	print("Match: ", a, " vs ", b)

func _handle(id: int, text: String) -> void:
	var m = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY:
		return
	var t: String = str(m.get("t", ""))
	var c: Dictionary = clients[id]

	if t == "find":
		if c.peer != -1 or c.room != "":
			return
		if waiting != -1 and waiting != id and clients.has(waiting):
			var other := waiting
			waiting = -1
			_pair(id, other)
		else:
			waiting = id
			_send(id, {"t": "waiting"})

	elif t == "create":
		if c.peer != -1 or c.room != "":
			return
		var code := str(randi_range(1000, 9999))
		while rooms.has(code):
			code = str(randi_range(1000, 9999))
		rooms[code] = id
		c.room = code
		_send(id, {"t": "created", "code": code})

	elif t == "join":
		if c.peer != -1:
			return
		var code := str(m.get("code", ""))
		if not rooms.has(code) or rooms[code] == id or not clients.has(rooms[code]):
			_send(id, {"t": "error", "m": "الكود غير صحيح"})
			return
		var host: int = rooms[code]
		rooms.erase(code)
		clients[host].room = ""
		_pair(id, host)

	elif t in RELAY:
		if c.peer != -1:
			_send(c.peer, m)

func _remove(id: int) -> void:
	if not clients.has(id):
		return
	if waiting == id:
		waiting = -1
	var room: String = clients[id].room
	if room != "":
		rooms.erase(room)
	var peer: int = clients[id].peer
	if peer != -1 and clients.has(peer):
		_send(peer, {"t": "left"})
		clients[peer].peer = -1
	clients.erase(id)
