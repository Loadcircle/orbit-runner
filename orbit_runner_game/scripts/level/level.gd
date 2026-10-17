class_name Level
extends Node3D
## Runs one level: spawns the player, camera and UI, tracks time, gems,
## sparks and checkpoints, handles respawns, pause and the finish.

signal gems_changed(collected: Array[bool])
signal sparks_changed(collected: int, total: int)

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CAMERA_SCENE := preload("res://scenes/player/follow_camera.tscn")
const YOYO_SCENE := preload("res://scenes/player/kinetic_yoyo.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const RESULTS_SCENE := preload("res://scenes/ui/results_screen.tscn")
const RESPAWN_DELAY := 0.55

static var current: Level

@export var biome: BiomeTheme
@export var start_yaw_degrees := 0.0
## Falling below this height respawns the player.
@export var kill_height := -12.0

var info: LevelInfo
var player: Player
var camera_rig: FollowCamera
var hud: Hud
var elapsed := 0.0
var timer_running := false
var finished := false
var respawns := 0
var gems: Array[bool] = [false, false, false]
var sparks := 0
var sparks_total := 0

var _respawn_xform: Transform3D
var _respawn_yaw := 0.0
var _pause_menu: PauseMenu
var _results: ResultsScreen
var _prompt_owner: TutorialPrompt
var _start_pos := Vector3.ZERO
var _goal_pos := Vector3.ZERO
## Route polyline (piece centres) and cumulative lengths for progress.
var _route_points: PackedVector3Array = []
var _route_cumulative: PackedFloat32Array = []


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	info = _resolve_info()
	if biome == null and info:
		biome = info.biome
	LevelEnvironment.build(self, biome, kill_height)
	_fade_decor_near_camera()
	sparks_total = find_children("*", "Spark", true, false).size()
	var start := $PlayerStart as Marker3D
	_start_pos = start.global_position
	var goal := find_child("Goal", true, false) as Node3D
	_goal_pos = goal.global_position if goal else _start_pos + Vector3.FORWARD * 100.0
	_respawn_xform = start.global_transform
	_build_route()
	_respawn_yaw = deg_to_rad(start_yaw_degrees)

	player = PLAYER_SCENE.instantiate()
	add_child(player)
	var yoyo := YOYO_SCENE.instantiate() as KineticYoyo
	add_child(yoyo)
	yoyo.owner_player = player
	player.yoyo = yoyo
	camera_rig = CAMERA_SCENE.instantiate()
	add_child(camera_rig)
	camera_rig.target = player
	player.camera_rig = camera_rig
	player.died.connect(_on_player_died)
	player.respawn_at(_respawn_xform)
	camera_rig.snap(_respawn_yaw)
	_apply_cosmetics()
	Progress.equipment_changed.connect(_apply_cosmetics)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(self)
	_pause_menu = PAUSE_SCENE.instantiate()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(resume)
	_pause_menu.restart_requested.connect(restart)
	_pause_menu.quit_requested.connect(quit_to_menu)
	_results = RESULTS_SCENE.instantiate()
	add_child(_results)

	AudioDirector.play_music(biome.music_id if biome else &"isles")
	# Compile all shaders now, while the scene-change fade hides the screen.
	ShaderWarmup.run.call_deferred(self, camera_rig.camera)


func _physics_process(delta: float) -> void:
	if finished:
		return
	if not timer_running and _player_started():
		timer_running = true
	if timer_running:
		elapsed += delta
	if player.global_position.y < kill_height and not player.is_dead:
		player.hurt()


func _player_started() -> bool:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.2 \
		or Input.is_action_pressed("jump") or Input.is_action_pressed("yoyo") or Input.is_action_pressed("action")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if not finished:
			toggle_pause()


func handle_back() -> void:
	if finished:
		_results.handle_back()
	elif get_tree().paused:
		_pause_menu.handle_back()
	else:
		pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and not finished and not get_tree().paused:
			pause()


# ------------------------------------------------------------------ flow

func toggle_pause() -> void:
	if get_tree().paused:
		resume()
	else:
		pause()


func pause() -> void:
	if finished:
		return
	get_tree().paused = true
	_pause_menu.open()
	AudioDirector.play_sfx(&"ui_back", -4.0)


func resume() -> void:
	_pause_menu.close()
	get_tree().paused = false


func restart() -> void:
	get_tree().paused = false
	SceneRouter.play_level(SceneRouter.current_level_index)


func quit_to_menu() -> void:
	get_tree().paused = false
	SceneRouter.go_to(SceneRouter.LEVEL_SELECT, {"world": info.world_index if info else 0})


func finish() -> void:
	if finished:
		return
	finished = true
	timer_running = false
	player.input_enabled = false
	player.visual.celebrating = true
	hud.on_finished()
	AudioDirector.play_sfx(&"goal")
	AudioDirector.play_music(&"victory", true)
	Settings.vibrate(60)
	var summary := {}
	if info:
		summary = Progress.submit_run(info, {"time": elapsed, "gems": gems, "sparks": sparks,
				"sparks_total": sparks_total, "respawns": respawns})
	await get_tree().create_timer(1.4).timeout
	_results.open(self, summary)


# ------------------------------------------------------------------ events from level elements

func on_checkpoint(checkpoint: Checkpoint) -> void:
	_respawn_xform = checkpoint.spawn_transform()
	_respawn_yaw = camera_rig.target_yaw
	hud.flash_message(tr("HUD_CHECKPOINT"))


func on_gem(index: int) -> void:
	gems[index] = true
	gems_changed.emit(gems)


func on_spark() -> void:
	sparks += 1
	sparks_changed.emit(sparks, sparks_total)


func gem_already_owned(index: int) -> bool:
	if info == null:
		return false
	var owned: Array = Progress.record(info.id)["gems"]
	return index < owned.size() and bool(owned[index])


func set_camera_yaw(yaw: float) -> void:
	camera_rig.target_yaw = yaw


func show_prompt(prompt: TutorialPrompt) -> void:
	_prompt_owner = prompt
	var key := prompt.text_key
	if hud.is_touch_mode() and tr(key + "_TOUCH") != key + "_TOUCH":
		key += "_TOUCH"
	hud.show_prompt(tr(key))


func hide_prompt(prompt: TutorialPrompt) -> void:
	if _prompt_owner == prompt:
		_prompt_owner = null
		hud.hide_prompt()


## 0..1 progress along the route polyline (start -> pieces -> goal).
func route_progress() -> float:
	if _route_points.size() < 2:
		return 0.0
	var p := player.global_position
	var best_dist := INF
	var best := 0.0
	for i in _route_points.size() - 1:
		var a := _route_points[i]
		var b := _route_points[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_squared_to(a + ab * t)
		if d < best_dist:
			best_dist = d
			best = _route_cumulative[i] + ab.length() * t
	return clampf(best / _route_cumulative[_route_cumulative.size() - 1], 0.0, 1.0)


func _build_route() -> void:
	_route_points = PackedVector3Array([_start_pos])
	if has_meta("route"):
		for piece in get_meta("route"):
			_route_points.append(to_global(piece["pos"]))
	_route_points.append(_goal_pos)
	_route_cumulative = PackedFloat32Array([0.0])
	for i in range(1, _route_points.size()):
		_route_cumulative.append(_route_cumulative[i - 1] + _route_points[i - 1].distance_to(_route_points[i]))


func _on_player_died() -> void:
	respawns += 1
	camera_rig.shake(0.6)
	AudioDirector.play_sfx(&"fail")
	Settings.vibrate(80)
	hud.fade_flash()
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if finished:
		return
	player.respawn_at(_respawn_xform)
	camera_rig.snap(_respawn_yaw)


func _apply_cosmetics() -> void:
	var outfit := Progress.equipped(CosmeticInfo.Kind.OUTFIT)
	var yoyo_item := Progress.equipped(CosmeticInfo.Kind.YOYO)
	player.visual.apply_cosmetics(outfit, yoyo_item)
	player.yoyo.apply_cosmetic(yoyo_item)


## Decoration dithers out when the camera gets close so it never hides the
## protagonist or the route (dither keeps it opaque-cheap on mobile GPUs).
func _fade_decor_near_camera() -> void:
	var decor := get_node_or_null("Decor")
	if decor == null:
		return
	var faded := {}
	for node in decor.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var base := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			if not faded.has(base):
				var mat := base.duplicate() as StandardMaterial3D
				mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				mat.distance_fade_min_distance = 3.0
				mat.distance_fade_max_distance = 7.5
				faded[base] = mat
			mesh_instance.set_surface_override_material(i, faded[base])


func _resolve_info() -> LevelInfo:
	var levels := Progress.levels()
	var index := SceneRouter.current_level_index
	if index >= 0 and index < levels.size() and levels[index].scene_path == scene_file_path:
		return levels[index]
	# Started directly from the editor: look the scene up in the catalog.
	for i in levels.size():
		if levels[i].scene_path == scene_file_path:
			SceneRouter.current_level_index = i
			return levels[i]
	return null
