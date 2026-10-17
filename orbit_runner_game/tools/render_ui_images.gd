extends Node
## Renders the UI images from the in-game protagonist with the toon shading:
## art/ui/icon.png (512, sky background), art/ui/portrait.png (256, transparent)
## and art/ui/icon_foreground.png (432, transparent, adaptive-icon safe zone).
##   godot --path . res://tools/render_ui_images.tscn
## (needs a window: rendering does not run with --headless). Overwrites the files.

const CHARACTER := preload("res://art/models/CHR_Adventurer.glb")
const BIOME: BiomeTheme = preload("res://resources/biomes/isles.tres")


func _ready() -> void:
	LevelEnvironment.apply_toon_globals(BIOME)
	await _shoot("res://art/ui/icon.png", 512, Vector3(0.7, 1.55, -2.0), Vector3(0, 1.17, 0), 38.0, false)
	await _shoot("res://art/ui/portrait.png", 256, Vector3(0.25, 1.34, -1.3), Vector3(0, 1.29, 0), 36.0, true)
	await _shoot("res://art/ui/icon_foreground.png", 432, Vector3(0.95, 1.5, -2.9), Vector3(0, 1.02, 0), 34.0, true)
	print("render_ui_images: done")
	get_tree().quit()


func _shoot(path: String, size: int, eye: Vector3, target: Vector3, fov: float, transparent: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size, size)
	viewport.transparent_bg = transparent
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR
	env.background_color = Color(0.2, 0.55, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = BIOME.ambient_color
	env.ambient_light_energy = BIOME.ambient_energy + 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = BIOME.sun_color
	sun.light_energy = BIOME.sun_energy
	sun.rotation_degrees = Vector3(-35, 160, 0)
	viewport.add_child(sun)
	var character := CHARACTER.instantiate() as Node3D
	viewport.add_child(character)
	var anim := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Victory"):
		anim.play("Victory")
		anim.seek(0.27, true)
		anim.pause()
	var camera := Camera3D.new()
	camera.fov = fov
	viewport.add_child(camera)
	camera.look_at_from_position(eye, target)
	camera.current = true
	for i in 8:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	viewport.queue_free()
