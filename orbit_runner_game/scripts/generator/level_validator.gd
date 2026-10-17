class_name LevelValidator
extends RefCounted
## Static checks run on every generated level before the bot plays it:
## reach of every jump with its annotated technique, clearances, clean
## landings, safe waiting spots, rhythm (rests and checkpoints) and gems.
## Works on a level that is not in the scene tree yet (root at the origin).

## Fraction of the technique's reach a gap may use.
const REACH_MARGIN := 0.975
## Minimum clearance between two pieces of geometry.
const CLEARANCE := 0.5
## No hazard closer than this to a landing point.
const LANDING_CLEAR := 2.0
const SPINNER_RADIUS := 3.3
const PATROL_RADIUS := 0.75
const SPIKE_HALF := 0.9

var reach: MovementReach


func _init(movement_reach: MovementReach = null) -> void:
	reach = movement_reach if movement_reach else MovementReach.new()


## Returns {"ok", "errors": [String], "warnings": [String], "windows": [float s]}.
func validate(level: Level, profile: DifficultyProfile) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var windows: Array[float] = []
	var route: Array = level.get_meta("route", [])
	var hazards := _hazards(level)
	if route.size() < 3:
		errors.append("route too short")
	for i in range(1, route.size()):
		_check_step(level, route, i, hazards, errors, windows)
	_check_overlaps(level, route, errors)
	_check_rhythm(level, route, profile, errors)
	var gems := level.find_children("*", "Gem", true, false)
	var meta: Dictionary = level.get_meta("generated", {})
	var spec_mode := int((meta.get("spec", {}) as Dictionary).get("mode", 0))
	if spec_mode != LevelSpec.Mode.TOWER:
		if gems.size() != 3:
			errors.append("expected 3 gems, found %d" % gems.size())
		if level.find_child("Goal", true, false) == null:
			errors.append("no goal")
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "windows": windows}


# ------------------------------------------------------------------ jumps

func _check_step(level: Level, route: Array, i: int, hazards: Array[Dictionary], errors: Array[String],
		windows: Array[float]) -> void:
	var from: Dictionary = route[i - 1]
	var to: Dictionary = route[i]
	var tech: String = to.get("tech", "")
	if tech == "":
		tech = "jump"
	if tech in ["wind", "air", "walk"]:
		return
	var rise: float = (to["pos"] as Vector3).y - _exit_height(level, from)
	var gap := _edge_distance(level, from, to)
	if to["kind"] == "mover" or from["kind"] == "mover":
		# Movers bring the platform to the player: check against the closest point.
		gap = maxf(gap, 0.0)
	var reach_tech := tech
	if tech == "ride":
		reach_tech = "jump"
	elif tech == "trampoline":
		reach_tech = "trampoline_24" if float(to.get("strength", 20.0)) > 22.0 else "trampoline"
		if not _has_near(level, "Elements", "Trampoline", from, 8.0):
			errors.append("piece %d: trampoline jump without a trampoline" % i)
	elif tech == "boost":
		if not _has_near(level, "Elements", "BoostPad", from, 8.0):
			errors.append("piece %d: boost jump without a boost pad" % i)
	var max_gap := reach.max_gap(reach_tech, rise)
	if rise > reach.max_rise(reach_tech) + 0.05:
		errors.append("piece %d: rise %.1f too high for %s" % [i, rise, tech])
	elif gap > max_gap * REACH_MARGIN:
		errors.append("piece %d: gap %.1f > %.1f (%s, rise %.1f)" % [i, gap, max_gap * REACH_MARGIN, tech, rise])
	if gap > 0.5:
		windows.append(reach.takeoff_window(reach_tech, gap, rise))
	_check_landing(route, i, hazards, errors)
	_check_ceiling(level, route, i, reach_tech, errors)
	if to.get("wait", "") != "" and from["kind"] == "crumble":
		errors.append("piece %d: waiting spot is a crumbling tile" % i)
	if to.get("wait", "") != "" and i >= 2 and to["kind"] != (from["kind"] as String):
		# First piece of a waiting chain: the spot before it must be safe.
		var spot := _far_point(from, 1.0)
		for h in hazards:
			if _hazard_distance(h, spot) < 1.0:
				errors.append("piece %d: hazard over the waiting spot" % i)


