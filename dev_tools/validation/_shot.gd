extends Node
## Temporary visual-check harness (not shipped).
## Args after "--": <scene path> <output dir> <mode: tour|run|ui> [count]

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	var scene_path := _args[0]
	var out_dir := _args[1]
	var mode := _args[2] if _args.size() > 2 else "tour"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene := (load(scene_path) as PackedScene).instantiate()
	add_child(scene)
	await _frames(30)
	if mode == "tour":
		await _tour(scene as Level, out_dir, int(_args[3]) if _args.size() > 3 else 6)
	elif mode == "run":
		await _run(scene as Level, out_dir)
	else:
		await _frames(60)
		_save(out_dir + "/ui.png")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)


var _sheet: Array[Image] = []


func _grab() -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(640, 360)
	_sheet.append(img)


func _write_sheet(path: String) -> void:
	var cols := 3
	var rows := ceili(_sheet.size() / float(cols))
	var out := Image.create(640 * cols, 360 * rows, false, _sheet[0].get_format())
	for k in _sheet.size():
		out.blit_rect(_sheet[k], Rect2i(0, 0, 640, 360), Vector2i((k % cols) * 640, (k / cols) * 360))
	out.save_png(path)
	print("SHEET ", path)


func _tour(level: Level, out_dir: String, count: int) -> void:
	var platforms := level.get_node("Geometry").get_children()
	var step := maxi(1, platforms.size() / count)
	var i := 0
	var shot := 0
	while i < platforms.size() and shot < count:
		var p := platforms[i] as Node3D
		var xf := Transform3D(Basis(Vector3.UP, p.rotation.y), p.global_position + Vector3.UP * 0.2)
		level.player.respawn_at(xf)
		level.camera_rig.snap(p.rotation.y)
		await _frames(45)
		_grab()
		shot += 1
		i += step
	# Final shot at the goal
	var goal := level.find_child("Goal", true, false) as Node3D
	if goal:
		level.player.respawn_at(Transform3D(Basis(Vector3.UP, goal.rotation.y), goal.global_position + goal.global_basis.z * 6.0))
		level.camera_rig.snap(goal.rotation.y)
		await _frames(45)
		_grab()
	_write_sheet("%s/sheet.png" % out_dir)


func _run(level: Level, out_dir: String) -> void:
	# Hold forward; jump periodically; capture a few frames and log positions.
	Input.action_press("move_forward")
	for k in 8:
		await _frames(20)
		if k == 2:
			Input.action_press("jump")
		if k == 3:
			Input.action_release("jump")
		if k == 5:
			Input.action_press("yoyo")
		if k == 6:
			Input.action_release("yoyo")
		print("POS ", k, " ", level.player.global_position, " vel ", level.player.velocity, " floor ", level.player.is_on_floor())
		_save("%s/run_%02d.png" % [out_dir, k])
	Input.action_release("move_forward")
