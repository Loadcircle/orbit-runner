extends Node
## Validation bot v2 (not shipped). Plays a level ONLY through the InputMap
## actions, like a person. It executes the technique annotated on each route
## piece ("tech", written by the generator; inferred for hand-made levels)
## and only decides the timing. Moving hazards, timed and moving platforms are
## predicted from their exported parameters, so the bot waits for a clear path
## instead of guessing. A skill profile (bot_skills.gd) adds human error.

signal run_finished(result: Dictionary)

const MOVES := ["move_forward", "move_back", "move_left", "move_right"]
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "yoyo", "action"]
const STEP := 1.0 / 60.0
const PREDICT_DT := 1.0 / 30.0
const PREDICT_HORIZON := 4.0
## Collision radii used by the predictor (hazard + capsule + safety margin).
const SPINNER_CLEAR := 0.9
const PATROL_CLEAR := 1.45
const SPINNER_LANE := 1.5
const ARM_LENGTH := 3.3

var level: Level
var player: Player
var skill: Dictionary = {}
var rng := RandomNumberGenerator.new()
var reach := MovementReach.new()
var max_time := 240.0
## Prints the route and the last ticks before each death (debugging).
var trace := false

var route: Array = []
var index := 0
var takeoff_index := 0
var time := 0.0
var done := false
var deaths := 0
var deaths_by_motif: Dictionary = {}
var exposure := 0.0
var landing_margins: Array[float] = []
var jumps := 0

var _spinners: Array[Dictionary] = []
var _patrols: Array[Dictionary] = []
var _lasers: Array[LaserGate] = []
var _spikes: Array[Node3D] = []
var _trampolines: Array[Node3D] = []
var _boosts: Array[Node3D] = []

var _plan_for := -1
var _timing_error := 0.0
var _air_error := 0.0
var _rescue_roll := 1.0
var _air_action_done := false
var _go_time := -1.0
var _committed_until := -1
var _lane := 0.0
var _dir_noise := 0.0
var _holds: Dictionary = {}
var _was_floor := true
var _spot_deaths: Dictionary = {}
var _wait_since := -1.0
var _trace_lines: Array[String] = []


func setup(level_node: Level, skill_profile: Dictionary, seed_value: int, time_limit: float) -> void:
	level = level_node
	player = level.player
	skill = skill_profile
	rng.seed = seed_value
	max_time = time_limit
	process_physics_priority = -100
	route = _build_route()
	_collect_hazards()
	player.died.connect(_on_died)
	player.landed.connect(_on_landed)
	if trace:
		for i in route.size():
			var p: Dictionary = route[i]
			print("  route %d %s tech=%s gap=%.1f rise=%.1f len=%.1f pos=%s yaw=%.0f" % [i, p["kind"], p["tech"],
					float(p["gap"]), float(p["rise"]), float(p["len"]), p["pos"], float(p["yaw"])])


func result(finished: bool, reason: String) -> Dictionary:
	return {"finished": finished, "reason": reason, "time": level.elapsed, "deaths": deaths,
			"deaths_by_motif": deaths_by_motif, "exposure": exposure, "landing_margins": landing_margins,
			"jumps": jumps, "sim_time": time, "piece": index, "route_size": route.size()}


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if done:
		return
	time += delta
	_tick_holds()
	if level.finished:
		_end(true, "finished")
		return
	if time > max_time:
		_end(false, "timeout")
		return
	if player.is_dead:
		_release(MOVES)
		return
	var pos := player.global_position
	var on_floor := player.is_on_floor()
	if _was_floor and not on_floor:
		takeoff_index = index
	_was_floor = on_floor
	_update_index(pos, on_floor)
	_measure_exposure(pos, delta)
	var sigma := float(skill.get("direction", 0.0))
	_dir_noise = lerpf(_dir_noise, rng.randfn(0.0, sigma * 1.6), 0.08) if sigma > 0.0 else 0.0
	_drive(pos, on_floor)
	if trace and Engine.get_physics_frames() % 3 == 0:
		var v := player.velocity
		var keys := ""
		for a in ACTIONS:
			if Input.is_action_pressed(a):
				keys += a.substr(0, 1) if not a.begins_with("move") else a.substr(5, 1)
		var extra := ""
		if _piece(index + 1)["kind"] == "timed":
			extra = " next_timed=%s cur_timed=%s" % [_timed_state(index + 1, 0.5), _timed_state(index, 0.0)]
		_trace_lines.append("t=%.2f i=%d tk=%d pos=(%.1f,%.1f,%.1f) v=(%.1f,%.1f,%.1f) floor=%s keys=%s commit=%d%s" % [time,
				index, takeoff_index, pos.x, pos.y, pos.z, v.x, v.y, v.z, on_floor, keys, _committed_until, extra])
		if _trace_lines.size() > 40:
			_trace_lines.pop_front()


func _end(finished: bool, reason: String) -> void:
	if trace and not finished:
		for line in _trace_lines:
			print("    ", line)
		print("  END %s piece=%d" % [reason, index])
	done = true
	_release(ACTIONS)
	run_finished.emit(result(finished, reason))


