class_name BoostPad
extends Area3D
## Speed strip: pushes the player along the pad's forward (-Z) direction.

@export var speed := 17.0

var _cooldown := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown -= delta


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or _cooldown > 0.0:
		return
	_cooldown = 0.3
	player.apply_boost(-global_basis.z, speed)
	Progress.add_stat(&"boosts", 1)
	AudioDirector.play_sfx(&"boost", -2.0, 1.0, 0.04)
