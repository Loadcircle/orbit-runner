extends MeshInstance3D
## Soft circle projected straight below the player: makes landing spots easy
## to read from the follow camera regardless of the sun direction.

@export var max_distance := 40.0
@export var base_size := 0.9

var _owner_body: CollisionObject3D


func _ready() -> void:
	top_level = true
	_owner_body = get_parent() as CollisionObject3D


func _physics_process(_delta: float) -> void:
	var origin: Vector3 = get_parent().global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * max_distance, 1)
	if _owner_body:
		query.exclude = [_owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	visible = true
	var height: float = origin.y - hit.position.y
	var s := base_size * clampf(1.0 - height * 0.04, 0.45, 1.0)
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(s, 1.0, s)), hit.position + Vector3.UP * 0.04)
	transparency = clampf(height * 0.03, 0.0, 0.6)
