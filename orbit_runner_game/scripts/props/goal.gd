class_name Goal
extends Area3D
## End of the level.

var _done := false
var _halo: Node3D


func _ready() -> void:
	_halo = $Model.find_child("Halo", true, false) as Node3D
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _halo:
		_halo.rotate_object_local(Vector3.UP, 0.8 * delta)


func _on_body_entered(body: Node) -> void:
	if _done or not body is Player or (body as Player).is_dead:
		return
	_done = true
	if Level.current:
		Level.current.finish()
