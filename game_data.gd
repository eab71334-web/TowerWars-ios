extends Node

signal coins_changed

const SAVE_PATH := "user://data.cfg"
const GAME_NAME := "برج الكتل"
const GAME_SUB := "BLOCK CLASH"

var DAILY := [20, 30, 40, 50, 70, 100, 200]

var SKINS := [
	{"id": "classic", "name": "كلاسيك", "price": 0, "k": "rainbow", "step": 0.045, "s": 0.65, "v": 0.95},
	{"id": "neon", "name": "نيون", "price": 150, "k": "rainbow", "step": 0.08, "s": 0.95, "v": 1.0},
	{"id": "candy", "name": "حلوى", "price": 200, "k": "list", "cols": [Color(1.0, 0.6, 0.75), Color(0.6, 1.0, 0.85), Color(1.0, 0.95, 0.6), Color(0.75, 0.7, 1.0)]},
	{"id": "ice", "name": "جليد", "price": 250, "k": "wave", "lo": 0.5, "hi": 0.62, "freq": 0.45, "s": 0.55, "v": 1.0},
	{"id": "forest", "name": "غابة", "price": 250, "k": "wave", "lo": 0.25, "hi": 0.4, "freq": 0.45, "s": 0.7, "v": 0.85},
	{"id": "gold", "name": "ذهب", "price": 300, "k": "lerp", "a": Color(1.0, 0.9, 0.3), "b": Color(1.0, 0.55, 0.1)},
	{"id": "lava", "name": "حمم", "price": 350, "k": "wave", "lo": 0.0, "hi": 0.12, "freq": 0.5, "s": 0.9, "v": 1.0},
	{"id": "galaxy", "name": "مجرة", "price": 400, "k": "wave", "lo": 0.72, "hi": 0.93, "freq": 0.5, "s": 0.75, "v": 1.0},
	{"id": "sunset", "name": "غروب", "price": 450, "k": "lerp", "a": Color(1.0, 0.35, 0.55), "b": Color(1.0, 0.75, 0.2)},
	{"id": "royal", "name": "ملكي", "price": 500, "k": "list", "cols": [Color(0.45, 0.25, 0.85), Color(1.0, 0.82, 0.25)]},
]

var MODES := [
	{"id": "classic", "name": "كلاسيك", "desc": "ابنِ أعلى برج ممكن، وأي ضربة فاشلة تنهي اللعبة", "icon": "tower", "color": Color(0.18, 0.52, 1.0), "start_w": 300.0, "base": 320.0, "grow": 10.0, "time": 0.0, "lives": 1, "tol": 10.0},
	{"id": "speed", "name": "سرعة", "desc": "كتل أسرع وتتسارع أكثر مع كل طابق", "icon": "bolt", "color": Color(0.95, 0.3, 0.65), "start_w": 300.0, "base": 520.0, "grow": 20.0, "time": 0.0, "lives": 1, "tol": 12.0},
	{"id": "timed", "name": "ضد الوقت", "desc": "60 ثانية فقط، ابنِ أعلى ما تقدر", "icon": "flame", "color": Color(1.0, 0.58, 0.08), "start_w": 300.0, "base": 360.0, "grow": 8.0, "time": 60.0, "lives": 1, "tol": 10.0},
	{"id": "lives", "name": "ثلاث أرواح", "desc": "تتحمل 3 أخطاء كاملة قبل ما تنتهي", "icon": "heart", "color": Color(0.9, 0.3, 0.35), "start_w": 300.0, "base": 340.0, "grow": 10.0, "time": 0.0, "lives": 3, "tol": 10.0},
	{"id": "precision", "name": "الدقة", "desc": "كتل رفيعة وضبط صعب، للمحترفين", "icon": "target", "color": Color(0.6, 0.4, 1.0), "start_w": 170.0, "base": 360.0, "grow": 12.0, "time": 0.0, "lives": 3, "tol": 6.0},
	{"id": "zen", "name": "هدوء", "desc": "دقيقتان بدون ضغط وبسرعة بطيئة", "icon": "star", "color": Color(0.15, 0.75, 0.42), "start_w": 320.0, "base": 230.0, "grow": 0.0, "time": 120.0, "lives": 99, "tol": 14.0},
]

