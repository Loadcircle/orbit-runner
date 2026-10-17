extends Node
## Temporary autopilot (not shipped). Follows the route metadata saved by the
## level builder, driving ONLY the real input actions (same path as players),
## and picks the move each gap needs. Reports deaths and the finish time.
## Args: <level scene> [max seconds]

var level: Level
var route: Array = []
var time := 0.0
var max_time := 240.0
var deaths := 0
var index := 0
var plan := ""
var plan_for := -1
var trampolines: Array[Node3D] = []
var hazards: Array[Node3D] = []
var lasers: Array[LaserGate] = []
var last_death_index := -1
var same_spot_deaths := 0
var trace: Array[String] = []
var takeoff_index := 0
var was_floor := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	max_time = float(args[1]) if args.size() > 1 else 240.0
	level = (load(args[0]) as PackedScene).instantiate()
	add_child(level)
	route = (level.get_meta("route") as Array).duplicate()
	var goal := level.find_child("Goal", true, false) as Node3D
	route.append({"kind": "goal", "pos": goal.global_position, "yaw": rad_to_deg(goal.rotation.y), "len": 1.5,
			"gap": 0.0, "rise": 0.0, "node": level.get_path_to(goal)})
	for n in level.get_node("Elements").get_children():
		if n is Trampoline:
			trampolines.append(n)
	for n in level.get_node("Hazards").get_children():
		if n is LaserGate:
			lasers.append(n)
		elif n is PatrolHazard or n is Spinner:
			hazards.append(n)
	level.player.died.connect(_on_died)
	print("BOT route=", route.size())


func _on_died() -> void:
	deaths += 1
	if index == last_death_index:
		same_spot_deaths += 1
	else:
		same_spot_deaths = 1
	last_death_index = index
	if true:
		for line in trace:
			print("   ", line)
	print("DIED #%d piece=%d next=%s plan=%s pos=%s t=%.1f" % [deaths, index, _piece(index + 1)["kind"], plan,
			level.player.global_position, time])
	plan_for = -1


func _piece(i: int) -> Dictionary:
	return route[clampi(i, 0, route.size() - 1)]


func _node(i: int) -> Node3D:
	return level.get_node_or_null(_piece(i)["node"]) as Node3D


func _fwd(i: int) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(_piece(i)["yaw"])))


func _piece_pos(i: int) -> Vector3:
	var p := _piece(i)
	if p["kind"] == "mover" or p["kind"] == "crumble" or p["kind"] == "timed":
		var n := _node(i)
		if n:
			return n.global_position
	return p["pos"]


