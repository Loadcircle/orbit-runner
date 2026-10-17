class_name MovingPlatform
extends AnimatableBody3D
## Travels back and forth between its start and start + travel with eased
## motion and short pauses at the ends. The player rides it automatically.

@export var travel := Vector3(0, 0, -6)
@export var period := 4.0
@export_range(0.0, 1.0) var phase := 0.0
@export_range(0.0, 0.45) var pause_fraction := 0.12

var _start: Vector3
var _time := 0.0


func _ready() -> void:
	sync_to_physics = true
	_start = position
	_time = phase * period


func _physics_process(delta: float) -> void:
	_time += delta
	var t := fmod(_time, period) / period
	# 0..1..0 with pauses at both ends.
	var p := pause_fraction
	var x: float
	if t < 0.5:
		x = clampf((t - p * 0.5) / (0.5 - p), 0.0, 1.0)
	else:
		x = 1.0 - clampf((t - 0.5 - p * 0.5) / (0.5 - p), 0.0, 1.0)
	x = x * x * (3.0 - 2.0 * x)
	position = _start + travel * x
