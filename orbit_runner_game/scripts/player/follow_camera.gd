class_name FollowCamera
extends Node3D
## Third-person camera behind the protagonist.
##
## The yaw follows a route direction set by the level (CameraZone areas), not
## the player's velocity, so camera-relative input stays predictable. The
## player can nudge the yaw (camera actions / touch drag); it eases back.

@export var distance := 6.6
@export var focus_height := 1.4
@export var pitch_degrees := -17.0
@export var base_fov := 70.0
@export var speed_fov := 7.0
@export var yaw_follow := 3.0
@export var horizontal_follow := 11.0
@export var vertical_follow_ground := 7.0
@export var vertical_follow_air := 2.6
@export var manual_speed := 2.2
@export var manual_limit := deg_to_rad(75.0)
@export var manual_return_delay := 1.2

var target: Player
var target_yaw := 0.0

var _yaw := 0.0
var _manual := 0.0
var _manual_idle := 0.0
var _focus := Vector3.ZERO
var _look_ahead := 0.0
var _shake := 0.0

@onready var _arm: SpringArm3D = $SpringArm
@onready var camera: Camera3D = $SpringArm/Camera


func _ready() -> void:
	top_level = true
	_arm.spring_length = distance
	_arm.rotation.x = deg_to_rad(pitch_degrees)
	camera.fov = base_fov


func get_yaw() -> float:
	return _yaw


## Places the camera behind the target immediately (spawn / respawn).
func snap(yaw: float) -> void:
	target_yaw = yaw
	_yaw = yaw
	_manual = 0.0
	if target:
		_focus = target.global_position + Vector3.UP * focus_height
	_look_ahead = 0.0
	_apply()
	reset_physics_interpolation()


func add_manual_yaw(radians: float) -> void:
	_manual = clampf(_manual + radians * float(Settings.get_value("camera_sensitivity")), -manual_limit, manual_limit)
	_manual_idle = 0.0


func shake(strength: float) -> void:
	if bool(Settings.get_value("screen_shake")):
		_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if target == null:
		return
	var axis := Input.get_axis(&"camera_left", &"camera_right")
	if absf(axis) > 0.05:
		add_manual_yaw(-axis * manual_speed * delta)
	else:
		_manual_idle += delta
		if _manual_idle > manual_return_delay:
			_manual = lerpf(_manual, 0.0, 1.0 - exp(-2.0 * delta))
	_yaw = lerp_angle(_yaw, target_yaw + _manual, 1.0 - exp(-yaw_follow * delta))

	var pos := target.get_global_transform_interpolated().origin
	var desired := pos + Vector3.UP * focus_height
	_focus.x = lerpf(_focus.x, desired.x, 1.0 - exp(-horizontal_follow * delta))
	_focus.z = lerpf(_focus.z, desired.z, 1.0 - exp(-horizontal_follow * delta))
	var vertical := vertical_follow_ground if target.is_on_floor() else vertical_follow_air
	_focus.y = lerpf(_focus.y, desired.y, 1.0 - exp(-vertical * delta))
	# Keep the protagonist inside a comfortable vertical band during big jumps.
	_focus.y = clampf(_focus.y, desired.y - 1.6, desired.y + 1.2)

	var forward := Vector3.FORWARD.rotated(Vector3.UP, _yaw)
	var along := Vector3(target.velocity.x, 0.0, target.velocity.z).dot(forward)
	_look_ahead = lerpf(_look_ahead, clampf(along * 0.16, -0.6, 2.0), 1.0 - exp(-2.5 * delta))

	var speed := target.horizontal_speed()
	var fov_target := base_fov + speed_fov * clampf((speed - target.tuning.run_speed) / 7.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-4.0 * delta))
	# Look a little further down while falling so landings stay visible.
	var pitch := pitch_degrees - clampf(-target.velocity.y * 0.5, 0.0, 9.0)
	_arm.rotation.x = lerp_angle(_arm.rotation.x, deg_to_rad(pitch), 1.0 - exp(-4.0 * delta))
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_apply()


func _apply() -> void:
	var forward := Vector3.FORWARD.rotated(Vector3.UP, _yaw)
	global_position = _focus + forward * _look_ahead
	rotation = Vector3(0.0, _yaw, 0.0)
	if _shake > 0.0:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
