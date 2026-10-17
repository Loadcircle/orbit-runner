@tool
class_name LaserGate
extends Node3D
## Horizontal energy beam between two posts. Slide under it, or wait for the
## off phase when it blinks (period > 0).

@export var width := 4.0:
	set(value):
		width = value
		if is_node_ready():
			_layout()
@export var beam_height := 1.05:
	set(value):
		beam_height = value
		if is_node_ready():
			_layout()
@export var period := 0.0
@export_range(0.0, 1.0) var on_fraction := 0.6
@export_range(0.0, 1.0) var phase := 0.0

var _time := 0.0

@onready var _beam: Node3D = $Beam
@onready var _beam_mesh: MeshInstance3D = $Beam/Mesh
@onready var _hazard: HazardArea = $Beam/Hazard
@onready var _hazard_shape: CollisionShape3D = $Beam/Hazard/CollisionShape3D
@onready var _left: Node3D = $LeftPost
@onready var _right: Node3D = $RightPost


func _ready() -> void:
	_beam_mesh.mesh = _beam_mesh.mesh.duplicate()
	_hazard_shape.shape = _hazard_shape.shape.duplicate()
	_layout()
	_time = phase * period


func _layout() -> void:
	var inner := maxf(width - 0.3, 0.1)
	_left.position.x = -width * 0.5
	_right.position.x = width * 0.5
	_beam.position.y = beam_height
	(_beam_mesh.mesh as BoxMesh).size = Vector3(inner, 0.12, 0.12)
	(_hazard_shape.shape as BoxShape3D).size = Vector3(inner, 0.32, 0.4)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or period <= 0.0:
		return
	_time = fmod(_time + delta, period)
	var on := _time < period * on_fraction
	var warn := on and _time > period * on_fraction - 0.4
	_hazard.active = on
	_beam_mesh.visible = on and (not warn or fmod(_time, 0.12) > 0.05)
