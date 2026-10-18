class_name MovementReach
extends RefCounted
## How far and how high each movement technique reaches, computed from
## MovementTuning by integrating the same equations the Player uses (60 Hz).
## The generator expresses gaps as a percentage of these values, so editing
## resources/player/movement_tuning.tres recalibrates generated levels.
##
## Technique ids (also stored as "tech" in the route metadata):
##   walk, jump, long, dash, yoyo_air, boost, yoyo_ground, trampoline, wind, ride

const STEP := 1.0 / 60.0
## Character capsule radius: landing counts once the capsule reaches the edge.
const CAPSULE_RADIUS := 0.35
## Techniques that cross horizontal gaps, weakest first.
const GAP_TECHS: Array[String] = ["jump", "long", "dash", "boost", "yoyo_air"]
## Boost pad speed used by the generator's boost motif (BoostPad.speed).
const BOOST_SPEED := 17.0
## Distance from the boost pad to the take-off edge in the boost motif.
const BOOST_RUNWAY := 3.0

var tuning: MovementTuning
var _trajectories: Dictionary = {}
var _gap_cache: Dictionary = {}


func _init(movement: MovementTuning = null) -> void:
	tuning = movement if movement else load("res://resources/player/movement_tuning.tres") as MovementTuning
	if tuning == null:
		tuning = MovementTuning.new()


## Longest edge-to-edge gap the technique clears when the landing surface is
## `rise` metres above the take-off surface (negative = below).
func max_gap(tech: String, rise := 0.0) -> float:
	# Computed from the rounded rise so the cached value depends only on the key
	# (otherwise the first caller would decide it and results would depend on
	# the order levels were generated in).
	rise = snappedf(rise, 0.01)
	var key := "%s:%.2f" % [tech, rise]
	if _gap_cache.has(key):
		return _gap_cache[key]
	var value := _distance_at_height(trajectory(tech), rise)
	if value > 0.0:
		value += CAPSULE_RADIUS
	_gap_cache[key] = value
	return value


## Highest point of the technique above the take-off surface.
func apex(tech: String) -> float:
	var best := 0.0
	for p in trajectory(tech):
		best = maxf(best, p.y)
	return best


## Highest step the technique climbs onto (apex minus a landing clearance).
func max_rise(tech: String) -> float:
	match tech:
		"walk", "ride":
			return 0.3
		"wind":
			return 12.0
	return apex(tech) - 0.25


## Seconds in the air for a jump that lands `rise` metres higher.
func airtime(tech: String, rise := 0.0) -> float:
	var path := trajectory(tech)
	var peak := false
	for i in path.size():
		if i > 0 and path[i].y < path[i - 1].y:
			peak = true
		if peak and path[i].y <= rise:
			return i * STEP
	return path.size() * STEP


## Take-off timing window in seconds for a gap: how early (jumping before the
## edge still lands) plus how late (coyote time after the edge) the press can be.
func takeoff_window(tech: String, gap: float, rise := 0.0) -> float:
	var speed := ground_speed(tech)
	var slack := maxf(max_gap(tech, rise) - gap, 0.0)
	return slack / speed + tuning.coyote_time


## Horizontal speed at take-off for each technique.
func ground_speed(tech: String) -> float:
	match tech:
		"long":
			return tuning.slide_speed
		"boost":
			return tuning.run_speed + (BOOST_SPEED - tuning.run_speed) * 0.7
	return tuning.run_speed


## Strongest technique id the gap needs (the cheapest one that clears it with
## `margin` of its reach to spare), or "" if nothing reaches.
func cheapest_tech(gap: float, rise: float, allowed: PackedStringArray, margin := 0.92) -> String:
	for tech in GAP_TECHS:
		if allowed.has(tech) and gap <= max_gap(tech, rise) * margin:
			return tech
	return ""


## Trajectory samples (x = horizontal distance, y = height) from take-off.
func trajectory(tech: String) -> PackedVector2Array:
	if _trajectories.has(tech):
		return _trajectories[tech]
	var path := PackedVector2Array()
	match tech:
		"jump":
			path = _simulate(tuning.run_speed, tuning.jump_velocity)
		"long":
			path = _simulate(tuning.long_jump_speed, tuning.long_jump_velocity)
		"dash":
			path = _simulate(tuning.run_speed, tuning.jump_velocity, "dash")
		"yoyo_air":
			path = _simulate(tuning.run_speed, tuning.jump_velocity, "yoyo")
		"boost":
			path = _simulate(ground_speed("boost"), tuning.jump_velocity, "boost")
		"yoyo_ground":
			path = _simulate(tuning.run_speed, tuning.yoyo_bounce_velocity)
		"trampoline":
			path = _simulate(tuning.run_speed, 20.0)
		"trampoline_24":
			path = _simulate(tuning.run_speed, 24.0)
		_:
			path = PackedVector2Array([Vector2.ZERO])
	_trajectories[tech] = path
	return path


func _simulate(vx: float, vy: float, extra := "") -> PackedVector2Array:
	var t := tuning
	var path := PackedVector2Array()
	var pos := Vector2.ZERO
	var boost := maxf(vx - t.run_speed, 0.0) if extra == "boost" else 0.0
	var dash_timer := -1.0
	var dashed := false
	var disc := Vector2.INF
	var disc_time := INF
	var bounced := false
	var time := 0.0
	while time < 4.0 and pos.y > -14.0:
		path.append(pos)
		time += STEP
		if dash_timer > 0.0:
			dash_timer -= STEP
			vx = t.dash_speed
			vy = t.dash_lift
			if dash_timer <= 0.0:
				vx = t.dash_exit_speed
				vy = 0.0
		else:
			var gravity := t.gravity_up if vy > 0.0 else t.gravity_down
			vy = maxf(vy - gravity * STEP, -t.max_fall_speed)
			if extra == "boost":
				boost = maxf(boost - t.boost_decay * STEP, 0.0)
				vx = maxf(t.run_speed + boost, t.run_speed)
			if extra == "dash" and not dashed and vy < 1.0:
				dashed = true
				dash_timer = t.dash_duration
			if extra == "yoyo" and disc == Vector2.INF and vy <= 0.0:
				disc = pos + Vector2(vx * t.yoyo_air_lead, -t.yoyo_air_drop)
				disc_time = time + t.yoyo_flight_time
			if disc != Vector2.INF and not bounced and time >= disc_time and absf(pos.x - disc.x) < 1.35 \
					and pos.y <= disc.y + 0.3 and pos.y >= disc.y - 0.45 and vy <= 2.0:
				bounced = true
				vy = t.yoyo_bounce_velocity
		pos += Vector2(vx, vy) * STEP
	return path


func _distance_at_height(path: PackedVector2Array, height: float) -> float:
	# Last crossing of `height` while descending: where the landing happens.
	var result := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		if a.y >= height and b.y < height:
			var k := (a.y - height) / maxf(a.y - b.y, 0.0001)
			result = lerpf(a.x, b.x, k)
	return result
