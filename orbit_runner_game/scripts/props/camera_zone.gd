class_name CameraZone
extends Area3D
## While the player is inside, the follow camera turns to face `yaw_degrees`
## (0 = looking towards -Z). Lets routes turn without disorienting input.

@export var yaw_degrees := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player and Level.current:
		Level.current.set_camera_yaw(deg_to_rad(yaw_degrees))
