class_name KineticYoyo
extends Node3D
## The kinetic yo-yo: flies to a point, unfolds into a temporary bounce disc,
## then folds and returns to the owner. It is a locomotion tool only.

signal deployed
signal consumed
signal returned

enum State { HOLSTERED, FLYING, DEPLOYED, RETURNING }

const DISC_RADIUS := 1.35
const BLINK_TIME := 0.5

var owner_player: Player
var state := State.HOLSTERED

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _life := 0.0
var _trail_color := Color(0.13, 0.83, 0.93)

@onready var _yoyo_model: Node3D = $YoyoModel
@onready var _disc: Node3D = $Disc
@onready var _disc_spin: Node3D = $Disc/Model
@onready var _area: Area3D = $Disc/BounceArea
@onready var _string: MeshInstance3D = $String
@onready var _burst: CPUParticles3D = $Disc/Burst


func _ready() -> void:
	top_level = true
	_hide_all()
	_area.body_entered.connect(_on_body_entered)


func is_ready() -> bool:
	return state == State.HOLSTERED


func throw(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to
	_t = 0.0
	state = State.FLYING
	global_position = from
	_yoyo_model.visible = true
	_string.visible = true
	_set_holster_visible(false)
	AudioDirector.play_sfx(&"yoyo_throw", -3.0, 1.0, 0.05)


## Falling throw: unfolds right under the owner's feet and bounces at once.
func deploy_under(feet: Vector3) -> void:
	_from = feet
	_to = feet
	_set_holster_visible(false)
	AudioDirector.play_sfx(&"yoyo_throw", -3.0, 1.0, 0.05)
	_deploy()
	_try_bounce()


func recall_instant() -> void:
	state = State.HOLSTERED
	_hide_all()
	_set_holster_visible(true)


func apply_cosmetic(item: CosmeticInfo) -> void:
	if item == null:
		return
	_trail_color = item.trail_color
	PlayerVisual.recolor(self, item.colors)
	var mat := _string.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = item.trail_color
		mat.emission = item.trail_color


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_t += delta / owner_player.tuning.yoyo_flight_time
			var p := _from.lerp(_to, minf(_t, 1.0))
			p.y += sin(minf(_t, 1.0) * PI) * 0.4
			global_position = p
			_yoyo_model.rotate_object_local(Vector3.RIGHT, 40.0 * delta)
			if _t >= 1.0:
				_deploy()
		State.DEPLOYED:
			_life -= delta
			_disc_spin.rotate_y(6.0 * delta)
			# Blink before folding so the remaining time is readable.
			if _life < BLINK_TIME:
				_disc_spin.visible = fmod(_life, 0.12) > 0.05
			_check_overlap()
			if _life <= 0.0:
				_start_return()
		State.RETURNING:
			_t += delta / owner_player.tuning.yoyo_return_time
			var target := owner_player.global_position + Vector3.UP * 1.0
			global_position = _from.lerp(target, minf(_t * _t, 1.0))
			_yoyo_model.rotate_object_local(Vector3.RIGHT, -40.0 * delta)
			if _t >= 1.0:
				state = State.HOLSTERED
				_hide_all()
				_set_holster_visible(true)
				returned.emit()
	_update_string()


func _deploy() -> void:
	state = State.DEPLOYED
	global_position = _to
	_life = owner_player.tuning.yoyo_disc_lifetime
	_yoyo_model.visible = false
	_disc.visible = true
	_disc_spin.visible = true
	_disc.scale = Vector3.ONE * 0.1
	var tween := create_tween()
	tween.tween_property(_disc, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_area.set_deferred("monitoring", true)
	AudioDirector.play_sfx(&"yoyo_deploy", -2.0)
	deployed.emit()


func _start_return() -> void:
	state = State.RETURNING
	_from = global_position
	_t = 0.0
	_disc.visible = false
	_area.set_deferred("monitoring", false)
	_yoyo_model.visible = true
	AudioDirector.play_sfx(&"yoyo_return", -6.0)


func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		_try_bounce()


func _check_overlap() -> void:
	if _area.monitoring and _area.overlaps_body(owner_player):
		_try_bounce()


func _try_bounce() -> void:
	if state != State.DEPLOYED or owner_player.is_dead:
		return
	# Bounce when arriving from above or level with the disc, not from below.
	if owner_player.velocity.y > 2.0 or owner_player.global_position.y < global_position.y - 0.45:
		return
	owner_player.bounce(owner_player.tuning.yoyo_bounce_velocity, &"yoyo")
	Progress.add_stat(&"yoyo_bounces", 1)
	AudioDirector.play_sfx(&"bounce_yoyo", 0.0, 1.0, 0.04)
	Settings.vibrate(30)
	_burst.restart()
	_burst.emitting = true
	consumed.emit()
	_start_return()


func _hide_all() -> void:
	if not is_node_ready():
		return
	_yoyo_model.visible = false
	_disc.visible = false
	_string.visible = false
	_area.set_deferred("monitoring", false)


func _set_holster_visible(value: bool) -> void:
	if owner_player and owner_player.visual:
		owner_player.visual.set_holster_visible(value)


func _update_string() -> void:
	if state == State.HOLSTERED or owner_player == null:
		_string.visible = false
		return
	_string.visible = true
	var a := owner_player.visual.hand_position()
	var b := global_position
	var length := a.distance_to(b)
	if length < 0.05:
		_string.visible = false
		return
	var mid := (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	# String mesh is a 1 m tall cylinder: stretch its local Y axis to the length.
	var basis := Basis(side, up * length, side.cross(up).normalized())
	_string.global_transform = Transform3D(basis, mid)
