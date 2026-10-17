class_name Gem
extends Area3D
## One of the three hidden gems of a level (index 0..2).

@export_range(0, 2) var index := 0

var _base_y := 0.0
var _collected := false

@onready var _model: Node3D = $Model


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = _model.position.y
	if Level.current and Level.current.gem_already_owned(index):
		# Found in an earlier run: drawn as a ghost but still collectable.
		for mesh in _model.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).transparency = 0.55


func _process(delta: float) -> void:
	_model.rotate_y(1.8 * delta)
	_model.position.y = _base_y + sin(Time.get_ticks_msec() * 0.003) * 0.15


func _on_body_entered(body: Node) -> void:
	if _collected or not body is Player:
		return
	_collected = true
	AudioDirector.play_sfx(&"gem")
	Settings.vibrate(20)
	if Level.current:
		Level.current.on_gem(index)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 1.6, 0.12)
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(queue_free)