func _on_died() -> void:
	if trace:
		for line in _trace_lines:
			print("    ", line)
		print("  DIED piece=%d next=%s/%s pos=%s t=%.1f" % [index, _piece(index + 1)["kind"], _piece(index + 1)["tech"],
				player.global_position, time])
		_trace_lines.clear()
	deaths += 1
	var motif := int(_piece(index + 1).get("motif", _piece(index).get("motif", -1)))
	deaths_by_motif[motif] = int(deaths_by_motif.get(motif, 0)) + 1
	_spot_deaths[motif] = int(_spot_deaths.get(motif, 0)) + 1
	_plan_for = -1
	_committed_until = -1
	_go_time = -1.0
	if int(_spot_deaths[motif]) >= int(skill.get("give_up", 3)) and not done:
		_end(false, "gave_up")


func _on_landed(_impact: float) -> void:
	var piece := _piece(index)
	if piece["kind"] == "goal":
		return
	var rel := player.global_position - _piece_pos(index)
	var f := _fwd(index)
	var r := f.cross(Vector3.UP)
	var margin := minf(float(piece["len"]) * 0.5 - absf(rel.dot(f)), float(piece.get("wid", 3.0)) * 0.5 - absf(rel.dot(r)))
	if absf(rel.y) < 1.0:
		landing_margins.append(margin)


# ------------------------------------------------------------------ route

func _build_route() -> Array:
	var result_route: Array = []
	for piece in level.get_meta("route", []):
		result_route.append((piece as Dictionary).duplicate())
	var goal := level.find_child("Goal", true, false) as Node3D
	if goal:
		result_route.append({"kind": "goal", "pos": goal.global_position, "yaw": rad_to_deg(goal.global_rotation.y),
				"len": 1.5, "wid": 4.0, "gap": 0.0, "rise": 0.0, "node": level.get_path_to(goal), "tech": "walk"})
	for i in result_route.size():
		var piece: Dictionary = result_route[i]
		if String(piece.get("tech", "")) == "":
			piece["tech"] = _infer_tech(result_route, i)
	return result_route


## Technique for hand-made levels without annotations.
func _infer_tech(list: Array, i: int) -> String:
	var piece: Dictionary = list[i]
	match piece["kind"]:
		"wind":
			return "wind"
		"mover":
			return "ride"
		"goal":
			return "walk"
	if i == 0:
		return "walk"
	if list[i - 1]["kind"] == "wind":
		return "air"
	var gap := float(piece["gap"])
	var rise := float(piece["rise"])
	if gap <= 0.05:
		return "walk"
	if rise > reach.max_rise("jump") - 0.15:
		if _has_on(list[i - 1], "Trampoline"):
			return "trampoline"
		return "yoyo_ground"
	if gap <= reach.max_gap("jump", rise) * 0.9:
		return "jump"
	if _has_on(list[i - 1], "BoostPad") and gap <= reach.max_gap("boost", rise) * 0.9:
		return "boost"
	if gap <= reach.max_gap("long", rise) * 0.9 and rise < 1.0:
		return "long"
	if gap <= reach.max_gap("dash", rise) * 0.9:
		return "dash"
	return "yoyo_air"


func _has_on(piece: Dictionary, type_name: String) -> bool:
	for group in ["Elements"]:
		for child in level.get_node(group).get_children():
			var script := child.get_script() as Script
			if script and script.get_global_name() == type_name and _contains(piece, (child as Node3D).global_position, 0.5):
				return true
	return false


func _collect_hazards() -> void:
	for n in level.get_node("Hazards").get_children():
		if n is Spinner:
			_spinners.append({"node": n, "arm": n.get_node("Arm"), "piece": _piece_of(n.global_position)})
		elif n is PatrolHazard:
			_patrols.append({"node": n, "body": n.get_node("Body"), "piece": _piece_of(n.global_position)})
		elif n is LaserGate:
			_lasers.append(n)
		else:
			_spikes.append(n)
	for n in level.get_node("Elements").get_children():
		if n is Trampoline:
			_trampolines.append(n)
		elif n is BoostPad:
			_boosts.append(n)


func _piece_of(point: Vector3) -> int:
	for i in route.size():
		if _contains(route[i], point, 0.6):
			return i
	return -1


func _piece(i: int) -> Dictionary:
	return route[clampi(i, 0, route.size() - 1)]


func _node(i: int) -> Node3D:
	return level.get_node_or_null(_piece(i)["node"]) as Node3D


func _fwd(i: int) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(_piece(i)["yaw"])))


func _piece_pos(i: int) -> Vector3:
	var p := _piece(i)
	if p["kind"] in ["mover", "crumble", "timed"]:
		var n := _node(i)
		if n:
			return n.global_position
	return p["pos"]


## Near edge of a piece along its heading (movers: at their start position).
func _near_edge(i: int) -> Vector3:
	var p := _piece(i)
	return (p["pos"] as Vector3) - _fwd(i) * float(p["len"]) * 0.5


