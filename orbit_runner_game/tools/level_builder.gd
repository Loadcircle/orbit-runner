class_name LevelBuilder
extends RefCounted
## Small layout DSL used by tools/build_levels.gd to author levels.
##
## A "cursor" walks along the route: plat() places the next platform `gap`
## metres after the previous far edge (along the current heading), `rise`
## metres higher and `side` metres to the right. Gaps are chosen against the
## movement capabilities documented in docs/LEVEL_DESIGN.md, so every jump in
## the main route is reachable by construction.

const PROPS := "res://scenes/props/%s.tscn"
const MODELS := "res://art/models/%s.glb"
const SIZES := {
	"S": Vector2(3, 3), "M": Vector2(4, 6), "L": Vector2(6, 10), "XL": Vector2(8, 14), "Strip": Vector2(2.5, 8),
	"Wide": Vector2(6, 6),
}
const DECOR := {
	"isle": ["ENV_Tree", "ENV_Pine", "ENV_Bush", "ENV_Rock_A", "ENV_Rock_B", "ENV_Bush"],
	"toy": ["ENV_ToyBlocks", "ENV_LampPost", "ENV_Gear", "ENV_ToyBlocks", "ENV_LampPost"],
	"ruin": ["ENV_RuinPillar", "ENV_Palm", "ENV_Obelisk", "ENV_Crystal", "ENV_RuinArch", "ENV_Palm"],
}

var root: Level
var biome_prefix := "isle"
var cursor := Vector3.ZERO
var yaw := 0.0
var path_length := 0.0
## Extra seconds a skilled player must wait (moving / timed platforms).
var wait_time := 0.0
var min_y := 0.0
var last: Node3D
var last_size := Vector2(4, 6)
var last_center := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var auto_sparks := true

var _groups: Dictionary = {}
var _last_zone: CameraZone
var _scene_cache: Dictionary = {}


func begin(level_name: String, prefix: String, biome: BiomeTheme, seed_value: int) -> void:
	root = Level.new()
	root.name = level_name
	root.biome = biome
	biome_prefix = prefix
	rng.seed = seed_value
	for group in ["Geometry", "Elements", "Hazards", "Collectibles", "Checkpoints", "CameraZones", "Prompts", "Decor"]:
		var n := Node3D.new()
		n.name = group
		root.add_child(n)
		_groups[group] = n
	var start := Marker3D.new()
	start.name = "PlayerStart"
	root.add_child(start)
	cursor = Vector3.ZERO
	yaw = 0.0
	path_length = 0.0
	wait_time = 0.0
	min_y = 0.0


# ------------------------------------------------------------------ geometry helpers

func fwd() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(yaw))


func right() -> Vector3:
	return fwd().cross(Vector3.UP)


## World position relative to the last main platform's top centre.
func local(lx: float, lz: float, y := 0.0) -> Vector3:
	return last_center + right() * lx + fwd() * lz + Vector3.UP * y


func _instance(path: String) -> Node3D:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return (_scene_cache[path] as PackedScene).instantiate() as Node3D


func _add(group: String, node: Node3D, pos: Vector3, yaw_deg := yaw) -> Node3D:
	_groups[group].add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	min_y = minf(min_y, pos.y)
	return node


func _camera_zone(center: Vector3, size: Vector2, yaw_deg: float) -> CameraZone:
	var zone := CameraZone.new()
	zone.yaw_degrees = yaw_deg
	zone.collision_layer = 4
	zone.collision_mask = 2
	zone.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 1.0, 14.0, size.y + 1.0)
	shape.shape = box
	shape.position.y = 5.0
	zone.add_child(shape)
	_add("CameraZones", zone, center, yaw_deg)
	return zone


func _gap_sparks(from: Vector3, to: Vector3, gap: float) -> void:
	if not auto_sparks or gap < 1.5:
		return
	var count := clampi(int(gap / 1.6), 1, 5)
	var apex := clampf(gap * 0.35, 1.0, 2.6)
	for i in count:
		var t := float(i + 1) / float(count + 1)
		var p := from.lerp(to, t)
		p.y += 4.0 * apex * t * (1.0 - t) + 1.0
		spark(p)


# ------------------------------------------------------------------ route pieces

## First platform: the player starts 2 m from its back edge.
func start(size_key := "L") -> Node3D:
	var size: Vector2 = SIZES[size_key]
	var center := cursor + fwd() * (size.y * 0.5 - 2.0)
	(root.get_node("PlayerStart") as Marker3D).position = cursor + Vector3.UP * 0.1
	last = _place_platform(size_key, center)
	cursor = center + fwd() * size.y * 0.5
	return last


