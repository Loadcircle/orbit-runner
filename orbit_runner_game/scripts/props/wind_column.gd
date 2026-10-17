@tool
class_name WindColumn
extends Node3D
## Rising air current: lifts the player while inside and restores the dash.

@export var height := 8.0:
	set(value):
		height = value
		if is_node_ready():
			_resize()
@export var lift := 62.0
@export var max_up_speed := 10.0

var _rotor: Node3D

@onready var _area: Area3D = $Area
@onready var _shape: CollisionShape3D = $Area/CollisionShape3D
@onready var _column: MeshInstance3D = $Column


func _ready() -> void:
	_rotor = $Model.find_child("Rotor", true, false) as Node3D
	_shape.shape = _shape.shape.duplicate()
	_column.mesh = _column.mesh.duplicate()
	_resize()


func _resize() -> void:
	(_shape.shape as CylinderShape3D).height = height
	_shape.position.y = height * 0.5
	(_column.mesh as CylinderMesh).height = height
	_column.position.y = height * 0.5


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _rotor:
		_rotor.rotate_object_local(Vector3.UP, 9.0 * delta)
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player and not player.is_dead:
			# Full push until 1.5 m below the top, fading out just above it, so the
			# player hovers at the column's end where the next platform is.
			var above := player.global_position.y - global_position.y
			var k := clampf((height + 1.0 - above) / 2.5, 0.0, 1.0)
			player.apply_wind(lift * k, max_up_speed, delta)