func _contains(piece: Dictionary, point: Vector3, margin: float) -> bool:
	var rel := point - (piece["pos"] as Vector3)
	var f := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(piece["yaw"])))
	var r := f.cross(Vector3.UP)
	return absf(rel.dot(f)) <= float(piece["len"]) * 0.5 + margin \
		and absf(rel.dot(r)) <= float(piece.get("wid", 3.0)) * 0.5 + margin and rel.y > -1.0 and rel.y < 2.5


func _above(i: int, pos: Vector3, margin := 0.3) -> bool:
	var c := _piece_pos(i)
	var p := _piece(i)
	var rel := pos - c
	var f := _fwd(i)
	return absf(rel.dot(f)) < float(p["len"]) * 0.5 + margin \
		and absf(rel.dot(f.cross(Vector3.UP))) < float(p.get("wid", 3.0)) * 0.5 + margin \
		and rel.y > -0.25 and rel.y < 7.0


func _update_index(pos: Vector3, on_floor: bool) -> void:
	if not on_floor:
		# Airborne: advance once we are above the next piece.
		var n := index + 1
		if n < route.size() - 1 and _above(n, pos, 0.3) and _piece(n)["kind"] != "wind":
			index = n
		return
	for i in range(maxi(index - 2, 0), mini(index + 4, route.size())):
		if _above(i, pos, 0.35) and pos.y - _piece_pos(i).y < 0.7:
			if i != index:
				index = i
			return
	# Fell somewhere else (respawn): closest piece below us.
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


# ------------------------------------------------------------------ driving

func _new_plan(nxt: int) -> void:
	_plan_for = nxt
	var sigma := float(skill.get("timing", 0.0))
	_timing_error = rng.randfn(0.0, sigma) if sigma > 0.0 else 0.0
	_air_error = rng.randfn(0.0, sigma) if sigma > 0.0 else 0.0
	_rescue_roll = rng.randf()
	_air_action_done = false
	_go_time = -1.0


func _drive(pos: Vector3, on_floor: bool) -> void:
	var nxt := index + 1
	if nxt >= route.size():
		_steer(_piece_pos(route.size() - 1) - pos, true)
		return
	if _plan_for != nxt and on_floor:
		_new_plan(nxt)
	var cur := _piece(index)
	var next_piece := _piece(nxt)
	var tech: String = next_piece["tech"]
	var f := _fwd(nxt)
	var gap := float(next_piece["gap"])
	var to_edge := (_near_edge(nxt) - pos).dot(f) - gap
	if _wind_control(pos, on_floor):
		return
	if not on_floor:
		_drive_air(pos, nxt, tech, to_edge)
		return
	_air_action_done = false
	# Riding a moving platform: stay on it until it reaches the end of its travel.
	if cur["kind"] == "mover" and _mover_x(index, 0.0) < 0.97:
		var mover_pos := _piece_pos(index)
		_steer(mover_pos - pos, Vector2(pos.x - mover_pos.x, pos.z - mover_pos.z).length() > 0.35)
		return
	if cur["kind"] == "mover" and next_piece["kind"] == "mover" and not _mover_ready(nxt, 0.45):
		var mover_pos2 := _piece_pos(index)
		_steer(mover_pos2 - pos, Vector2(pos.x - mover_pos2.x, pos.z - mover_pos2.z).length() > 0.35)
		return
	if _hazard_gate(pos, nxt, to_edge):
		return
	var speed := player.horizontal_speed()
	match tech:
		"wind", "walk", "air":
			var target := _piece_pos(nxt)
			if tech == "wind":
				target = (_node(nxt) as Node3D).global_position
			_steer_with_avoidance(pos, target, nxt)
		"trampoline":
			_ground_trampoline(pos, nxt)
		"yoyo_ground":
			_steer_with_avoidance(pos, _aim_point(nxt), nxt)
			if to_edge < 4.6 and to_edge > 3.8 and player.yoyo.is_ready() and player.facing.dot(f) > 0.95:
				_tap("yoyo", 6)
			elif to_edge <= 3.8 and player.yoyo.is_ready() and to_edge > 0.6:
				# Missed the window: back off and try again.
				_steer(-f, true)
		_:
			_ground_jump(pos, nxt, tech, to_edge, speed)
	_slide_under_lasers(pos)


