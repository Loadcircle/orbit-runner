class_name Trampoline
extends Node3D
## Fixed impulse prop: launches the player upwards on contact from above.

@export var strength := 18.0

var _pad: Node3D

@onready var _area: Area3D = $PadArea


func _ready() -> void:
	_pad = $Model.find_child("Pad", true, false) as Node3D
	_area.body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	for body in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or player.is_dead or player.velocity.y > 1.0:
		return
	player.bounce(strength, &"trampoline")
	Progress.add_stat(&"trampolines", 1)
	AudioDirector.play_sfx(&"trampoline", 0.0, 1.0, 0.05)
	Settings.vibrate(25)
	if _pad:
		_pad.scale = Vector3(1.15, 0.4, 1.15)
		create_tween().tween_property(_pad, "scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
