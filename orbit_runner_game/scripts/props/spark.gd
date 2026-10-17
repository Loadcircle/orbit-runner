class_name Spark
extends Area3D
## Small collectible currency. Drifts towards the player when close.

const MAGNET_RADIUS := 2.2

var _collected := false

@onready var _model: Node3D = $Model


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_model.rotation.y = randf() * TAU


func _process(delta: float) -> void:
	_model.rotate_y(3.0 * delta)
	if _collected or Level.current == null:
		return
	var player := Level.current.player
	if player and not player.is_dead:
		var to := player.global_position + Vector3.UP * 0.8 - global_position
		if to.length() < MAGNET_RADIUS:
			global_position += to.normalized() * minf(to.length(), 14.0 * delta)


func _on_body_entered(body: Node) -> void:
	if _collected or not body is Player:
		return
	_collected = true
	AudioDirector.play_sfx(&"spark", -6.0, 1.0, 0.08)
	if Level.current:
		Level.current.on_spark()
	queue_free()
