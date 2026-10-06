extends Node

const RATE := 16000
const BPM := 112.0
const SAVE_PATH := "user://settings.cfg"

var music_on := true
var music_player: AudioStreamPlayer
var sfx_players: Array = []
var sfx := {}
var _thread: Thread

func _ready() -> void:
	_load_settings()
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -9.0
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		sfx_players.append(p)
	_build_sfx()
	_thread = Thread.new()
	_thread.start(_music_job)

func _music_job() -> void:
	var s := _make_music()
	_music_ready.call_deferred(s)

func _music_ready(s: AudioStreamWAV) -> void:
	_thread.wait_to_finish()
	music_player.stream = s
	if music_on:
		music_player.play()

func set_music(on: bool) -> void:
	music_on = on
	_save_settings()
	if music_player.stream == null:
		return
	if on:
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()

func play(id: String) -> void:
	if not sfx.has(id):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx[id]
			p.play()
			return
	var p0: AudioStreamPlayer = sfx_players[0]
	p0.stream = sfx[id]
	p0.play()

func click() -> void:
	play("click")

func drop() -> void:
	play("drop")

func perfect() -> void:
	play("perfect")

func hit() -> void:
	play("hit")

func win() -> void:
	play("win")

func lose() -> void:
	play("lose")

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		music_on = bool(cf.get_value("audio", "music", true))

func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_on)
	cf.save(SAVE_PATH)

func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.88 / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32760.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

func _add(buf: PackedFloat32Array, start: float, dur: float, freq: float, vol: float, kind: int) -> void:
	var size := buf.size()
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var decay := 4.0
	if kind == 0:
		decay = 3.0
	elif kind == 2:
		decay = 0.6
	for i in n:
		var t := float(i) / RATE
		var ph := TAU * freq * t
		var w := 0.0
		if kind == 1:
			w = sin(ph) * 0.6 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.12
		elif kind == 0:
			w = sin(ph) + sin(ph * 2.0) * 0.6
		else:
			w = sin(ph) * 0.6 + sin(ph * 1.004) * 0.6
		var env := minf(t / 0.012, 1.0) * exp(-t * decay) * clampf((dur - t) / 0.04, 0.0, 1.0)
		buf[(i0 + i) % size] += w * env * vol

func _kick(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var size := buf.size()
	var i0 := int(start * RATE)
	var n := int(0.16 * RATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (45.0 + 110.0 * exp(-t * 28.0)) / RATE
		buf[(i0 + i) % size] += sin(ph) * exp(-t * 18.0) * vol

func _hat(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var size := buf.size()
	var i0 := int(start * RATE)
	var n := int(0.05 * RATE)
	for i in n:
		var t := float(i) / RATE
		buf[(i0 + i) % size] += (randf() * 2.0 - 1.0) * exp(-t * 70.0) * vol

func _make_music() -> AudioStreamWAV:
	var beat := 60.0 / BPM
	var total := int(16.0 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var chords := [
		{"bass": 45, "tones": [57, 60, 64]},
		{"bass": 41, "tones": [53, 57, 60]},
		{"bass": 48, "tones": [55, 60, 64]},
		{"bass": 43, "tones": [59, 62, 67]},
	]
	var pattern := [0, 1, 2, 1, 0, 1, 2, 2]
	for c in 4:
		var ch: Dictionary = chords[c]
		var tones: Array = ch.tones
		var t0 := c * 4.0 * beat
		_add(buf, t0, 1.5 * beat, _midi(ch.bass), 0.55, 0)
		_add(buf, t0 + 2.0 * beat, 1.0 * beat, _midi(ch.bass), 0.5, 0)
		_add(buf, t0 + 3.5 * beat, 0.5 * beat, _midi(ch.bass + 7), 0.4, 0)
		_add(buf, t0, 4.0 * beat, _midi(tones[0]), 0.10, 2)
		_add(buf, t0, 4.0 * beat, _midi(tones[2]), 0.10, 2)
		for k in 8:
			var note: int = int(tones[pattern[k]]) + 12
			_add(buf, t0 + k * beat * 0.5, beat * 0.6, _midi(note), 0.28, 1)
		for b in 4:
			_kick(buf, t0 + b * beat, 0.9)
			_hat(buf, t0 + (b + 0.5) * beat, 0.18)
	return _to_wav(buf, true)

func _seq(freqs: Array, step: float, tail: float, kind: int, vol: float) -> AudioStreamWAV:
	var n := int((freqs.size() * step + tail) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in freqs.size():
		_add(buf, i * step, step + tail, float(freqs[i]), vol, kind)
	return _to_wav(buf, false)

func _build_sfx() -> void:
	sfx["click"] = _seq([_midi(84)], 0.05, 0.06, 1, 0.8)
	sfx["perfect"] = _seq([_midi(72), _midi(76), _midi(79), _midi(84)], 0.07, 0.2, 1, 0.8)
	sfx["win"] = _seq([_midi(60), _midi(64), _midi(67), _midi(72), _midi(76), _midi(79)], 0.11, 0.35, 1, 0.8)
	sfx["lose"] = _seq([_midi(67), _midi(64), _midi(60), _midi(55)], 0.16, 0.3, 0, 0.9)
	var d := PackedFloat32Array()
	d.resize(int(0.25 * RATE))
	_kick(d, 0.0, 1.0)
	sfx["drop"] = _to_wav(d, false)
	var h := PackedFloat32Array()
	h.resize(int(0.3 * RATE))
	for i in h.size():
		var t := float(i) / RATE
		h[i] = (randf() * 2.0 - 1.0) * exp(-t * 9.0) * 0.8 + sin(TAU * 70.0 * t) * exp(-t * 8.0)
	sfx["hit"] = _to_wav(h, false)