func plat(size_key: String, gap: float, rise := 0.0, side := 0.0) -> Node3D:
	var size: Vector2 = SIZES[size_key]
	var from := cursor
	var center := cursor + fwd() * (gap + size.y * 0.5) + right() * side + Vector3.UP * rise
	var near_edge := center - fwd() * size.y * 0.5
	_gap_sparks(from, near_edge, gap)
	last = _place_platform(size_key, center)
	cursor = center + fwd() * size.y * 0.5
	path_length += gap + size.y + absf(rise) * 0.5
	return last


func _place_platform(size_key: String, center: Vector3) -> Node3D:
	var size: Vector2 = SIZES[size_key]
	var node := _instance(PROPS % ("platforms/%s_%s" % [biome_prefix, size_key.to_lower()]))
	_add("Geometry", node, center)
	last_size = size
	last_center = center
	_last_zone = _camera_zone(center, size, yaw)
	if auto_sparks and size.y >= 6.0:
		for i in 2:
			spark(center + fwd() * (i - 0.5) * size.y * 0.4 + Vector3.UP * 1.0)
	return node


## Optional platform beside the route (does not move the cursor).
## `gap` is the clear distance from the last main platform's side edge.
func side_plat(size_key: String, gap: float, rise: float, along := 0.0, dir := 1.0) -> Node3D:
	var size: Vector2 = SIZES[size_key]
	var dist := last_size.x * 0.5 + gap + size.x * 0.5
	var center := last_center + right() * dist * dir + fwd() * along + Vector3.UP * rise
	var node := _instance(PROPS % ("platforms/%s_%s" % [biome_prefix, size_key.to_lower()]))
	_add("Geometry", node, center)
	_camera_zone(center, size, yaw)
	return node


## Turns the route (positive = left) around the last platform.
func turn(degrees: float) -> void:
	yaw += degrees
	cursor = last_center + fwd() * (last_size.x * 0.5 if absf(fmod(degrees, 180.0)) > 1.0 else last_size.y * 0.5)
	# The platform where the turn happens already faces the new direction.
	if _last_zone:
		_last_zone.free()
		_last_zone = null
	_camera_zone(last_center, Vector2(maxf(last_size.x, last_size.y), maxf(last_size.x, last_size.y)), yaw)


func mover(gap: float, travel: float, axis := "fwd", period := 4.0, rise := 0.0, phase := 0.0) -> Node3D:
	var start_pos := cursor + fwd() * (gap + 1.5) + Vector3.UP * rise
	var node := _instance(PROPS % "moving_platform") as MovingPlatform
	var travel_vec := fwd() * travel
	if axis == "side":
		travel_vec = right() * travel
	elif axis == "up":
		travel_vec = Vector3.UP * travel
	node.travel = travel_vec
	node.period = period
	node.phase = phase
	_add("Elements", node, start_pos)
	_gap_sparks(cursor, start_pos - fwd() * 1.5, gap)
	last = node
	last_size = Vector2(3, 3)
	var end_pos := start_pos + travel_vec
	last_center = end_pos
	cursor = end_pos + fwd() * 1.5
	path_length += gap + 3.0 + travel * 0.3
	wait_time += period * 0.35
	return node


func crumble(gap: float, rise := 0.0, side := 0.0) -> Node3D:
	var center := cursor + fwd() * (gap + 1.5) + right() * side + Vector3.UP * rise
	_gap_sparks(cursor, center - fwd() * 1.5, gap)
	var node := _instance(PROPS % "crumble_platform")
	_add("Elements", node, center)
	last = node
	last_size = Vector2(3, 3)
	last_center = center
	cursor = center + fwd() * 1.5
	path_length += gap + 3.0
	return node


func timed(gap: float, rise := 0.0, phase := 0.0, on_time := 2.2, off_time := 1.4, side := 0.0) -> Node3D:
	var center := cursor + fwd() * (gap + 1.6) + right() * side + Vector3.UP * rise
	_gap_sparks(cursor, center - fwd() * 1.6, gap)
	var node := _instance(PROPS % "timed_platform") as TimedPlatform
	node.phase = phase
	node.on_time = on_time
	node.off_time = off_time
	_add("Elements", node, center)
	last = node
	last_size = Vector2(3.2, 3.2)
	last_center = center
	cursor = center + fwd() * 1.6
	path_length += gap + 3.2
	wait_time += off_time * 0.25
	return node


## Wind column whose ring sits `gap` ahead of the cursor at `rise`; the player
## comes out at the top (cursor moves to the top, 1.5 m past the column).
func wind(gap: float, height: float, rise := -1.0) -> Node3D:
	var base := cursor + fwd() * (gap + 1.5) + Vector3.UP * rise
	var node := _instance(PROPS % "wind_column") as WindColumn
	node.height = height
	_add("Elements", node, base)
	for i in 4:
		spark(base + Vector3.UP * (1.5 + i * height / 4.0))
	last_center = base + Vector3.UP * height
	last_size = Vector2(3, 3)
	cursor = base + Vector3.UP * height + fwd() * 1.5
	path_length += gap + 3.0 + height * 0.4
	return node


