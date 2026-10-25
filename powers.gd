extends RefCounted

const SAVE_PATH := "user://powers.cfg"
const PACK := 5
const MAX_LOADOUT := 3
const STARTER := ["slow", "fast", "grow"]
const STARTER_COUNT := 10

const LIST: Array = [
	{"id": "slow", "name": "تباطؤ", "kind": "self", "price": 80, "color": Color(0.2, 0.7, 1.0),
		"desc": "كتلتك تتحرك أبطأ بكثير لمدة 5 ثوانٍ",
		"how": "اضغط الزر فتتباطأ كتلتك إلى أقل من النصف لمدة 5 ثوانٍ، فيسهل عليك ضبطها فوق البرج بدقة.",
		"pop": "كتلتك أبطأ! (5ث)"},
	{"id": "grow", "name": "توسيع", "kind": "self", "price": 80, "color": Color(0.25, 0.8, 0.4),
		"desc": "كتلتك الحالية تصير أعرض بكثير",
		"how": "اضغط الزر قبل ما تنزّل الكتلة، فتتّسع كتلتك الحالية وتغطي البرج بسهولة ولا تخسر من عرضك.",
		"pop": "كتلة أعرض!"},
	{"id": "magnet", "name": "مغناطيس", "kind": "self", "price": 150, "color": Color(0.65, 0.4, 1.0),
		"desc": "الإنزال القادم يكون مضبوطاً تماماً",
		"how": "اضغط الزر، وعند لمستك القادمة تنجذب كتلتك لمنتصف البرج وتنزل مضبوطة بالكامل.",
		"pop": "مضبوط تلقائياً!"},
	{"id": "shield", "name": "درع", "kind": "self", "price": 120, "color": Color(0.35, 0.5, 0.95),
		"desc": "يصدّ أول هجوم أو قدرة من الخصم",
		"how": "اضغط الزر لتفعيل درع يمتص أول هجوم أو قدرة يرسلها خصمك، ثم يختفي.",
		"pop": "صددت الهجوم!"},
	{"id": "fast", "name": "تسريع الخصم", "kind": "enemy", "price": 90, "color": Color(1.0, 0.4, 0.2),
		"desc": "كتلة خصمك تتسارع لمدة 5 ثوانٍ",
		"how": "اضغط الزر فتتسارع كتلة خصمك لمدة 5 ثوانٍ فيصعب عليه التوقيت.",
		"pop": "كتلته أسرع! (5ث)"},
	{"id": "narrow", "name": "تضييق", "kind": "enemy", "price": 100, "color": Color(0.95, 0.35, 0.65),
		"desc": "كتلة خصمك الحالية تضيق فوراً",
		"how": "اضغط الزر فتضيق كتلة خصمك الحالية في الحال، فيصعب عليه إبقاء برجه عريضاً.",
		"pop": "كتلته أضيق!"},
	{"id": "fog", "name": "ضباب", "kind": "enemy", "price": 130, "color": Color(0.5, 0.6, 0.85),
		"desc": "يغطي برج خصمك بضباب 4 ثوانٍ",
		"how": "اضغط الزر فيتغطى برج خصمك بضباب لمدة 4 ثوانٍ، فلا يرى مكان كتلته بوضوح.",
		"pop": "الرؤية ضبابية! (4ث)"},
	{"id": "jitter", "name": "ارتباك", "kind": "enemy", "price": 110, "color": Color(1.0, 0.8, 0.2),
		"desc": "سرعة كتلة خصمك تتذبذب 5 ثوانٍ",
		"how": "اضغط الزر فتتحرك كتلة خصمك بسرعات متغيرة ومفاجئة لمدة 5 ثوانٍ فيفشل في توقيتها.",
		"pop": "حركة مرتبكة! (5ث)"},
]

static var counts: Dictionary = {}
static var loadout: Array = []
static var _loaded := false

static func _data() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Data")

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		counts = Dictionary(cf.get_value("p", "counts", {}))
		loadout = Array(cf.get_value("p", "loadout", []))
		if bool(cf.get_value("p", "started", false)):
			return
	for sid in STARTER:
		counts[sid] = int(counts.get(sid, 0)) + STARTER_COUNT
	loadout = STARTER.duplicate()
	_save()

static func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "counts", counts)
	cf.set_value("p", "loadout", loadout)
	cf.set_value("p", "started", true)
	cf.save(SAVE_PATH)

static func def(id: String) -> Dictionary:
	for item in LIST:
		if str(item["id"]) == id:
			return item
	return {}

static func count(id: String) -> int:
	_ensure()
	return int(counts.get(id, 0))

static func use(id: String) -> bool:
	_ensure()
	var c := count(id)
	if c <= 0:
		return false
	counts[id] = c - 1
	_save()
	return true

static func buy(id: String) -> bool:
	_ensure()
	var item := def(id)
	if item.is_empty():
		return false
	var dt := _data()
	if dt == null:
		return false
	var price := int(item["price"])
	if int(dt.coins) < price:
		return false
	dt.add_coins(-price)
	dt._save()
	counts[id] = count(id) + PACK
	_save()
	return true

static func get_loadout() -> Array:
	_ensure()
	var out: Array = []
	for lid in loadout:
		if not def(str(lid)).is_empty() and not out.has(str(lid)):
			out.append(str(lid))
	return out.slice(0, MAX_LOADOUT)

static func toggle(id: String) -> String:
	_ensure()
	var cur := get_loadout()
	if cur.has(id):
		cur.erase(id)
		loadout = cur
		_save()
		return "removed"
	if cur.size() >= MAX_LOADOUT:
		return "full"
	cur.append(id)
	loadout = cur
	_save()
	return "added"
