class_name PatrolHazard
extends Node3D
## Hazard that patrols between its start and start + travel.

@export var travel := Vector3(6, 0, 0)
@export var speed := 3.0
@export_range(0.0, 1.0) var phase := 0.0

var _start: Vector3
var _t := 0.0

@onready var _body: Node3D = $Body


func _ready() -> void:
	_start = _body.position
	_t = phase


func _physics_process(delta: float) -> void:
	var length := maxf(travel.length(), 0.01)
	_t = fmod(_t + delta * speed / (length * 2.0), 1.0)
	var x := 1.0 - absf(1.0 - _t * 2.0)
	x = x * x * (3.0 - 2.0 * x)
	_body.position = _start + travel * x + Vector3.UP * sin(Time.get_ticks_msec() * 0.006) * 0.12
	_body.rotate_y(2.5 * delta)
