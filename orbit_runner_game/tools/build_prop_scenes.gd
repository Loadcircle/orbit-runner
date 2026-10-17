extends Node
## Generates the reusable gameplay prop scenes (scenes/props/) from the GLB
## models: collision shapes, trigger areas and behaviour scripts.
##   godot --headless --path . res://tools/build_prop_scenes.tscn
## Re-running overwrites the generated scenes.

const MODELS := "res://art/models/%s.glb"
const OUT := "res://scenes/props/%s.tscn"
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_TRIGGER := 4
const LAYER_HAZARD := 8

const PLATFORM_SIZES := {
	"S": Vector2(3, 3), "M": Vector2(4, 6), "L": Vector2(6, 10), "XL": Vector2(8, 14), "Strip": Vector2(2.5, 8),
	"Wide": Vector2(6, 6),
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/props/platforms"))
	for biome in ["Isle", "Toy", "Ruin"]:
		for size_key in PLATFORM_SIZES:
			_platform(biome, size_key)
	_moving_platform()
	_crumble_platform()
	_timed_platform()
	_trampoline()
	_wind_column()
	_boost_pad()
	_spikes()
	_spinner()
	_patrol_bot()
	_laser_gate()
	_checkpoint()
	_gem()
	_spark()
	_goal()
	print("build_prop_scenes: done")
	get_tree().quit()


# ------------------------------------------------------------------ helpers

func _model(name: String, parent: Node, node_name := "Model") -> Node3D:
	var scene: PackedScene = load(MODELS % name)
	var inst := scene.instantiate() as Node3D
	inst.name = node_name
	parent.add_child(inst)
	return inst


func _box_shape(parent: Node, size: Vector3, offset: Vector3, node_name := "CollisionShape3D") -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = node_name
	cs.shape = shape
	cs.position = offset
	parent.add_child(cs)
	return cs


func _cylinder_shape(parent: Node, radius: float, height: float, offset: Vector3) -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position = offset
	parent.add_child(cs)
	return cs


func _sphere_shape(parent: Node, radius: float, offset: Vector3) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position = offset
	parent.add_child(cs)
	return cs


func _area(parent: Node, node_name: String, layer: int, script_path := "") -> Area3D:
	var a := Area3D.new()
	a.name = node_name
	a.collision_layer = layer
	a.collision_mask = LAYER_PLAYER
	a.monitorable = false
	if script_path != "":
		a.set_script(load(script_path))
	parent.add_child(a)
	return a


func _burst(parent: Node, color: Color, node_name := "Burst") -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.emitting = false
	p.one_shot = true
	p.amount = 20
	p.lifetime = 0.6
	p.explosiveness = 0.9
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)
	return p


func _save(root: Node, file_name: String) -> void:
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT % file_name)
	print("%s -> %s" % [file_name, error_string(err)])
	root.free()


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		# Do not descend into instanced scenes (their internals stay in the GLB).
		if child.scene_file_path == "":
			_set_owner(child, owner_node)


# ------------------------------------------------------------------ props

func _platform(biome: String, size_key: String) -> void:
	var size: Vector2 = PLATFORM_SIZES[size_key]
	var body := StaticBody3D.new()
	body.name = "Platform%s%s" % [biome, size_key]
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	_model("PLAT_%s_%s" % [biome, size_key], body)
	_box_shape(body, Vector3(size.x, 1.0, size.y), Vector3(0, -0.5, 0))
	_save(body, "platforms/%s_%s" % [biome.to_lower(), size_key.to_lower()])


func _moving_platform() -> void:
	var body := AnimatableBody3D.new()
	body.name = "MovingPlatform"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.set_script(load("res://scripts/props/moving_platform.gd"))
	_model("PLAT_Moving", body)
	_box_shape(body, Vector3(3.0, 0.5, 3.0), Vector3(0, -0.25, 0))
	_save(body, "moving_platform")


func _crumble_platform() -> void:
	var body := StaticBody3D.new()
	body.name = "CrumblePlatform"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.set_script(load("res://scripts/props/crumble_platform.gd"))
	_model("PLAT_Crumble", body)
	_box_shape(body, Vector3(3.0, 0.4, 3.0), Vector3(0, -0.2, 0))
	var sensor := _area(body, "Sensor", LAYER_TRIGGER)
	_box_shape(sensor, Vector3(2.8, 0.5, 2.8), Vector3(0, 0.25, 0))
	_save(body, "crumble_platform")


func _timed_platform() -> void:
	var body := StaticBody3D.new()
	body.name = "TimedPlatform"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.set_script(load("res://scripts/props/timed_platform.gd"))
	_model("PLAT_Timed", body)
	_cylinder_shape(body, 1.55, 0.6, Vector3(0, -0.3, 0))
	_save(body, "timed_platform")


func _trampoline() -> void:
	var root := Node3D.new()
	root.name = "Trampoline"
	root.set_script(load("res://scripts/props/trampoline.gd"))
	_model("PROP_Trampoline", root)
	var base := StaticBody3D.new()
	base.name = "Base"
	base.collision_layer = LAYER_WORLD
	base.collision_mask = 0
	root.add_child(base)
	_cylinder_shape(base, 1.15, 0.36, Vector3(0, 0.18, 0))
	# Wider than the base so running into the side also launches the player.
	var pad := _area(root, "PadArea", LAYER_TRIGGER)
	_cylinder_shape(pad, 1.35, 1.0, Vector3(0, 0.5, 0))
	_save(root, "trampoline")


