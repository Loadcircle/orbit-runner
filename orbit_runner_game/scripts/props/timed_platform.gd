class_name TimedPlatform
extends StaticBody3D
## Appears and disappears on a fixed rhythm; blinks before vanishing.

@export var on_time := 2.2
@export var off_time := 1.4
@export_range(0.0, 1.0) var phase := 0.0
@export var warning := 0.6

var _time := 0.0
var _solid := true

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _model: Node3D = $Model


func _ready() -> void:
	_time = phase * (on_time + off_time)


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta, on_time + off_time)
	var solid := _time < on_time
	if solid != _solid:
		_solid = solid
		_shape.set_deferred("disabled", not solid)
		if solid:
			_model.scale = Vector3.ONE * 0.3
			create_tween().tween_property(_model, "scale", Vector3.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if solid:
		var remaining := on_time - _time
		_model.visible = remaining > warning or fmod(remaining, 0.16) > 0.07
	else:
		_model.visible = false
