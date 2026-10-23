extends Node
## Exports campaign level scenes as JSON (schema 1) for the Roblox LevelBuilder.
##   godot --headless --path . res://tools/export_level_json.tscn -- in=res://scenes/levels out=../roblox/levels_json
## `in` is a level scene or a folder of them; `ids=tutorial,w1_l1` limits a folder.
## Output is in metres and Godot axes (Y up, forward -Z); rotations are Euler
## degrees in Godot's YXZ order. Read-only on the game: it only loads scenes.
## Schema: roblox/levels_json/SCHEMA.md.

const SCHEMA := 1
const CATALOG_PATH := "res://resources/levels/level_catalog.tres"
const DIFFICULTY_NAMES := ["easy", "medium", "hard", "extreme"]

var _catalog: LevelCatalog


func _ready() -> void:
	var args := _parse_args()
	var input: String = args.get("in", "res://scenes/levels")
	var out_dir: String = args.get("out", "../roblox/levels_json")
	if out_dir.is_relative_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(out_dir).simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var only: PackedStringArray = String(args.get("ids", "")).split(",", false)
	_catalog = load(CATALOG_PATH) as LevelCatalog
	var paths: Array[String] = []
	if input.ends_with(".tscn"):
		paths.append(input)
	else:
		for file in DirAccess.get_files_at(input):
			if file.ends_with(".tscn") and (only.is_empty() or only.has(file.get_basename())):
				paths.append(input.path_join(file))
	var failures := 0
	for path in paths:
		var data := export_scene(path)
		if data.is_empty():
			failures += 1
			continue
		var file_path := out_dir.path_join("%s.json" % data["id"])
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data, "\t", false))
		file.close()
		print("%s: platforms=%d elements=%d hazards=%d sparks=%d checkpoints=%d -> %s" % [data["id"],
				data["platforms"].size(), data["elements"].size(), data["hazards"].size(),
				data["collectibles"]["sparks"].size(), data["checkpoints"].size(), file_path])
	get_tree().quit(1 if failures > 0 else 0)


func export_scene(path: String) -> Dictionary:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("cannot load %s" % path)
		return {}
	var root := packed.instantiate() as Node3D
	var id := path.get_file().get_basename()
	var info: LevelInfo = _catalog.get_level(StringName(id)) if _catalog else null
	var data := {
		"schema": SCHEMA,
		"id": id,
		"name_key": info.title_key if info else "",
		"hint_key": info.hint_key if info else "",
		"world": (info.world_index + 1) if info else 0,
		"index": _index_in_world(info),
		"tutorial": info.is_tutorial if info else false,
		"biome": String(info.biome.id) if info and info.biome else String(root.get("biome").id) if root.get("biome") else "",
		"difficulty": DIFFICULTY_NAMES[info.difficulty] if info and info.difficulty >= 0 else "",
		"medals": {"gold": info.gold_time, "silver": info.silver_time} if info else {},
		"kill_height": float(root.get("kill_height")),
		"source": _source(root),
		"player_start": {},
		"route": [],
		"platforms": [],
		"elements": [],
		"hazards": [],
		"collectibles": {"gems": [], "sparks": []},
		"checkpoints": [],
		"camera_zones": [],
		"prompts": [],
		"decor": [],
		"goal": {},
	}
	var start := root.get_node_or_null("PlayerStart") as Node3D
	if start:
		data["player_start"] = {"pos": _vec(_global(start).origin), "yaw": float(root.get("start_yaw_degrees"))}
	for piece in root.get_meta("route", []):
		data["route"].append(_plain(piece))
	for group in ["Geometry", "Elements", "Hazards", "Collectibles", "Checkpoints", "CameraZones", "Prompts", "Decor"]:
		var node := root.get_node_or_null(group)
		if node == null:
			continue
		for child in node.get_children():
			if child is Node3D:
				_export_node(child, group, data)
	root.free()
	return data


