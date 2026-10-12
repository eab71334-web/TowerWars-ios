extends SceneTree

func _initialize() -> void:
	var bad := 0
	for f in DirAccess.get_files_at("res://"):
		if not f.ends_with(".gd") or f == "check.gd":
			continue
		var s = load("res://" + f)
		if s == null or not s.can_instantiate():
			print("BAD: ", f)
			bad += 1
		else:
			print("ok: ", f)
	print("done, bad=", bad)
	quit()