func _check_landing(route: Array, i: int, hazards: Array[Dictionary], errors: Array[String]) -> void:
	var to: Dictionary = route[i]
	if to["kind"] != "plat":
		return
	var f := _fwd(to)
	var land: Vector3 = (to["pos"] as Vector3) - f * (float(to["len"]) * 0.5 - 1.5)
	for h in hazards:
		if absf((h["pos"] as Vector3).y - land.y) > 2.5:
			continue
		if _hazard_distance(h, land) < LANDING_CLEAR:
			errors.append("piece %d: %s too close to the landing" % [i, h["kind"]])


func _check_ceiling(level: Level, route: Array, i: int, tech: String, errors: Array[String]) -> void:
	var from: Dictionary = route[i - 1]
	var to: Dictionary = route[i]
	var a: Vector3 = _far_point(from, 0.0)
	var c: Vector3 = _near_point(to)
	var top := maxf(a.y, c.y) + reach.apex(tech) + 1.9
	var bottom := minf(a.y, c.y) + 0.4
	for j in route.size():
		if absf(j - i) <= 1:
			continue
		var other: Dictionary = route[j]
		var p: Vector3 = other["pos"]
		if p.y <= bottom or p.y >= top:
			continue
		var poly := _footprint(other)
		if _segment_hits_polygon(Vector2(a.x, a.z), Vector2(c.x, c.z), poly, 0.6):
			errors.append("piece %d: piece %d blocks the jump arc" % [i, j])
			return


# ------------------------------------------------------------------ geometry

func _check_overlaps(level: Level, route: Array, errors: Array[String]) -> void:
	var boxes: Array[Dictionary] = []
	for i in route.size():
		var piece: Dictionary = route[i]
		boxes.append({"index": i, "poly": _footprint(piece, _mover_travel(level, piece)), "y": (piece["pos"] as Vector3).y,
				"top": (piece["pos"] as Vector3).y + _mover_rise(level, piece)})
	for extra in level.get_meta("extras", []):
		boxes.append({"index": -1, "poly": _footprint(extra), "y": (extra["pos"] as Vector3).y,
				"top": (extra["pos"] as Vector3).y})
	for a in boxes.size():
		for b in range(a + 1, boxes.size()):
			var ia: int = boxes[a]["index"]
			var ib: int = boxes[b]["index"]
			if ia >= 0 and ib >= 0 and absi(ia - ib) <= 1:
				continue
			var low := maxf(boxes[a]["y"], boxes[b]["y"])
			var high := minf(boxes[a]["top"], boxes[b]["top"])
			if low - high > 3.0:
				continue
			if _polygon_distance(boxes[a]["poly"], boxes[b]["poly"]) < CLEARANCE:
				errors.append("overlap between piece %d and piece %d" % [ia, ib])


func _check_rhythm(level: Level, route: Array, profile: DifficultyProfile, errors: Array[String]) -> void:
	var meta: Dictionary = level.get_meta("generated", {})
	var run := 0
	for motif in meta.get("motifs", []):
		if motif["rest"]:
			run = 0
		else:
			run += 1
			if run > profile.motifs_without_rest + 1:
				errors.append("too many motifs without a rest")
				break
	var checkpoints := level.find_children("*", "Checkpoint", true, false)
	for node in checkpoints:
		var cp := node as Node3D
		var on_rest := false
		for piece in route:
			if piece.get("rest", false) and _contains(piece, cp.position, 0.5):
				on_rest = true
		if not on_rest:
			errors.append("checkpoint outside a rest platform")


func _fwd(piece: Dictionary) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(piece["yaw"])))


func _near_point(piece: Dictionary) -> Vector3:
	return (piece["pos"] as Vector3) - _fwd(piece) * float(piece["len"]) * 0.5


func _far_point(piece: Dictionary, inset: float) -> Vector3:
	return (piece["pos"] as Vector3) + _fwd(piece) * (float(piece["len"]) * 0.5 - inset)


## Height of the surface the player leaves from (movers: their end position).
func _exit_height(level: Level, piece: Dictionary) -> float:
	return (piece["pos"] as Vector3).y + _mover_rise(level, piece)


func _mover_travel(level: Level, piece: Dictionary) -> Vector3:
	if piece["kind"] != "mover":
		return Vector3.ZERO
	var node := level.get_node_or_null(piece["node"]) as MovingPlatform
	return node.travel if node else Vector3.ZERO


func _mover_rise(level: Level, piece: Dictionary) -> float:
	return maxf(_mover_travel(level, piece).y, 0.0)


