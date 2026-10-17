class_name Player
extends CharacterBody3D
## Manually controlled 3D platformer character.
##
## Reads the shared gameplay actions (keyboard, gamepad and the touch controls
## all feed the same InputMap actions). Movement is relative to the follow
## camera yaw: forward on the stick moves along the route, sideways corrects
## the line, back moves back. There is no auto-run.

signal jumped
signal landed(impact_speed: float)
signal died
signal dashed
signal slid
signal bounced(source: StringName)
signal yoyo_thrown

@export var tuning: MovementTuning

var input_enabled := true
## Provides get_yaw(); set by the level.
var camera_rig: Node3D
var yoyo: KineticYoyo

var dash_available := true
var yoyo_charges := 1
var is_sliding := false
var is_dashing := false
var is_dead := false
var bounce_timer := 0.0
var throw_timer := 0.0
var facing := Vector3.FORWARD

var _coyote := 0.0
var _buffer := 0.0
var _slide_timer := 0.0
var _slide_cooldown := 0.0
var _slide_dir := Vector3.FORWARD
var _slide_speed := 0.0
var _dash_timer := 0.0
var _dash_dir := Vector3.FORWARD
var _jump_held_cut := false
var _boost := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _wind_frames := 0

@onready var _stand_shape: CollisionShape3D = $StandShape
@onready var _slide_shape: CollisionShape3D = $SlideShape
@onready var _ceiling: ShapeCast3D = $CeilingCheck
@onready var visual: PlayerVisual = $Visual


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	_ceiling.add_exception(self)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)
	if on_floor and not _was_on_floor:
		_on_landed()
	var wish := _wish_direction()
	var h := Vector3(velocity.x, 0.0, velocity.z)

	if is_dashing:
		_process_dash(delta)
	else:
		h = _horizontal(h, wish, on_floor, delta)
		velocity.x = h.x
		velocity.z = h.z
		_vertical(delta)
		_handle_actions(on_floor, h, wish)

	if not on_floor:
		_fall_speed = minf(_fall_speed, velocity.y)
	_was_on_floor = on_floor
	move_and_slide()
	_update_facing(delta)


# ------------------------------------------------------------------ input

func _wish_direction() -> Vector3:
	if not input_enabled:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.get_yaw() if camera_rig else 0.0
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, yaw)


func _pressed(action: StringName) -> bool:
	return input_enabled and Input.is_action_just_pressed(action)


# ------------------------------------------------------------------ movement

func _update_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote = tuning.coyote_time
		dash_available = true
		yoyo_charges = 1
		bounce_timer = 0.0
	else:
		_coyote -= delta
	_buffer = tuning.jump_buffer if _pressed(&"jump") else _buffer - delta
	_slide_cooldown -= delta
	throw_timer -= delta
	bounce_timer = maxf(bounce_timer - delta, 0.0) if velocity.y > 0.0 else 0.0
	_boost = move_toward(_boost, 0.0, tuning.boost_decay * delta)
	if _wind_frames > 0:
		_wind_frames -= 1


func _horizontal(h: Vector3, wish: Vector3, on_floor: bool, delta: float) -> Vector3:
	var max_speed := tuning.run_speed + _boost
	if is_sliding:
		_slide_timer -= delta
		_slide_speed = maxf(_slide_speed - tuning.slide_friction * delta, tuning.run_speed * 0.6)
		# Light steering while sliding.
		if wish.length() > 0.1:
			_slide_dir = _slide_dir.slerp(wish.normalized(), clampf(2.5 * delta, 0.0, 1.0)).normalized()
		if (_slide_timer <= 0.0 or not on_floor) and _can_stand():
			_end_slide()
		return _slide_dir * _slide_speed
	var has_input := wish.length() > 0.05
	var target := wish * max_speed
	var accel: float
	if on_floor:
		if has_input:
			accel = tuning.turn_acceleration if h.dot(target) < 0.0 else tuning.ground_acceleration
		else:
			accel = tuning.ground_deceleration
	else:
		accel = tuning.air_acceleration if has_input else tuning.air_deceleration
		# Keep momentum above run speed in the air (long jumps, boosts, dashes).
		var speed := h.length()
		if speed > max_speed:
			target = (wish.normalized() * speed) if has_input else h
			if has_input and h.dot(wish) < 0.0:
				target = wish * max_speed
	return h.move_toward(target, accel * delta)


func _vertical(delta: float) -> void:
	var gravity := tuning.gravity_up if velocity.y > 0.0 else tuning.gravity_down
	if _wind_frames > 0:
		gravity = tuning.gravity_up * 0.5
	velocity.y = maxf(velocity.y - gravity * delta, -tuning.max_fall_speed)
	if _jump_held_cut and velocity.y > 0.0 and not Input.is_action_pressed(&"jump"):
		velocity.y *= tuning.jump_cut
		_jump_held_cut = false
	if velocity.y <= 0.0:
		_jump_held_cut = false


func _handle_actions(on_floor: bool, h: Vector3, wish: Vector3) -> void:
	if _buffer > 0.0 and _coyote > 0.0:
		if is_sliding and _can_stand():
			_long_jump()
		elif not is_sliding:
			_jump()
	if _pressed(&"action"):
		if on_floor and not is_sliding and h.length() > 2.5 and _slide_cooldown <= 0.0:
			_start_slide(h)
		elif not on_floor and dash_available:
			_start_dash(wish)
	if _pressed(&"yoyo"):
		_try_throw_yoyo(on_floor, h)