func _ground_jump(pos: Vector3, nxt: int, tech: String, to_edge: float, speed: float) -> void:
	var cur := _piece(index)
	var next_piece := _piece(nxt)
	var f := _fwd(nxt)
	var rise := float(next_piece["rise"])
	var takeoff := 0.35
	var hold := 24
	match tech:
		"jump", "ride":
			takeoff = _jump_takeoff(nxt, speed)
		"long":
			takeoff = 0.45
	# Waiting pieces: only go when the platform will be there on arrival.
	var wait_ok := true
	if next_piece["kind"] == "timed":
		wait_ok = _timed_ready(nxt, reach.airtime("jump", rise) * 0.85)
	elif next_piece["kind"] == "mover":
		wait_ok = _mover_ready(nxt, reach.airtime("jump", rise) * 0.8)
	if not wait_ok:
		var can_wait: bool = cur["kind"] in ["plat", "mover"] or (cur["kind"] == "timed" and _timed_remaining(index, 0.0) > 0.5)
		if can_wait:
			if to_edge > takeoff + 0.9:
				_steer_with_avoidance(pos, _aim_point(nxt), nxt)
			else:
				_steer(Vector3.ZERO, false)
			_go_time = -1.0
			return
	elif next_piece["kind"] in ["timed", "mover"] and cur["kind"] != "timed" and _reaction_pending():
		_steer(Vector3.ZERO, false)
		return
	_steer_with_avoidance(pos, _aim_point(nxt), nxt)
	# Never take off into a laser beam that is still between us and the edge.
	if _laser_ahead(pos, maxf(to_edge, 0.0) + 0.3):
		return
	var early := maxf(speed, 3.0) * _timing_error
	match tech:
		"long":
			if not player.is_sliding and to_edge <= 2.7 + early and to_edge > 0.6 and speed > 3.0:
				_tap("action", 6)
			if player.is_sliding and to_edge <= takeoff + early:
				_press_jump(hold)
			elif not player.is_sliding and to_edge <= 0.3 + early:
				_press_jump(hold)
		_:
			if to_edge <= takeoff + early:
				_press_jump(hold)


## Distance before the edge at which a plain jump lands `depth` metres into
## the next piece (jumping later only adds distance, up to the coyote time).
func _jump_takeoff(nxt: int, speed: float) -> float:
	var next_piece := _piece(nxt)
	var rise := float(next_piece["rise"])
	var gap := float(next_piece["gap"])
	var length := float(next_piece["len"])
	var range_now := reach.max_gap("jump", rise) * clampf(speed / player.tuning.run_speed, 0.5, 1.8)
	var depth := clampf(length * 0.4, 0.9, 2.2)
	if next_piece["kind"] in ["crumble", "timed", "mover"]:
		depth = length * 0.5
	var cur_len := float(_piece(index)["len"])
	return clampf(range_now - gap - depth, 0.3, maxf(cur_len - 1.2, 0.3))


func _ground_trampoline(pos: Vector3, nxt: int) -> void:
	var t := _nearest(_trampolines, _piece_pos(index), 7.0)
	if t == null:
		_steer_with_avoidance(pos, _aim_point(nxt), nxt)
		return
	_steer(t.global_position - pos, true)


func _drive_air(pos: Vector3, nxt: int, tech: String, to_edge: float) -> void:
	var v := player.velocity
	var target_i := nxt
	# Already above the landing piece: brake onto it instead of overshooting.
	if index > takeoff_index and _piece(index)["kind"] != "wind":
		target_i = index
	var target := _landing_point(target_i)
	var next_top := _piece_pos(nxt).y
	var past_edge := to_edge < -0.3
	var late := _air_error
	if target_i == nxt and not _air_action_done:
		match tech:
			"dash", "boost":
				if tech == "dash" and past_edge and v.y < 1.0 - late * 20.0 and player.dash_available:
					_tap("action", 6)
					_air_action_done = true
			"yoyo_air":
				if past_edge and v.y <= 0.3 - late * 20.0 and player.yoyo_charges > 0 and player.yoyo.is_ready():
					_tap("yoyo", 6)
					_air_action_done = true
	# Rescue a short jump with the dash, then with the yo-yo disc.
	var short: bool = target_i == nxt and v.y < -1.5 and pos.y < next_top + 0.2 and to_edge < -0.2 \
		and (_near_edge(nxt) - pos).dot(_fwd(nxt)) > 0.2 and tech in ["jump", "long", "dash", "boost"]
	if short and _rescue_roll < float(skill.get("rescue", 1.0)):
		if player.dash_available:
			_tap("action", 6)
		elif player.yoyo_charges > 0 and player.yoyo.is_ready():
			_tap("yoyo", 6)
	# Climbing launches: do not hit the side of a high platform.
	if tech in ["trampoline", "yoyo_ground"] and target_i == nxt and pos.y < next_top + 0.3:
		var ahead := (_near_edge(nxt) - pos).dot(_fwd(nxt))
		if ahead < 1.2:
			_steer(-_fwd(nxt), v.y > 0.0)
			return
	_steer(target - pos, true)


## Wind columns: hover in the current, then leave towards the next piece.
func _wind_control(pos: Vector3, on_floor: bool) -> bool:
	for i in [index, index + 1]:
		if i >= route.size() or _piece(i)["kind"] != "wind":
			continue
		var col := _node(i) as WindColumn
		var base := col.global_position
		var flat := Vector2(pos.x - base.x, pos.z - base.z).length()
		var in_column := flat < 2.0 and pos.y > base.y - 2.5 and pos.y < base.y + col.height + 0.2
		if not in_column or (on_floor and pos.y < base.y):
			continue
		index = i
		if pos.y < base.y + col.height - 0.8:
			_steer(base - pos, flat > 0.35)
		else:
			_steer(_landing_point(i + 1) - pos, true)
		return true
	return false