## Oriented rectangle of a piece in the XZ plane (optionally swept by a mover).
func _footprint(piece: Dictionary, travel := Vector3.ZERO) -> PackedVector2Array:
	var f := _fwd(piece)
	var r := f.cross(Vector3.UP)
	var c: Vector3 = piece["pos"]
	var hl := float(piece["len"]) * 0.5
	var hw := float(piece.get("wid", 3.0)) * 0.5
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector3 = c + r * hw * corner.x + f * hl * corner.y
		points.append(Vector2(p.x, p.z))
	if travel != Vector3.ZERO:
		var moved := PackedVector2Array()
		for p in points:
			moved.append(p + Vector2(travel.x, travel.z))
		points = _hull(points + moved)
	return points


func _edge_distance(level: Level, from: Dictionary, to: Dictionary) -> float:
	var a := _footprint(from)
	if from["kind"] == "mover":
		var t := _mover_travel(level, from)
		var moved := PackedVector2Array()
		for p in a:
			moved.append(p + Vector2(t.x, t.z))
		a = moved
	return _polygon_distance(a, _footprint(to))


func _contains(piece: Dictionary, point: Vector3, margin: float) -> bool:
	var rel := point - (piece["pos"] as Vector3)
	var f := _fwd(piece)
	var r := f.cross(Vector3.UP)
	return absf(rel.dot(f)) <= float(piece["len"]) * 0.5 + margin \
		and absf(rel.dot(r)) <= float(piece.get("wid", 3.0)) * 0.5 + margin and absf(rel.y) < 1.5


func _has_near(level: Level, group: String, type_name: String, piece: Dictionary, radius: float) -> bool:
	var parent := level.get_node_or_null(group)
	if parent == null:
		return false
	for child in parent.get_children():
		if child.get_class() == type_name or (child.get_script() and (child.get_script() as Script).get_global_name() == type_name):
			if _contains(piece, (child as Node3D).position, 0.5) \
					or (child as Node3D).position.distance_to(piece["pos"]) < radius * 0.5:
				return true
	return false


# ------------------------------------------------------------------ hazards

func _hazards(level: Level) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parent := level.get_node_or_null("Hazards")
	if parent == null:
		return result
	for child in parent.get_children():
		var n := child as Node3D
		if n is Spinner:
			result.append({"kind": "spinner", "pos": n.position, "radius": SPINNER_RADIUS})
		elif n is PatrolHazard:
			var p := n as PatrolHazard
			result.append({"kind": "patrol", "pos": n.position, "to": n.position + p.travel, "radius": PATROL_RADIUS})
		elif n is LaserGate:
			result.append({"kind": "laser", "pos": n.position, "yaw": n.rotation.y, "width": (n as LaserGate).width})
		else:
			result.append({"kind": "spikes", "pos": n.position, "radius": SPIKE_HALF})
	return result


func _hazard_distance(h: Dictionary, point: Vector3) -> float:
	var p: Vector3 = h["pos"]
	match h["kind"]:
		"patrol":
			var a := Vector2(p.x, p.z)
			var b := Vector2((h["to"] as Vector3).x, (h["to"] as Vector3).z)
			var q := Vector2(point.x, point.z)
			return Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) - float(h["radius"])
		"laser":
			var f := Vector3.FORWARD.rotated(Vector3.UP, float(h["yaw"]))
			return absf((point - p).dot(f)) - 0.2
	return Vector2(point.x - p.x, point.z - p.z).length() - float(h["radius"])


# ------------------------------------------------------------------ 2D helpers

func _polygon_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return 0.0
	var best := INF
	for i in a.size():
		var a1 := a[i]
		var a2 := a[(i + 1) % a.size()]
		for p in b:
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, a1, a2).distance_to(p))
	for i in b.size():
		var b1 := b[i]
		var b2 := b[(i + 1) % b.size()]
		for p in a:
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, b1, b2).distance_to(p))
	return best


func _segment_hits_polygon(a: Vector2, b: Vector2, poly: PackedVector2Array, margin: float) -> bool:
	if Geometry2D.is_point_in_polygon(a, poly) or Geometry2D.is_point_in_polygon(b, poly):
		return true
	for i in poly.size():
		var p1 := poly[i]
		var p2 := poly[(i + 1) % poly.size()]
		if Geometry2D.segment_intersects_segment(a, b, p1, p2) != null:
			return true
		var closest := Geometry2D.get_closest_points_between_segments(a, b, p1, p2)
		if closest[0].distance_to(closest[1]) < margin:
			return true
	return false


func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[-1]:
		hull.remove_at(hull.size() - 1)
	return hull