func _jump() -> void:
	velocity.y = tuning.jump_velocity
	_buffer = 0.0
	_coyote = 0.0
	_jump_held_cut = true
	Progress.add_stat(&"jumps", 1, false)
	jumped.emit()


func _long_jump() -> void:
	_end_slide()
	velocity.y = tuning.long_jump_velocity
	var dir := _slide_dir
	velocity.x = dir.x * tuning.long_jump_speed
	velocity.z = dir.z * tuning.long_jump_speed
	_buffer = 0.0
	_coyote = 0.0
	_jump_held_cut = false
	Progress.add_stat(&"long_jumps", 1)
	jumped.emit()


func _start_slide(h: Vector3) -> void:
	is_sliding = true
	_slide_timer = tuning.slide_duration
	_slide_dir = h.normalized()
	_slide_speed = maxf(h.length(), tuning.slide_speed)
	_set_slide_shape(true)
	Progress.add_stat(&"slides", 1)
	slid.emit()


func _end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	_slide_cooldown = tuning.slide_cooldown
	_set_slide_shape(false)


func _can_stand() -> bool:
	_ceiling.force_shapecast_update()
	return not _ceiling.is_colliding()


func _set_slide_shape(sliding: bool) -> void:
	_stand_shape.set_deferred("disabled", sliding)
	_slide_shape.set_deferred("disabled", not sliding)


func _start_dash(wish: Vector3) -> void:
	dash_available = false
	is_dashing = true
	_dash_timer = tuning.dash_duration
	var dir := wish.normalized() if wish.length() > 0.2 else facing
	_dash_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	Progress.add_stat(&"dashes", 1)
	dashed.emit()


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity = _dash_dir * tuning.dash_speed + Vector3.UP * tuning.dash_lift
	if _dash_timer <= 0.0:
		is_dashing = false
		var h := _dash_dir * tuning.dash_exit_speed
		velocity = Vector3(h.x, 0.0, h.z)


func _try_throw_yoyo(on_floor: bool, h: Vector3) -> void:
	if yoyo == null or not yoyo.is_ready() or (not on_floor and yoyo_charges <= 0):
		return
	var origin := global_position + Vector3.UP * 1.0
	var target: Vector3
	if on_floor:
		target = global_position + facing * tuning.yoyo_ground_distance + Vector3.UP * 0.1
		# Stop in front of walls.
		var query := PhysicsRayQueryParameters3D.create(origin, target + Vector3.UP * 0.5, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			target = hit.position - facing * 1.3 - Vector3.UP * 0.5
	else:
		yoyo_charges -= 1
		target = global_position + h * tuning.yoyo_air_lead - Vector3.UP * tuning.yoyo_air_drop
	yoyo.throw(origin, target)
	throw_timer = 0.3
	Progress.add_stat(&"yoyo_throws", 1, false)
	yoyo_thrown.emit()


func _on_landed() -> void:
	is_dashing = false
	landed.emit(-_fall_speed)
	_fall_speed = 0.0


func _update_facing(delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if is_sliding:
		h = _slide_dir
	if h.length() > 0.6:
		facing = facing.slerp(h.normalized(), clampf(tuning.rotation_speed * delta, 0.0, 1.0)).normalized()
	if facing.length() < 0.5:
		facing = Vector3.FORWARD
	visual.global_rotation.y = atan2(-facing.x, -facing.z)


# ------------------------------------------------------------------ external forces

## Vertical launch from trampolines and the yo-yo disc. Restores air actions.
func bounce(vertical_speed: float, source: StringName) -> void:
	if is_dead:
		return
	_end_slide()
	is_dashing = false
	velocity.y = vertical_speed
	dash_available = true
	if source != &"yoyo":
		yoyo_charges = 1
	_coyote = 0.0
	_jump_held_cut = false
	bounce_timer = 0.6
	bounced.emit(source)


## Boost pads: pushes along `direction` and raises the speed cap briefly.
func apply_boost(direction: Vector3, speed: float) -> void:
	var dir := Vector3(direction.x, 0.0, direction.z).normalized()
	_boost = maxf(_boost, speed - tuning.run_speed)
	var along := Vector3(velocity.x, 0.0, velocity.z).dot(dir)
	var add := dir * maxf(speed - along, 0.0)
	velocity.x += add.x
	velocity.z += add.z
	if is_sliding:
		_slide_speed = maxf(_slide_speed, speed)


## Wind columns call this every physics frame while the player is inside.
func apply_wind(lift: float, max_up_speed: float, delta: float) -> void:
	_wind_frames = 2
	dash_available = true
	if velocity.y < max_up_speed:
		velocity.y = minf(velocity.y + lift * delta, max_up_speed)
	_jump_held_cut = false


func hurt() -> void:
	if is_dead:
		return
	is_dead = true
	_end_slide()
	is_dashing = false
	velocity = Vector3.ZERO
	Progress.add_stat(&"respawns", 1)
	died.emit()


func respawn_at(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	facing = -xform.basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.1 else Vector3.FORWARD
	velocity = Vector3.ZERO
	is_dead = false
	is_dashing = false
	_end_slide()
	dash_available = true
	yoyo_charges = 1
	_boost = 0.0
	_buffer = 0.0
	_was_on_floor = true
	reset_physics_interpolation()
	if yoyo:
		yoyo.recall_instant()


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
