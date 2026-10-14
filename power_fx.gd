extends RefCounted

const DUR := {"slow": 5.0, "fast": 5.0, "jitter": 5.0, "fog": 4.0}

var timers := {"slow": 0.0, "fast": 0.0, "jitter": 0.0, "fog": 0.0}
var magnet := false
var shield := false
var clock := 0.0

func tick(delta: float) -> void:
	clock += delta
	for k in timers.keys():
		timers[k] = maxf(0.0, float(timers[k]) - delta)

func start(id: String) -> void:
	if DUR.has(id):
		timers[id] = float(DUR[id])
	elif id == "magnet":
		magnet = true
	elif id == "shield":
		shield = true

func active(id: String) -> bool:
	if timers.has(id):
		return float(timers[id]) > 0.0
	if id == "magnet":
		return magnet
	if id == "shield":
		return shield
	return false

func frac(id: String) -> float:
	if timers.has(id):
		return clampf(float(timers[id]) / float(DUR[id]), 0.0, 1.0)
	if active(id):
		return 1.0
	return 0.0

func speed_mult() -> float:
	var m := 1.0
	if float(timers["slow"]) > 0.0:
		m *= 0.45
	if float(timers["fast"]) > 0.0:
		m *= 1.9
	if float(timers["jitter"]) > 0.0:
		m *= clampf(1.0 + 0.75 * sin(clock * 11.0), 0.25, 2.0)
	return m
