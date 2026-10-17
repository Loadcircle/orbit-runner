extends Node
## Temporary validation helper: loads every script and scene to surface errors.

func _ready() -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	_collect("res://scenes", files)
	for f in files:
		var res := load(f)
		if res == null:
			print("FAILED: ", f)
		elif res is GDScript and not (res as GDScript).can_instantiate():
			print("CANNOT INSTANTIATE: ", f)
	print("CHECK DONE ", files.size())
	get_tree().quit()


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	for d in dir.get_directories():
		_collect(dir_path + "/" + d, out)
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir_path + "/" + f)
