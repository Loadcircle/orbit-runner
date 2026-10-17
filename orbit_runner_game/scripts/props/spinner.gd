class_name Spinner
extends Node3D
## Rotating bar hazard. The GLB arm and the hazard area share one pivot.

@export var degrees_per_second := 70.0
@export var start_angle := 0.0

@onready var _arm: Node3D = $Arm


func _ready() -> void:
	_arm.rotation_degrees.y = start_angle
	var model_arm := $Model.find_child("Arm", true, false) as Node3D
	if model_arm:
		model_arm.reparent(_arm, false)
		model_arm.transform = Transform3D.IDENTITY


func _physics_process(delta: float) -> void:
	_arm.rotate_y(deg_to_rad(degrees_per_second) * delta)
