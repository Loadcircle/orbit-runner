class_name LevelEnvironment
extends RefCounted
## Builds the sky, sun, fog, cloud sea and distant scenery for a level from
## its BiomeTheme, scaled to the current quality setting.

const CLOUD := preload("res://art/models/ENV_Cloud.glb")
const DISTANT := {
	&"isles": ["res://art/models/PLAT_Isle_L.glb", "res://art/models/ENV_Tree.glb", "res://art/models/ENV_Pine.glb"],
	&"toyworks": ["res://art/models/PLAT_Toy_L.glb", "res://art/models/ENV_Gear.glb", "res://art/models/ENV_ToyBlocks.glb"],
	&"ruins": ["res://art/models/PLAT_Ruin_L.glb", "res://art/models/ENV_Obelisk.glb", "res://art/models/ENV_Palm.glb"],
}


static func build(level: Node3D, biome: BiomeTheme, kill_height: float) -> void:
	if biome == null:
		biome = BiomeTheme.new()
	var quality := Settings.quality()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = biome.sky_top
	sky_mat.sky_horizon_color = biome.sky_horizon
	sky_mat.ground_horizon_color = biome.sky_horizon
	sky_mat.ground_bottom_color = biome.ground_bottom
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = biome.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = biome.fog_color
	env.fog_density = biome.fog_density
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.15
	env.glow_enabled = quality == Settings.Quality.HIGH
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.06
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	level.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = biome.sun_color
	sun.light_energy = biome.sun_energy
	sun.rotation_degrees = biome.sun_rotation_degrees
	sun.shadow_enabled = quality != Settings.Quality.LOW
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0 if quality == Settings.Quality.HIGH else 30.0
	sun.shadow_opacity = 0.75
	sun.shadow_blur = 1.5
	level.add_child(sun)

	var bounds := _level_bounds(level)
	_cloud_sea(level, biome, kill_height, bounds, quality)
	if quality != Settings.Quality.LOW:
		_distant_scenery(level, biome, bounds)


static func _level_bounds(level: Node3D) -> AABB:
	var box := AABB(level.global_position, Vector3.ONE)
	var geometry := level.get_node_or_null("Geometry")
	if geometry == null:
		return box
	for child in geometry.get_children():
		if child is Node3D:
			box = box.expand((child as Node3D).global_position)
	return box


static func _cloud_sea(level: Node3D, biome: BiomeTheme, kill_height: float, bounds: AABB, quality: int) -> void:
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = biome.cloud_color.lerp(biome.sky_horizon, 0.35)
	mat.disable_receive_shadows = true
	plane.material = mat
	sea.mesh = plane
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(bounds.get_center().x, kill_height - 10.0, bounds.get_center().z)
	level.add_child(sea)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.scene_file_path)
	var count := 26 if quality == Settings.Quality.HIGH else 14
	for i in count:
		var cloud := CLOUD.instantiate() as Node3D
		var center := bounds.get_center()
		var radius := maxf(bounds.size.length() * 0.6, 40.0)
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(0.35, 1.0) * radius
		cloud.position = Vector3(center.x + cos(angle) * dist, kill_height - rng.randf_range(2.0, 8.0),
				center.z + sin(angle) * dist)
		cloud.scale = Vector3.ONE * rng.randf_range(1.5, 3.5)
		cloud.rotation.y = rng.randf() * TAU
		_no_shadows(cloud)
		level.add_child(cloud)


static func _distant_scenery(level: Node3D, biome: BiomeTheme, bounds: AABB) -> void:
	var paths: Array = DISTANT.get(biome.id, DISTANT[&"isles"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.scene_file_path) + 7
	var scenes: Array[PackedScene] = []
	for path in paths:
		scenes.append(load(path))
	var center := bounds.get_center()
	var reach := maxf(maxf(bounds.size.x, bounds.size.z) * 0.5, 30.0)
	for i in 10:
		var island := scenes[0].instantiate() as Node3D
		var angle := rng.randf() * TAU
		var dist := reach + rng.randf_range(35.0, 90.0)
		island.position = Vector3(center.x + cos(angle) * dist, center.y + rng.randf_range(-15.0, 12.0),
				center.z + sin(angle) * dist)
		var s := rng.randf_range(1.2, 2.4)
		island.scale = Vector3(s, s, s)
		island.rotation.y = rng.randf() * TAU
		_no_shadows(island)
		level.add_child(island)
		for j in rng.randi_range(1, 3):
			var prop := scenes[1 + rng.randi() % (scenes.size() - 1)].instantiate() as Node3D
			island.add_child(prop)
			prop.position = Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-3.5, 3.5))
			prop.rotation.y = rng.randf() * TAU
			_no_shadows(prop)


static func _no_shadows(node: Node) -> void:
	for mesh in node.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
