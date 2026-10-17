class_name HazardArea
extends Area3D
## Touching this area sends the player back to the last checkpoint.

@export var active := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if active and monitoring:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if active and player and not player.is_dead:
		player.hurt()
