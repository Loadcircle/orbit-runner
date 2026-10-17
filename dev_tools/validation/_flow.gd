extends Node
## Temporary flow-check harness (not shipped). Drives the real screens and
## captures screenshots. Wipes the test save at the end.

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# The driver lives under the root so it survives scene changes.
	get_tree().root.add_child.call_deferred(_make_driver())


func _make_driver() -> Node:
	var d := Driver.new()
	d.out_dir = out_dir
	return d


class Driver extends Node:
	var out_dir := ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func _wait(seconds: float) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func _shot(name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
		print("SHOT ", name)

	func _run() -> void:
		SaveService.wipe()
		SceneRouter.go_to(SceneRouter.TITLE)
		await _wait(1.6)
		await _shot("01_title")
		SceneRouter.go_to(SceneRouter.MAIN_MENU)
		await _wait(1.2)
		await _shot("02_menu")
		get_tree().current_scene.call("_open_settings")
		await _wait(0.6)
		await _shot("03_settings")
		SceneRouter.go_to(SceneRouter.LEVEL_SELECT)
		await _wait(1.2)
		await _shot("04_levels")
		SceneRouter.go_to("res://scenes/ui/wardrobe_screen.tscn")
		await _wait(1.2)
		await _shot("05_wardrobe")
		SceneRouter.go_to("res://scenes/ui/achievements_screen.tscn")
		await _wait(1.2)
		await _shot("06_achievements")
		SceneRouter.go_to("res://scenes/ui/credits_screen.tscn")
		await _wait(1.5)
		await _shot("07_credits")
		SceneRouter.play_level(1)
		await _wait(2.0)
		await _shot("08_level")
		var level := get_tree().current_scene as Level
		level.pause()
		await _wait(0.5)
		await _shot("09_pause")
		level.resume()
		await _wait(0.3)
		var goal := level.find_child("Goal", true, false) as Node3D
		level.elapsed = 21.0
		level.on_gem(0)
		level.player.global_position = goal.global_position + Vector3.UP * 0.3
		await _wait(3.0)
		await _shot("10_results")
		print("RECORD ", Progress.record(&"w1_l1"))
		print("SPARKS ", Progress.sparks(), " ACH ", Progress.achievements_unlocked_count())
		print("UNLOCKED2 ", Progress.is_unlocked(2))
		SaveService.save_now()
		print("SAVE_EXISTS ", FileAccess.file_exists(SaveService.SAVE_PATH))
		SceneRouter.go_to(SceneRouter.LEVEL_SELECT, {"world": 0})
		await _wait(1.2)
		await _shot("11_levels_after")
		SaveService.wipe()
		SaveService.set("_dirty", false)
		get_tree().quit()