var TEMPLATES := [
	{"kind": "blocks", "text": "ابنِ %d كتلة في الأنماط", "t": [40, 90], "as_max": false, "r": [30, 60]},
	{"kind": "perfect", "text": "حقق %d ضربة مضبوطة في الأنماط", "t": [8, 18], "as_max": false, "r": [35, 70]},
	{"kind": "combo", "text": "حقق كومبو x%d في الأنماط", "t": [3, 5], "as_max": true, "r": [30, 60]},
	{"kind": "score", "text": "اوصل ارتفاع %d في نمط واحد", "t": [15, 30], "as_max": true, "r": [40, 80]},
	{"kind": "matches", "text": "العب %d مباريات", "t": [2, 4], "as_max": false, "r": [30, 60]},
	{"kind": "wins", "text": "افز في %d مباراة", "t": [1, 3], "as_max": false, "r": [40, 90]},
]

var coins := 100
var xp := 0
var owned: Array = ["classic"]
var skin := "classic"
var best: Dictionary = {}
var streak := 0
var last_claim := ""
var ch_date := ""
var ch_prog: Dictionary = {}
var ch_claimed: Array = []
var last_reward := 0

func _ready() -> void:
	_load()
	_roll_day()

func _today() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()))

func _yesterday() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)

func _roll_day() -> void:
	var d := _today()
	if ch_date != d:
		ch_date = d
		ch_prog = {}
		ch_claimed = []
		_save()

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	coins = int(cf.get_value("p", "coins", coins))
	xp = int(cf.get_value("p", "xp", 0))
	owned = Array(cf.get_value("p", "owned", ["classic"]))
	if not owned.has("classic"):
		owned.append("classic")
	skin = str(cf.get_value("p", "skin", "classic"))
	best = Dictionary(cf.get_value("p", "best", {}))
	streak = int(cf.get_value("p", "streak", 0))
	last_claim = str(cf.get_value("p", "last_claim", ""))
	ch_date = str(cf.get_value("p", "ch_date", ""))
	ch_prog = Dictionary(cf.get_value("p", "ch_prog", {}))
	ch_claimed = Array(cf.get_value("p", "ch_claimed", []))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "xp", xp)
	cf.set_value("p", "owned", owned)
	cf.set_value("p", "skin", skin)
	cf.set_value("p", "best", best)
	cf.set_value("p", "streak", streak)
	cf.set_value("p", "last_claim", last_claim)
	cf.set_value("p", "ch_date", ch_date)
	cf.set_value("p", "ch_prog", ch_prog)
	cf.set_value("p", "ch_claimed", ch_claimed)
	cf.save(SAVE_PATH)

# ---------- العملات والمستوى ----------

func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit()

func level_info() -> Dictionary:
	var lv := 1 + int(sqrt(float(xp) / 40.0))
	var base := (lv - 1) * (lv - 1) * 40
	var nxt := lv * lv * 40
	return {"level": lv, "xp": xp - base, "need": nxt - base}

# ---------- الأشكال ----------

func skin_def(id: String) -> Dictionary:
	for s in SKINS:
		if str(s.id) == id:
			return s
	return SKINS[0]

func mode_def(id: String) -> Dictionary:
	for m in MODES:
		if str(m.id) == id:
			return m
	return MODES[0]

func block_color(i: int, off: float) -> Color:
	return color_for(skin_def(skin), i, off)