func _physics_process(delta: float) -> void:
	time += delta
	var p := level.player
	if level.finished:
		print("FINISHED level_time=%.2f deaths=%d sparks=%d/%d" % [level.elapsed, deaths, level.sparks, level.sparks_total])
		_release_all()
		get_tree().quit()
		return
	if time > max_time or same_spot_deaths >= 12:
		print("STUCK/TIMEOUT piece=%d next=%s plan=%s pos=%s deaths=%d" % [index, _piece(index + 1)["kind"], plan,
				p.global_position, deaths])
		get_tree().quit()
		return
	if p.is_dead:
		_release_all()
		return
	var pos := p.global_position
	if was_floor and not p.is_on_floor():
		takeoff_index = index
	was_floor = p.is_on_floor()
	_update_index(pos, p.is_on_floor())
	var nxt := index + 1
	var cur_piece := _piece(index)
	var next_piece := _piece(nxt)
	var f := _fwd(nxt)
	var next_pos := _piece_pos(nxt)
	# Edges come from the static route layout (movers' start position).
	var near_edge: Vector3 = (next_piece["pos"] as Vector3) - f * float(next_piece["len"]) * 0.5
	var gap := float(next_piece["gap"])
	var rise := float(next_piece["rise"])
	var to_edge := (near_edge - pos).dot(f) - gap
	if plan_for != nxt:
		plan_for = nxt
		plan = _choose(next_piece, gap, rise)
	if Engine.get_physics_frames() % 4 == 0:
		var tinfo := ""
		var tn := _node(nxt) as TimedPlatform
		if tn:
			tinfo = " T(solid=%s t=%.2f)" % [tn.get("_solid"), float(tn.get("_time"))]
		trace.append("i=%d nxt=%s plan=%s pos=(%.1f,%.1f,%.1f) v=(%.1f,%.1f,%.1f) to_edge=%.2f floor=%s%s" % [index,
				next_piece["kind"], plan, pos.x, pos.y, pos.z, p.velocity.x, p.velocity.y, p.velocity.z, to_edge, p.is_on_floor(), tinfo])
		if trace.size() > 70:
			trace.pop_front()

	var target := next_pos
	var move := true
	# On a platform: follow its centre line towards the exit instead of cutting corners.
	if p.is_on_floor() and cur_piece["kind"] == "plat" and to_edge > 1.2:
		var c: Vector3 = _piece_pos(index)
		var along := (pos - c).dot(f)
		target = c + f * (along + 3.0)
		target.y = pos.y
	# Air control: once above a piece, brake onto it instead of overshooting.
	if not p.is_on_floor() and index > takeoff_index and _above(index, pos) and cur_piece["kind"] != "wind" 			and p.velocity.y < 3.0:
		target = _piece_pos(index)
	# Ride the trampoline on this piece when the next one is far above.
	if plan == "trampoline" and p.is_on_floor():
		var tr := _trampoline_near(_piece_pos(index), 6.0)
		if tr:
			target = tr.global_position
	# Inside a wind column (current piece): hover up, then head for the next piece.
	if cur_piece["kind"] == "wind":
		var col := _node(index) as WindColumn
		var flat_c := Vector2(pos.x - col.global_position.x, pos.z - col.global_position.z).length()
		if pos.y < col.global_position.y + col.height - 0.8 and flat_c < 2.2:
			target = col.global_position
			if flat_c < 0.4:
				move = false
	match next_piece["kind"]:
		"wind":
			var base := _node(nxt) as WindColumn
			var flat := Vector2(pos.x - base.global_position.x, pos.z - base.global_position.z).length()
			if flat < 2.2 and pos.y < base.global_position.y + base.height - 0.4 and not p.is_on_floor():
				target = base.global_position
				if flat < 0.4:
					move = false
			elif pos.y > base.global_position.y + base.height - 0.8:
				target = _piece_pos(nxt + 1)
		"mover":
			if p.is_on_floor():
				var start_pos: Vector3 = next_piece["pos"]
				var far_from_start := _piece_pos(nxt).distance_to(start_pos) > 0.8
				if to_edge < 1.0 and far_from_start:
					move = false
		"timed":
			# Rhythm chains: wait (on solid ground) for the first one to appear, then flow.
			var tp := _node(nxt) as TimedPlatform
			if p.is_on_floor() and to_edge < 1.5 and tp and cur_piece["kind"] != "timed":
				var remaining: float = tp.on_time - float(tp.get("_time"))
				if not bool(tp.get("_solid")) or remaining < tp.on_time - 0.35:
					move = false
	if cur_piece["kind"] == "mover" and p.is_on_floor():
		var mover := _node(index) as MovingPlatform
		var end_pos: Vector3 = (cur_piece["pos"] as Vector3) + mover.travel
		if mover.global_position.distance_to(end_pos) > 0.5:
			# Ride: stay centred on the platform (it carries us) until the end.
			_steer(mover.global_position - pos, Vector2(pos.x - mover.global_position.x,
					pos.z - mover.global_position.z).length() > 0.4)
			return
		elif next_piece["kind"] != "mover":
			plan = _choose(next_piece, 1.5, rise)
			if plan == "walk":
				plan = "jump"

	# Lasers: slide under when close ahead.
	for l in lasers:
		var ahead := (l.global_position - pos).dot(_fwd(index))
		var lateral := (l.global_position - pos) - _fwd(index) * ahead
		if ahead > 1.0 and ahead < 3.0 and Vector2(lateral.x, lateral.z).length() < 3.5 \
				and absf(l.global_position.y - pos.y) < 1.0 and p.is_on_floor() and not p.is_sliding:
			_tap("action")
	# Spikes: steer around those ahead on this piece.
	for sp in level.get_node("Hazards").get_children():
		if (sp.scene_file_path.ends_with("spikes.tscn") or sp is Spinner) and p.is_on_floor():
			var rel2 := (sp as Node3D).global_position - pos
			var fw := _fwd(index)
			var ahead2 := rel2.dot(fw)
			var right := fw.cross(Vector3.UP)
			var side2 := rel2.dot(right)
			if ahead2 > -1.0 and ahead2 < 4.0 and absf(side2) < 1.5 and absf(rel2.y) < 1.0:
				var away := -signf(side2) if absf(side2) > 0.05 else 1.0
				target = pos + fw * 3.0 + right * away * (1.6 - absf(side2))
	_steer(target - pos, move)
	# Hazards: hop over when one is close.
	for h in hazards:
		if _hazard_close(h, pos) and p.is_on_floor() and not p.is_sliding:
			_tap("jump")

	if not move:
		return
	if not p.is_on_floor():
		var past_edge := to_edge < -0.6 and to_edge > -(gap + 0.3)
		if plan == "dash" and past_edge and p.velocity.y < 1.0 and p.dash_available:
			_tap("action")
		elif plan == "yoyo_air" and past_edge and p.velocity.y < 0.5 and p.yoyo_charges > 0 and p.yoyo.is_ready():
			_tap("yoyo")
		elif plan == "jump" and past_edge and cur_piece["kind"] != "wind" and p.velocity.y < -2.0 				and pos.y < next_pos.y - 0.2 and p.dash_available:
			_tap("action")  # rescue dash if a plain jump falls short
		return
	# Wait on safe ground if the landing spot will be swept by a hazard.
	if to_edge < 1.0 and not _landing_safe(near_edge + f * 2.0):
		_steer(Vector3.ZERO, false)
		return
	match plan:
		"jump":
			if to_edge < 0.55:
				_tap("jump")
		"yoyo_ground":
			if to_edge < 4.4 and p.yoyo.is_ready():
				_tap("yoyo")
		"long":
			if to_edge < 3.0 and not p.is_sliding:
				_tap("action")
			if (p.is_sliding or float(p.get("_slide_cooldown")) > 0.0) and to_edge < 0.5:
				_tap("jump")
		"dash", "yoyo_air":
			if to_edge < 0.5:
				_tap("jump")