# ------------------------------------------------------------------ targets

## Point a little way into a piece where a jump should land.
func _landing_point(i: int) -> Vector3:
	var p := _piece(i)
	var f := _fwd(i)
	var depth := clampf(float(p["len"]) * 0.4, 0.9, 2.5)
	if p["kind"] in ["crumble", "timed", "mover", "goal"]:
		return _piece_pos(i)
	return _piece_pos(i) - f * (float(p["len"]) * 0.5 - depth) + _lane_offset(i)


## Sideways shift that keeps the path clear of a spinner's hub on piece i.
func _lane_offset(i: int) -> Vector3:
	for sp in _spinners:
		if int(sp["piece"]) == i:
			var lane := _lane if _lane != 0.0 else SPINNER_LANE
			var c: Vector3 = (sp["node"] as Node3D).global_position
			var right := _fwd(i).cross(Vector3.UP)
			return right * ((c - _piece_pos(i)).dot(right) + lane)
	return Vector3.ZERO


## Where to run on the current piece: the next piece's line, a step beyond the edge.
func _aim_point(nxt: int) -> Vector3:
	var f := _fwd(nxt)
	var p := _piece(nxt)
	var target := _near_edge(nxt) + f * minf(float(p["len"]) * 0.5, 2.0) + _lane_offset(nxt)
	if p["kind"] in ["mover", "timed", "crumble"]:
		target = _piece_pos(nxt) if p["kind"] != "mover" else (p["pos"] as Vector3)
	return target


func _steer_with_avoidance(pos: Vector3, target: Vector3, nxt: int) -> void:
	var dir := target - pos
	var f := _fwd(nxt)
	var right := f.cross(Vector3.UP)
	# Spinner on this piece: run along a lane beside the hub (chosen by the hazard gate).
	for s in _spinners:
		if int(s["piece"]) == index:
			var c: Vector3 = (s["node"] as Node3D).global_position
			var along := (c - pos).dot(f)
			if along > -(ARM_LENGTH + 0.6) and along < ARM_LENGTH + 2.5:
				var lane := _lane if _lane != 0.0 else SPINNER_LANE
				dir = f * 2.5 + right * (c + right * lane - pos).dot(right)
	# Spikes ahead: shift sideways around them.
	for sp in _spikes:
		var rel := sp.global_position - pos
		if absf(rel.y) > 1.0:
			continue
		var ahead := rel.dot(f)
		var side := rel.dot(right)
		if ahead > -0.6 and ahead < 3.6 and absf(side) < 1.7:
			var cur := _piece(index)
			var c2 := _piece_pos(index)
			var half_w := float(cur.get("wid", 3.0)) * 0.5 - 0.45
			var lat_now := (pos - c2).dot(right)
			var away := -signf(side) if absf(side) > 0.05 else (1.0 if lat_now < 0.0 else -1.0)
			var wanted := lat_now + away * (1.75 - absf(side))
			if absf(wanted) > half_w:
				wanted = lat_now - away * (1.75 + absf(side))
			dir = f * 2.5 + right * (wanted - lat_now)
	_steer(dir, true)


# ------------------------------------------------------------------ hazards

## Spinners and patrol bots on the way: wait outside their reach until the
## predicted path to the next safe spot is clear. Returns true while waiting.
func _hazard_gate(pos: Vector3, nxt: int, to_edge: float) -> bool:
	if _committed_until >= 0:
		if index > _committed_until or (index == _committed_until and not _in_danger(pos)):
			_committed_until = -1
		else:
			_emergency_hop(pos)
			return false
	var horizon := _danger_horizon(pos, nxt)
	if horizon < 0:
		return false
	# Nowhere to wait on vanishing or moving pieces: keep going and hop the hazards.
	if _piece(index)["kind"] in ["timed", "crumble", "mover"]:
		_emergency_hop(pos)
		return false
	var entry := _distance_to_danger(pos, nxt, to_edge)
	if entry > 2.2:
		return false
	var lanes := [0.0] if not _has_spinner_up_to(horizon) else [SPINNER_LANE, -SPINNER_LANE]
	for lane in lanes:
		var path := _predict_path(pos, lane, horizon)
		if _path_clear(path):
			if not _reaction_pending():
				_lane = lane
				_committed_until = horizon
				_wait_since = -1.0
				return false
			break
	if entry < 0.2 and _in_danger(pos):
		# Caught inside the sweep: keep moving and hop if needed.
		_emergency_hop(pos)
		return false
	# No clear window for a while (a bot patrolling along the lane): go and hop over it.
	if _wait_since < 0.0:
		_wait_since = time
	elif time - _wait_since > 3.0 + float(skill.get("reaction", 0.0)):
		_wait_since = -1.0
		_lane = SPINNER_LANE
		_committed_until = horizon
		return false
	_steer(Vector3.ZERO, false)
	return true