func _wind_column() -> void:
	var root := Node3D.new()
	root.name = "WindColumn"
	root.set_script(load("res://scripts/props/wind_column.gd"))
	_model("PROP_WindRing", root)
	var area := _area(root, "Area", LAYER_TRIGGER)
	_cylinder_shape(area, 1.65, 8.0, Vector3(0, 4.0, 0))
	var column := MeshInstance3D.new()
	column.name = "Column"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.45
	mesh.bottom_radius = 1.45
	mesh.height = 8.0
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://resources/shaders/wind_column.gdshader")
	mesh.material = mat
	column.mesh = mesh
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position.y = 4.0
	root.add_child(column)
	_save(root, "wind_column")


func _boost_pad() -> void:
	var area := Area3D.new()
	area.name = "BoostPad"
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.set_script(load("res://scripts/props/boost_pad.gd"))
	_model("PROP_BoostPad", area)
	_box_shape(area, Vector3(2.2, 0.8, 3.2), Vector3(0, 0.4, 0))
	_save(area, "boost_pad")


func _spikes() -> void:
	var root := Node3D.new()
	root.name = "Spikes"
	_model("HAZ_Spikes", root)
	var hazard := _area(root, "Hazard", LAYER_HAZARD, "res://scripts/props/hazard_area.gd")
	_box_shape(hazard, Vector3(1.8, 0.5, 1.8), Vector3(0, 0.3, 0))
	_save(root, "spikes")


func _spinner() -> void:
	var root := Node3D.new()
	root.name = "Spinner"
	root.set_script(load("res://scripts/props/spinner.gd"))
	_model("HAZ_Spinner", root)
	var hub := StaticBody3D.new()
	hub.name = "Hub"
	hub.collision_layer = LAYER_WORLD
	hub.collision_mask = 0
	root.add_child(hub)
	_cylinder_shape(hub, 0.6, 1.2, Vector3(0, 0.6, 0))
	var arm := Node3D.new()
	arm.name = "Arm"
	root.add_child(arm)
	var hazard := _area(arm, "Hazard", LAYER_HAZARD, "res://scripts/props/hazard_area.gd")
	_box_shape(hazard, Vector3(6.6, 0.5, 0.5), Vector3(0, 0.7, 0))
	_save(root, "spinner")


func _patrol_bot() -> void:
	var root := Node3D.new()
	root.name = "PatrolBot"
	root.set_script(load("res://scripts/props/patrol_hazard.gd"))
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.9, 0)
	root.add_child(body)
	_model("HAZ_PatrolBot", body)
	var hazard := _area(body, "Hazard", LAYER_HAZARD, "res://scripts/props/hazard_area.gd")
	_sphere_shape(hazard, 0.75, Vector3.ZERO)
	_save(root, "patrol_bot")


func _laser_gate() -> void:
	var root := Node3D.new()
	root.name = "LaserGate"
	root.set_script(load("res://scripts/props/laser_gate.gd"))
	var left := _model("HAZ_LaserPost", root, "LeftPost")
	left.position.x = -2.0
	left.rotation_degrees.y = -90
	var right := _model("HAZ_LaserPost", root, "RightPost")
	right.position.x = 2.0
	right.rotation_degrees.y = 90
	for post in [left, right]:
		var body := StaticBody3D.new()
		body.name = "Collider"
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		post.add_child(body)
		_box_shape(body, Vector3(0.4, 2.2, 0.4), Vector3(0, 1.1, 0))
	var beam := Node3D.new()
	beam.name = "Beam"
	beam.position.y = 1.05
	root.add_child(beam)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.7, 0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.3, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.7)
	mesh.material = mat
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(mesh_instance)
	var hazard := _area(beam, "Hazard", LAYER_HAZARD, "res://scripts/props/hazard_area.gd")
	_box_shape(hazard, Vector3(3.7, 0.32, 0.4), Vector3.ZERO)
	_save(root, "laser_gate")


func _checkpoint() -> void:
	var area := Area3D.new()
	area.name = "Checkpoint"
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.set_script(load("res://scripts/props/checkpoint.gd"))
	var model := _model("PROP_Checkpoint", area)
	model.position = Vector3(-1.4, 0, 0)
	_box_shape(area, Vector3(4.0, 3.0, 2.0), Vector3(0, 1.5, 0))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 0.1, 0)
	area.add_child(spawn)
	var burst := _burst(area, Color(1.0, 0.75, 0.3))
	burst.position = Vector3(-1.4, 2.4, 0)
	_save(area, "checkpoint")


func _gem() -> void:
	var area := Area3D.new()
	area.name = "Gem"
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.set_script(load("res://scripts/props/gem.gd"))
	var model := _model("PROP_Gem", area)
	model.position.y = 1.0
	_sphere_shape(area, 0.9, Vector3(0, 1.0, 0))
	_save(area, "gem")


func _spark() -> void:
	var area := Area3D.new()
	area.name = "Spark"
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.set_script(load("res://scripts/props/spark.gd"))
	var model := _model("PROP_Spark", area)
	model.scale = Vector3.ONE * 1.1
	_sphere_shape(area, 0.6, Vector3.ZERO)
	_save(area, "spark")


func _goal() -> void:
	var area := Area3D.new()
	area.name = "Goal"
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.set_script(load("res://scripts/props/goal.gd"))
	_model("PROP_GoalGate", area)
	_box_shape(area, Vector3(4.6, 4.0, 1.6), Vector3(0, 2.0, 0))
	var pillars := StaticBody3D.new()
	pillars.name = "Pillars"
	pillars.collision_layer = LAYER_WORLD
	pillars.collision_mask = 0
	area.add_child(pillars)
	_box_shape(pillars, Vector3(0.7, 4.0, 0.7), Vector3(-2.6, 2.0, 0), "LeftPillar")
	_box_shape(pillars, Vector3(0.7, 4.0, 0.7), Vector3(2.6, 2.0, 0), "RightPillar")
	_save(area, "goal")
