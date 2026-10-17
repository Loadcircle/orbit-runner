extends Node
func _ready() -> void:
	var lvl: Node = (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	var r: Array = lvl.get_meta("route")
	for i in r.size():
		var p: Dictionary = r[i]
		print("%2d %-7s pos=(%.1f,%.1f,%.1f) yaw=%d len=%.1f gap=%.1f rise=%.1f" % [i, p["kind"], p["pos"].x, p["pos"].y, p["pos"].z, int(p["yaw"]), p["len"], p["gap"], p["rise"]])
	lvl.free()
	get_tree().quit()