## True while a "go" decision is still inside the profile's reaction delay.
func _reaction_pending() -> bool:
	var reaction := float(skill.get("reaction", 0.0))
	if reaction <= 0.0:
		return false
	if _go_time < 0.0:
		_go_time = time + maxf(rng.randfn(reaction, reaction * 0.25), 0.05)
	if time >= _go_time:
		_go_time = -1.0
		return false
	return true


## Last route index whose moving hazards matter for the next move (-1: none).
func _danger_horizon(pos: Vector3, nxt: int) -> int:
	var last := -1
	for i in [index, nxt, nxt + 1]:
		if i >= route.size():
			continue
		if _piece_has_moving_hazard(i, pos if i == index else Vector3.INF):
			last = i
		elif last >= 0:
			break
		elif i > index and _piece(i)["kind"] == "plat" and float(_piece(i)["len"]) >= 6.0:
			break
	return last


func _piece_has_moving_hazard(i: int, from: Vector3) -> bool:
	for s in _spinners:
		if int(s["piece"]) == i:
			if from == Vector3.INF:
				return true
			var c: Vector3 = (s["node"] as Node3D).global_position
			if (c - from).dot(_fwd(i + 1)) > -(ARM_LENGTH + 0.8):
				return true
	for p in _patrols:
		if int(p["piece"]) == i:
			if from == Vector3.INF:
				return true
			var lane_pos := _patrol_center(p)
			if (lane_pos - from).dot(_fwd(i + 1)) > -1.6:
				return true
	return false


func _has_spinner_up_to(horizon: int) -> bool:
	for s in _spinners:
		var piece := int(s["piece"])
		if piece >= index and piece <= horizon:
			return true
	return false


func _distance_to_danger(pos: Vector3, nxt: int, to_edge: float) -> float:
	var best := INF
	var f := _fwd(nxt)
	for s in _spinners:
		if int(s["piece"]) == index:
			var c: Vector3 = (s["node"] as Node3D).global_position
			best = minf(best, (c - pos).dot(f) - (ARM_LENGTH + SPINNER_CLEAR))
	for p in _patrols:
		if int(p["piece"]) == index:
			best = minf(best, (_patrol_center(p) - pos).dot(f) - PATROL_CLEAR - 0.3)
	if best == INF:
		# Danger starts on a later piece: decide before the take-off.
		best = to_edge - _jump_takeoff(nxt, player.tuning.run_speed)
	return best


func _in_danger(pos: Vector3) -> bool:
	for s in _spinners:
		var c: Vector3 = (s["node"] as Node3D).global_position
		if absf(pos.y - c.y) < 1.2 and Vector2(pos.x - c.x, pos.z - c.z).length() < ARM_LENGTH + 0.6:
			return true
	for p in _patrols:
		var body := (p["body"] as Node3D).global_position
		var a: Vector3 = (p["node"] as Node3D).global_position
		var b2: Vector3 = a + (p["node"] as PatrolHazard).travel
		var q := Geometry2D.get_closest_point_to_segment(Vector2(pos.x, pos.z), Vector2(a.x, a.z), Vector2(b2.x, b2.z))
		if absf(pos.y - a.y) < 1.5 and q.distance_to(Vector2(pos.x, pos.z)) < PATROL_CLEAR and body != Vector3.INF:
			return true
	return false


func _emergency_hop(pos: Vector3) -> void:
	if not player.is_on_floor() or player.is_sliding or _laser_ahead(pos, 2.5):
		return
	var v := player.velocity
	# Spinner arm (0.45-0.95 m high): feet clear it from ~0.1 s to ~0.7 s into a jump.
	for s in _spinners:
		var c: Vector3 = (s["node"] as Node3D).global_position
		if absf(pos.y - c.y) > 1.0:
			continue
		for dt in [0.12, 0.2, 0.28]:
			if _arm_distance(s, dt, pos + v * dt) < SPINNER_CLEAR - 0.1:
				# Only worth it if the arm is gone when we come down again.
				if _arm_distance(s, 0.7, pos + v * 0.7) > SPINNER_CLEAR:
					_press_jump(24)
				return
	# Patrol bot (sphere up to 1.65 m): feet clear it from ~0.2 s to ~0.6 s.
	for p in _patrols:
		var body_now := _patrol_body_at(p, 0.0)
		if absf(pos.y + 0.9 - body_now.y) > 1.6:
			continue
		for dt in [0.25, 0.32, 0.4]:
			var body: Vector3 = _patrol_body_at(p, dt)
			var me: Vector3 = pos + v * dt
			if Vector2(me.x - body.x, me.z - body.z).length() < PATROL_CLEAR - 0.15:
				_press_jump(24)
				return