func _export_node(node: Node3D, group: String, data: Dictionary) -> void:
	var xform := _global(node)
	var entry := {"pos": _vec(xform.origin), "rot": _rot(xform.basis)}
	var scale := xform.basis.get_scale()
	if not scale.is_equal_approx(Vector3.ONE):
		entry["scale"] = _vec(scale)
	var kind := _kind(node)
	match kind:
		"platform":
			entry["asset"] = _model_asset(node)
			entry["collider"] = _box_collider(node)
			data["platforms"].append(entry)
		"Trampoline":
			_add_element(data, entry, "trampoline", {"strength": node.get("strength")})
		"WindColumn":
			_add_element(data, entry, "wind_column",
					{"height": node.get("height"), "lift": node.get("lift"), "max_up_speed": node.get("max_up_speed")})
		"BoostPad":
			_add_element(data, entry, "boost_pad", {"speed": node.get("speed")})
		"MovingPlatform":
			entry["collider"] = _box_collider(node)
			_add_element(data, entry, "moving_platform", {"travel": _vec(node.get("travel")),
					"period": node.get("period"), "phase": node.get("phase"), "pause_fraction": node.get("pause_fraction")})
		"TimedPlatform":
			_add_element(data, entry, "timed_platform", {"on_time": node.get("on_time"), "off_time": node.get("off_time"),
					"phase": node.get("phase"), "warning": node.get("warning")})
		"CrumblePlatform":
			_add_element(data, entry, "crumble_platform",
					{"warning_time": node.get("warning_time"), "respawn_time": node.get("respawn_time")})
		"Goal":
			data["goal"] = entry
		"Spinner":
			_add_hazard(data, entry, "spinner",
					{"degrees_per_second": node.get("degrees_per_second"), "start_angle": node.get("start_angle")})
		"PatrolHazard":
			_add_hazard(data, entry, "patrol", {"travel": _vec(node.get("travel")), "speed": node.get("speed"),
					"phase": node.get("phase")})
		"LaserGate":
			_add_hazard(data, entry, "laser", {"width": node.get("width"), "beam_height": node.get("beam_height"),
					"period": node.get("period"), "on_fraction": node.get("on_fraction"), "phase": node.get("phase")})
		"spikes":
			_add_hazard(data, entry, "spikes", {})
		"Gem":
			data["collectibles"]["gems"].append({"index": node.get("index"), "pos": entry["pos"]})
		"Spark":
			data["collectibles"]["sparks"].append(entry["pos"])
		"Checkpoint":
			var spawn := node.get_node_or_null("Spawn") as Node3D
			entry["spawn"] = _vec(_global(spawn).origin) if spawn else entry["pos"]
			data["checkpoints"].append(entry)
		"CameraZone":
			_add_box(entry, node)
			entry["yaw"] = node.get("yaw_degrees")
			data["camera_zones"].append(entry)
		"TutorialPrompt":
			entry["key"] = node.get("text_key")
			_add_box(entry, node)
			data["prompts"].append(entry)
		"decor":
			entry["asset"] = _model_asset(node)
			data["decor"].append(entry)
		_:
			push_warning("%s: unexported node %s (%s) in %s" % [data["id"], node.name, kind, group])


func _add_element(data: Dictionary, entry: Dictionary, type: String, params: Dictionary) -> void:
	entry["type"] = type
	entry["params"] = params
	data["elements"].append(entry)


func _add_hazard(data: Dictionary, entry: Dictionary, type: String, params: Dictionary) -> void:
	entry["type"] = type
	entry["params"] = params
	data["hazards"].append(entry)


## Trigger volumes: box size and centre offset from the node origin (local).
func _add_box(entry: Dictionary, node: Node) -> void:
	var box := _box_collider(node)
	entry["size"] = box.get("size", [0.0, 0.0, 0.0])
	entry["offset"] = box.get("offset", [0.0, 0.0, 0.0])


## Script class name, or a structural kind for script-less nodes.
func _kind(node: Node) -> String:
	var script := node.get_script() as Script
	if script and script.get_global_name() != &"":
		return String(script.get_global_name())
	var scene := node.scene_file_path
	if scene.contains("/platforms/"):
		return "platform"
	if scene.get_file() == "spikes.tscn":
		return "spikes"
	if scene.ends_with(".glb"):
		return "decor"
	return node.get_class()


## GLB basename of the visual model (PLAT_Isle_M, ENV_Tree...).
func _model_asset(node: Node) -> String:
	if node.scene_file_path.ends_with(".glb"):
		return node.scene_file_path.get_file().get_basename()
	var model := node.get_node_or_null("Model")
	if model and model.scene_file_path != "":
		return model.scene_file_path.get_file().get_basename()
	return ""


## First box collision shape under the node: size and centre offset (local).
func _box_collider(node: Node) -> Dictionary:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var shape := (child as CollisionShape3D).shape
		if shape is BoxShape3D:
			var offset := _relative(child as Node3D, node as Node3D).origin
			return {"size": _vec(shape.size), "offset": _vec(offset)}
	return {}


func _source(root: Node) -> Dictionary:
	if root.has_meta("generated"):
		var meta: Dictionary = root.get_meta("generated")
		return {"kind": "campaign_gen", "seed": meta.get("seed", 0), "route_hash": meta.get("route_hash", ""),
				"difficulty_index": meta.get("index", 0.0)}
	return {"kind": "handmade"}


func _index_in_world(info: LevelInfo) -> int:
	if info == null or _catalog == null:
		return 0
	var levels := _catalog.levels_in_world(info.world_index)
	var position := 0
	for level in levels:
		if level.is_tutorial:
			continue
		position += 1
		if level.id == info.id:
			return position
	return 0


# ------------------------------------------------------------------ transforms (nodes are not in the tree)

func _global(node: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform


func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent is Node3D and parent != ancestor:
		xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform


func _vec(v: Vector3) -> Array:
	return [_round(v.x), _round(v.y), _round(v.z)]


func _rot(basis: Basis) -> Array:
	var euler := basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	return [_round(rad_to_deg(euler.x)), _round(rad_to_deg(euler.y)), _round(rad_to_deg(euler.z))]


func _round(value: float) -> float:
	var r := snappedf(value, 0.0001)
	return 0.0 if absf(r) < 0.00005 else r


## Route metadata to JSON-safe values (Vector3 -> array, NodePath -> string).
func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[String(key)] = _plain(value[key])
			return out
		TYPE_ARRAY:
			var list := []
			for item in value:
				list.append(_plain(item))
			return list
		TYPE_VECTOR3:
			return _vec(value)
		TYPE_NODE_PATH, TYPE_STRING_NAME:
			return String(value)
		TYPE_FLOAT:
			return _round(value)
	return value


func _parse_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	return args