func color_for(def: Dictionary, i: int, off: float) -> Color:
	var k := str(def.k)
	if k == "rainbow":
		return Color.from_hsv(fposmod(off + float(i) * float(def.step), 1.0), float(def.s), float(def.v))
	elif k == "wave":
		var w := 0.5 + 0.5 * sin(float(i) * float(def.freq) + off * TAU)
		return Color.from_hsv(lerpf(float(def.lo), float(def.hi), w), float(def.s), float(def.v))
	elif k == "lerp":
		var w2 := 0.5 + 0.5 * sin(float(i) * 0.5 + off * TAU)
		var ca: Color = def.a
		var cb: Color = def.b
		return ca.lerp(cb, w2)
	var cols: Array = def.cols
	return cols[(i + int(off * 2.0)) % cols.size()]

func buy(id: String) -> bool:
	if owned.has(id):
		return true
	var def := skin_def(id)
	var price := int(def.price)
	if coins < price:
		return false
	coins -= price
	owned.append(id)
	coins_changed.emit()
	_save()
	return true

func equip(id: String) -> void:
	if owned.has(id):
		skin = id
		_save()

# ---------- المكافآت ----------

func take_reward() -> int:
	var r := last_reward
	last_reward = 0
	return r

func reward_match(result: int, score: int, vs_bot: bool) -> int:
	var c := 8
	var gained_xp := 10
	if result > 0:
		c = 30
		gained_xp = 30
	elif result == 0:
		c = 15
		gained_xp = 15
	c += int(float(score) / 5.0)
	if vs_bot:
		c = int(float(c) / 2.0)
	add_progress("matches", 1, false)
	if result > 0:
		add_progress("wins", 1, false)
	xp += gained_xp
	add_coins(c)
	_save()
	return c

func reward_run(mode_id: String, score: int) -> int:
	var c := 0
	if score > 0:
		c = maxi(1, int(float(score) / 2.0))
	xp += score
	if score > int(best.get(mode_id, 0)):
		best[mode_id] = score
	add_progress("score", score, true)
	add_coins(c)
	last_reward = c
	_save()
	return c

# ---------- التحديات والمكافأة اليومية ----------

func add_progress(kind: String, amount: int, as_max: bool) -> void:
	_roll_day()
	var cur := int(ch_prog.get(kind, 0))
	if as_max:
		ch_prog[kind] = maxi(cur, amount)
	else:
		ch_prog[kind] = cur + amount

func progress_of(kind: String) -> int:
	return int(ch_prog.get(kind, 0))

func daily_challenges() -> Array:
	_roll_day()
	var rng := RandomNumberGenerator.new()
	rng.seed = _today().hash()
	var pool: Array = []
	for i in TEMPLATES.size():
		pool.append(i)
	var out: Array = []
	for n in 3:
		var pick := rng.randi_range(0, pool.size() - 1)
		var tpl: Dictionary = TEMPLATES[int(pool[pick])]
		pool.remove_at(pick)
		var lvl := rng.randi_range(0, 1)
		var target := int(tpl.t[lvl])
		out.append({"i": n, "kind": str(tpl.kind), "text": str(tpl.text) % target, "target": target, "reward": int(tpl.r[lvl])})
	return out

func is_claimed(i: int) -> bool:
	return ch_claimed.has(i)

func claimable_count() -> int:
	var n := 0
	for ch in daily_challenges():
		if progress_of(str(ch.kind)) >= int(ch.target) and not is_claimed(int(ch.i)):
			n += 1
	return n

func claim_challenge(i: int) -> int:
	for ch in daily_challenges():
		if int(ch.i) == i:
			if is_claimed(i) or progress_of(str(ch.kind)) < int(ch.target):
				return 0
			ch_claimed.append(i)
			add_coins(int(ch.reward))
			_save()
			return int(ch.reward)
	return 0

func daily_available() -> bool:
	return last_claim != _today()

func daily_idx() -> int:
	if last_claim == _today():
		return maxi(0, streak - 1) % 7
	if last_claim == _yesterday():
		return streak % 7
	return 0

func claim_daily() -> int:
	if not daily_available():
		return 0
	if last_claim != _yesterday():
		streak = 0
	var idx := streak % 7
	streak += 1
	last_claim = _today()
	var amount := int(DAILY[idx])
	add_coins(amount)
	_save()
	return amount