## Simulated path from now until standing past the hazards of piece `horizon`:
## samples of [time, position, feet height above that position's ground].
func _predict_path(pos: Vector3, lane: float, horizon: int) -> Array:
	var samples: Array = []
	var t := 0.0
	var p := pos
	var speed := maxf(player.horizontal_speed(), 1.0)
	var i := index
	while t < PREDICT_HORIZON and i <= horizon:
		var nxt := i + 1
		var f := _fwd(nxt)
		var right := f.cross(Vector3.UP)
		var lane_target := lane if _piece_has_moving_hazard(i, Vector3.INF) else 0.0
		var center := _piece_pos(i) if i == index else _piece_pos(i)
		var stop_along: float
		if i == horizon:
			# _danger_exit measures from the player; the path may already be further on.
			stop_along = _danger_exit(i, f) - (p - player.global_position).dot(f)
		else:
			stop_along = (_near_edge(nxt) - p).dot(f) - float(_piece(nxt)["gap"]) - _jump_takeoff(nxt, 8.0)
		var travelled := 0.0
		while travelled < stop_along and t < PREDICT_HORIZON:
			speed = minf(speed + 38.0 * PREDICT_DT, player.tuning.run_speed)
			var step := speed * PREDICT_DT
			travelled += step
			p += f * step
			var lat := (p - center).dot(right)
			p += right * clampf(lane_target - lat, -step, step) * (1.0 if lane_target != 0.0 else 0.0)
			t += PREDICT_DT
			samples.append([t, p, 0.0])
		if i == horizon or t >= PREDICT_HORIZON:
			break
		# Jump to the next piece along the technique's trajectory.
		var tech: String = _piece(nxt)["tech"]
		if tech == "jump" and i == index and (player.is_sliding or _laser_ahead(player.global_position, 4.0)):
			tech = "long"
		var traj := reach.trajectory(tech if tech in ["jump", "long", "dash", "boost", "yoyo_air"] else "jump")
		var rise := float(_piece(nxt)["rise"])
		var gap := float(_piece(nxt)["gap"])
		var land_x := gap + _jump_takeoff(nxt, 8.0) + clampf(float(_piece(nxt)["len"]) * 0.4, 0.9, 2.2)
		if tech == "long":
			land_x = reach.max_gap("long", rise) + 0.3
		var start := p
		var k := 0
		var peaked := false
		while k < traj.size():
			var sample := traj[k]
			if k > 0 and sample.y < traj[k - 1].y:
				peaked = true
			if peaked and sample.y <= rise:
				break
			if sample.x >= land_x and sample.y <= rise + 0.3 and peaked:
				break
			var q := start + f * minf(sample.x, land_x) + Vector3.UP * sample.y
			t += STEP
			if k % 2 == 0:
				samples.append([t, q, sample.y if sample.x < gap * 0.5 else sample.y - rise])
			k += 1
		p = start + f * land_x + Vector3.UP * rise
		i = nxt
	return samples


## Distance along `f` from the current path point to beyond the hazards of piece i.
func _danger_exit(i: int, f: Vector3) -> float:
	var pos := player.global_position
	var best := 0.0
	for s in _spinners:
		if int(s["piece"]) == i:
			var c: Vector3 = (s["node"] as Node3D).global_position
			best = maxf(best, (c - pos).dot(f) + ARM_LENGTH + SPINNER_CLEAR + 0.3)
	for p in _patrols:
		if int(p["piece"]) == i:
			if _patrol_along_route(p, f):
				# Patrols along the lane cannot be outrun: land safely, then hop over them.
				best = maxf(best, (_near_edge(i) - pos).dot(f) + 2.5)
			else:
				best = maxf(best, (_patrol_center(p) - pos).dot(f) + PATROL_CLEAR + 0.4)
	if i != index:
		# Measured from the path's arrival on that piece: approximate with its far side.
		best = maxf(best, 0.0)
	return best


func _path_clear(path: Array) -> bool:
	for sample in path:
		var t: float = sample[0]
		var q: Vector3 = sample[1]
		var h: float = sample[2]
		for s in _spinners:
			var c: Vector3 = (s["node"] as Node3D).global_position
			if absf(q.y - h - c.y) > 1.2 or h > 0.95:
				continue
			if _arm_distance(s, t, q) < SPINNER_CLEAR:
				return false
		for p in _patrols:
			var body := _patrol_body_at(p, t)
			if h > 1.6 or absf(q.y - h - ((p["node"] as Node3D).global_position.y)) > 1.2:
				continue
			if Vector2(q.x - body.x, q.z - body.z).length() < PATROL_CLEAR:
				if trace and Engine.get_physics_frames() % 30 == 0:
					print("    blocked by patrol t=%.2f q=%s body=%s h=%.2f" % [t, q, body, h])
				return false
	return true


func _arm_distance(s: Dictionary, dt: float, q: Vector3) -> float:
	var spinner := s["node"] as Spinner
	var arm := s["arm"] as Node3D
	var c := spinner.global_position
	var d := arm.global_basis.x.normalized().rotated(Vector3.UP, deg_to_rad(spinner.degrees_per_second) * dt)
	var rel := q - c
	var along := clampf(rel.dot(d), -ARM_LENGTH, ARM_LENGTH)
	var closest := c + d * along
	return Vector2(q.x - closest.x, q.z - closest.z).length()


func _patrol_body_at(p: Dictionary, dt: float) -> Vector3:
	var patrol := p["node"] as PatrolHazard
	var length := maxf(patrol.travel.length(), 0.01)
	var t := fmod(float(patrol.get("_t")) + dt * patrol.speed / (length * 2.0), 1.0)
	var x := 1.0 - absf(1.0 - t * 2.0)
	x = x * x * (3.0 - 2.0 * x)
	var start: Vector3 = patrol.get("_start")
	return patrol.global_position + start + patrol.travel * x