func _choose(piece: Dictionary, gap: float, rise: float) -> String:
	if piece["kind"] == "wind" or piece["kind"] == "goal":
		return "walk"
	if gap <= 0.05:
		return "walk"
	if rise > 4.5:
		return "trampoline"
	if rise > 2.4:
		return "yoyo_ground"
	if gap <= 3.8:
		return "jump"
	if gap <= 6.0:
		return "long"
	if gap <= 7.6:
		return "dash"
	return "yoyo_air"


func _update_index(pos: Vector3, on_floor: bool) -> void:
	if not on_floor:
		# Airborne: advance once we are above the next piece.
		var n := index + 1
		if n < route.size() - 1:
			var c := _piece_pos(n)
			var half := float(_piece(n)["len"]) * 0.5 + 0.4
			var rel := pos - c
			var half_w := float(_piece(n).get("wid", 3.0)) * 0.5 + 0.4
			if absf(rel.dot(_fwd(n))) < half and absf(rel.dot(_fwd(n).cross(Vector3.UP))) < half_w 					and rel.y > -0.2:
				index = n
		return
	# Prefer the piece whose footprint actually contains us.
	for i in range(maxi(index - 2, 0), mini(index + 3, route.size() - 1)):
		if _above(i, pos) and pos.y - _piece_pos(i).y < 0.6:
			index = i
			return
	var best := index
	var best_d := INF
	for i in route.size() - 1:
		var c := _piece_pos(i)
		var d := Vector2(pos.x - c.x, pos.z - c.z).length() + absf(pos.y - c.y) * 2.0
		if d < best_d and pos.y > c.y - 0.6:
			best_d = d
			best = i
	if best_d < 9.0:
		index = best


func _above(i: int, pos: Vector3) -> bool:
	var c := _piece_pos(i)
	var half := float(_piece(i)["len"]) * 0.5 + 0.3
	var half_w := float(_piece(i).get("wid", 3.0)) * 0.5 + 0.3
	var rel := pos - c
	return absf(rel.dot(_fwd(i))) < half and absf(rel.dot(_fwd(i).cross(Vector3.UP))) < half_w 			and rel.y > -0.2 and rel.y < 6.0