# ------------------------------------------------------------------ elements on the last platform

func trampoline(lx := 0.0, lz := 0.0, strength := 18.0) -> Node3D:
	var node := _instance(PROPS % "trampoline") as Trampoline
	node.strength = strength
	return _add("Elements", node, local(lx, lz))


func trampoline_at(pos: Vector3, strength := 18.0) -> Node3D:
	var node := _instance(PROPS % "trampoline") as Trampoline
	node.strength = strength
	return _add("Elements", node, pos)


func boost(lx := 0.0, lz := 0.0, speed := 17.0) -> Node3D:
	var node := _instance(PROPS % "boost_pad") as BoostPad
	node.speed = speed
	return _add("Elements", node, local(lx, lz))


func spikes(lx: float, lz: float) -> Node3D:
	return _add("Hazards", _instance(PROPS % "spikes"), local(lx, lz))


func spinner(lx := 0.0, lz := 0.0, speed := 70.0, start_angle := 0.0) -> Node3D:
	var node := _instance(PROPS % "spinner") as Spinner
	node.degrees_per_second = speed
	node.start_angle = start_angle
	return _add("Hazards", node, local(lx, lz))


func patrol(lx: float, lz: float, to_lx: float, to_lz: float, speed := 3.0, phase := 0.0) -> Node3D:
	var node := _instance(PROPS % "patrol_bot") as PatrolHazard
	var a := local(lx, lz)
	node.travel = local(to_lx, to_lz) - a
	node.speed = speed
	node.phase = phase
	return _add("Hazards", node, a, 0.0)


func laser(lz: float, period := 0.0, phase := 0.0, height := 1.05) -> Node3D:
	var node := _instance(PROPS % "laser_gate") as LaserGate
	node.width = last_size.x - 0.2
	node.period = period
	node.phase = phase
	node.beam_height = height
	return _add("Hazards", node, local(0.0, lz))


func checkpoint(lz := 0.0, lx := 0.0) -> Node3D:
	return _add("Checkpoints", _instance(PROPS % "checkpoint"), local(lx, lz))


func goal(lz := 0.0) -> Node3D:
	return _add("Elements", _instance(PROPS % "goal"), local(0.0, lz))


func gem(index: int, pos: Vector3) -> Node3D:
	var node := _instance(PROPS % "gem") as Gem
	node.index = index
	return _add("Collectibles", node, pos)


func spark(pos: Vector3) -> Node3D:
	return _add("Collectibles", _instance(PROPS % "spark"), pos)


func spark_line(a: Vector3, b: Vector3, count: int) -> void:
	for i in count:
		spark(a.lerp(b, float(i) / maxf(count - 1, 1)))


func prompt(text_key: String, lz := 0.0, length := 0.0) -> void:
	var p := TutorialPrompt.new()
	p.text_key = text_key
	p.collision_layer = 4
	p.collision_mask = 2
	p.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(last_size.x + 1.0, 6.0, length if length > 0.0 else last_size.y)
	shape.shape = box
	shape.position.y = 2.5
	p.add_child(shape)
	_add("Prompts", p, local(0.0, lz))


## Scatters decoration near the edges of the last platform, off the route line.
func decorate(count := 2) -> void:
	if last_size.x < 4.0:
		return
	var kinds: Array = DECOR[biome_prefix]
	for i in count:
		var sx := (1.0 if rng.randf() > 0.5 else -1.0) * (last_size.x * 0.5 - rng.randf_range(0.6, 1.0))
		var sz := rng.randf_range(-0.38, 0.38) * last_size.y
		var model := _instance(MODELS % kinds[rng.randi() % kinds.size()])
		model.scale = Vector3.ONE * rng.randf_range(0.8, 1.15)
		_add("Decor", model, local(sx, sz), rng.randf() * 360.0)


## Free-floating decoration (background islands, clouds) at a world position.
func deco(model_name: String, pos: Vector3, scale := 1.0, yaw_deg := 0.0) -> Node3D:
	var model := _instance(MODELS % model_name)
	model.scale = Vector3.ONE * scale
	return _add("Decor", model, pos, yaw_deg)


func finish_level(path: String) -> Dictionary:
	root.kill_height = min_y - 9.0
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	var sparks := root.find_children("*", "Spark", true, false).size()
	var result := {"path": path, "length": path_length, "wait": wait_time, "sparks": sparks, "error": error_string(err)}
	root.free()
	return result


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path == "":
			_set_owner(child, owner_node)