func _patrol_along_route(p: Dictionary, f: Vector3) -> bool:
	var travel := (p["node"] as PatrolHazard).travel
	return absf(travel.normalized().dot(f)) > 0.7


func _patrol_center(p: Dictionary) -> Vector3:
	var patrol := p["node"] as PatrolHazard
	return patrol.global_position + patrol.travel * 0.5


# ------------------------------------------------------------------ timed and moving platforms

func _timed_state(i: int, dt: float) -> Vector2:
	# x = solid (1/0), y = seconds of solid time left at now + dt.
	var tp := _node(i) as TimedPlatform
	if tp == null:
		return Vector2(1, 9)
	var cycle := tp.on_time + tp.off_time
	var t := fmod(float(tp.get("_time")) + dt, cycle)
	if t < tp.on_time:
		return Vector2(1, tp.on_time - t)
	return Vector2(0, 0)


func _timed_ready(i: int, arrival: float) -> bool:
	var state := _timed_state(i, arrival)
	return state.x > 0.5 and state.y >= 0.45


func _timed_remaining(i: int, dt: float) -> float:
	return _timed_state(i, dt).y


func _mover_x(i: int, dt: float) -> float:
	var mover := _node(i) as MovingPlatform
	if mover == null:
		return 1.0
	var t := fmod(float(mover.get("_time")) + dt, mover.period) / mover.period
	var p := mover.pause_fraction
	var x: float
	if t < 0.5:
		x = clampf((t - p * 0.5) / (0.5 - p), 0.0, 1.0)
	else:
		x = 1.0 - clampf((t - 0.5 - p * 0.5) / (0.5 - p), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The mover will be waiting at its start when we land on it.
func _mover_ready(i: int, arrival: float) -> bool:
	return _mover_x(i, arrival) < 0.04 and _mover_x(i, arrival + 0.15) < 0.25


# ------------------------------------------------------------------ lasers and metrics

func _slide_under_lasers(pos: Vector3) -> void:
	if not player.is_on_floor() or player.is_sliding or player.horizontal_speed() < 3.0:
		return
	var f := _fwd(index + 1)
	for l in _lasers:
		var rel := l.global_position - pos
		var ahead := rel.dot(f)
		var lateral := (rel - f * ahead)
		# Late enough that one slide (~5 m) also clears a second laser 2.5 m further on.
		if ahead > 0.5 and ahead < 1.4 and Vector2(lateral.x, lateral.z).length() < l.width * 0.5 + 0.5 \
				and absf(rel.y) < 1.0:
			_tap("action", 6)
			return


func _laser_ahead(pos: Vector3, distance: float) -> bool:
	var f := _fwd(index + 1)
	for l in _lasers:
		var rel := l.global_position - pos
		var ahead := rel.dot(f)
		if ahead > -0.5 and ahead < distance and absf(rel.y) < 1.0 				and Vector2(rel.x - f.x * ahead, rel.z - f.z * ahead).length() < l.width * 0.5 + 0.5:
			return true
	return false


func _measure_exposure(pos: Vector3, delta: float) -> void:
	for s in _spinners:
		var c: Vector3 = (s["node"] as Node3D).global_position
		if absf(pos.y - c.y) < 1.2 and _arm_distance(s, 0.0, pos) < 1.6:
			exposure += delta
			return
	for p in _patrols:
		var body := (p["body"] as Node3D).global_position
		if pos.distance_to(body) < 2.2:
			exposure += delta
			return
	for l in _lasers:
		if pos.distance_to(l.global_position) < 1.5 and bool((l.get_node("Beam/Hazard") as HazardArea).active):
			exposure += delta
			return


# ------------------------------------------------------------------ input

func _steer(direction: Vector3, move: bool) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not move or flat.length() < 0.05:
		_release(MOVES)
		return
	flat = flat.normalized().rotated(Vector3.UP, deg_to_rad(_dir_noise))
	var yaw := level.camera_rig.get_yaw()
	var local := flat.rotated(Vector3.UP, -yaw)
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


func _press_jump(hold_ticks: int) -> void:
	if Input.is_action_pressed("jump"):
		return
	jumps += 1
	_tap("jump", hold_ticks)


func _tap(action: String, ticks: int) -> void:
	if Input.is_action_pressed(action):
		return
	Input.action_press(action)
	_holds[action] = ticks


func _tick_holds() -> void:
	for action in _holds.keys():
		_holds[action] -= 1
		if _holds[action] <= 0:
			Input.action_release(action)
			_holds.erase(action)


func _release(actions: Array) -> void:
	for a in actions:
		Input.action_release(a)
		_holds.erase(a)


func _nearest(list: Array, center: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for n in list:
		var d := (n as Node3D).global_position.distance_to(center)
		if d < best_d:
			best_d = d
			best = n
	return best