func _trampoline_near(center: Vector3, radius: float) -> Node3D:
	for t in trampolines:
		if t.global_position.distance_to(center) < radius:
			return t
	return null


func _hazard_close(h: Node3D, pos: Vector3) -> bool:
	if h is PatrolHazard:
		var body := h.get_node("Body") as Node3D
		return body.global_position.distance_to(pos + Vector3.UP * 0.9) < 3.1
	if h is Spinner:
		var arm := h.get_node("Arm") as Node3D
		var c := h.global_position
		var rel := pos - c
		if absf(rel.y) > 1.5 or Vector2(rel.x, rel.z).length() > 3.9:
			return false
		var now := _arm_distance(arm.global_basis.x.normalized(), c, pos)
		# Where the arm will be in 0.1 s: only hop when it is approaching.
		var ahead_dir := arm.global_basis.x.normalized().rotated(Vector3.UP,
				deg_to_rad((h as Spinner).degrees_per_second) * 0.1)
		var soon := _arm_distance(ahead_dir, c, pos)
		return now < 1.9 and soon < now
	return false


func _crossing_safe(pos: Vector3, dir: Vector3) -> bool:
	dir.y = 0.0
	if dir.length() < 0.1:
		return true
	dir = dir.normalized()
	for h in hazards:
		if not h is Spinner:
			continue
		var c := h.global_position
		var rel := c - pos
		var dist := Vector2(rel.x, rel.z).length()
		# Only decide while standing just outside the sweep with the hub ahead.
		if absf(rel.y) > 1.5 or dist < 3.75 or dist > 5.0 or rel.dot(dir) < 1.0:
			continue
		var arm := h.get_node("Arm") as Node3D
		for k in range(1, 11):
			var spot := pos + dir * float(k) * 0.8
			var t := float(k) * 0.8 / 8.0 + 0.05
			var d := arm.global_basis.x.normalized().rotated(Vector3.UP,
					deg_to_rad((h as Spinner).degrees_per_second) * t)
			if spot.distance_to(c) < 3.8 and _arm_distance(d, c, spot) < 1.0:
				return false
	return true


func _landing_safe(spot: Vector3) -> bool:
	for h in hazards:
		if h is Spinner and false:
			var c := h.global_position
			if absf(c.y - spot.y) > 1.5 or Vector2(spot.x - c.x, spot.z - c.z).length() > 4.0:
				continue
			var arm := h.get_node("Arm") as Node3D
			for t in [0.4, 0.6, 0.8, 1.0]:
				var d := arm.global_basis.x.normalized().rotated(Vector3.UP,
						deg_to_rad((h as Spinner).degrees_per_second) * t)
				if _arm_distance(d, c, spot) < 1.4:
					return false
		elif h is PatrolHazard:
			var body := h.get_node("Body") as Node3D
			if absf(body.global_position.y - spot.y) < 2.0 and 					Vector2(spot.x - body.global_position.x, spot.z - body.global_position.z).length() < 2.2:
				return false
	return true


func _arm_distance(dir: Vector3, c: Vector3, pos: Vector3) -> float:
	var rel := pos - c
	var along := clampf(rel.dot(dir), -3.3, 3.3)
	var closest := c + dir * along
	return Vector2(pos.x - closest.x, pos.z - closest.z).length()


func _steer(direction: Vector3, move: bool) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not move or flat.length() < 0.05:
		for a in ["move_forward", "move_back", "move_left", "move_right"]:
			Input.action_release(a)
		return
	var yaw := level.camera_rig.get_yaw()
	var local := flat.normalized().rotated(Vector3.UP, -yaw)
	_axis("move_left", "move_right", local.x)
	_axis("move_forward", "move_back", local.z)


func _axis(neg: String, pos_action: String, v: float) -> void:
	if v < -0.05:
		Input.action_press(neg, minf(-v * 1.4, 1.0))
		Input.action_release(pos_action)
	elif v > 0.05:
		Input.action_press(pos_action, minf(v * 1.4, 1.0))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos_action)


func _tap(action: String) -> void:
	if Input.is_action_pressed(action):
		return
	Input.action_press(action)
	var hold := 0.4 if action == "jump" else 0.1
	get_tree().create_timer(hold, false, true).timeout.connect(func(): Input.action_release(action))


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "yoyo", "action"]:
		Input.action_release(a)
