class_name Checkpoint
extends Area3D
## Respawn point. Activating it raises and recolours the flag.

const ACTIVE_COLOR := Color(1.0, 0.6, 0.18)

var activated := false
var _flag: Node3D

@onready var _spawn: Marker3D = $Spawn
@onready var _burst: CPUParticles3D = $Burst


func _ready() -> void:
	_flag = $Model.find_child("Flag", true, false) as Node3D
	body_entered.connect(_on_body_entered)


func spawn_transform() -> Transform3D:
	return _spawn.global_transform


func _on_body_entered(body: Node) -> void:
	if activated or not body is Player or (body as Player).is_dead:
		return
	activated = true
	PlayerVisual.recolor($Model, {"M_Flag": ACTIVE_COLOR})
	if _flag:
		_flag.scale = Vector3(1.0, 0.2, 1.0)
		create_tween().tween_property(_flag, "scale", Vector3.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst.emitting = true
	AudioDirector.play_sfx(&"checkpoint")
	if Level.current:
		Level.current.on_checkpoint(self)
