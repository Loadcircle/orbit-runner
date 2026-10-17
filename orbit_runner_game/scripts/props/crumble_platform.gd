class_name CrumblePlatform
extends StaticBody3D
## Temporary platform: shakes when stepped on, drops, and rebuilds itself.

@export var warning_time := 0.55
@export var respawn_time := 3.0

var _busy := false
var _tiles: Array[Node3D] = []
var _tile_rest: Array[Transform3D] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _sensor: Area3D = $Sensor
@onready var _model: Node3D = $Model


func _ready() -> void:
	_sensor.body_entered.connect(_on_body_entered)
	for child in _model.find_children("Tile_*", "", true, false):
		if child is Node3D:
			_tiles.append(child)
			_tile_rest.append(child.transform)


func _on_body_entered(body: Node) -> void:
	if _busy or not body is Player:
		return
	_busy = true
	AudioDirector.play_sfx(&"crumble", -4.0, 1.0, 0.05)
	var elapsed := 0.0
	while elapsed < warning_time:
		elapsed += get_physics_process_delta_time()
		for i in _tiles.size():
			var t := _tile_rest[i]
			t.origin += Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.04, 0.04))
			_tiles[i].transform = t
		await get_tree().physics_frame
	_shape.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	for i in _tiles.size():
		var rest := _tile_rest[i]
		tween.tween_property(_tiles[i], "position", rest.origin + Vector3(0, -6, 0), 0.7) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(i * 0.05)
	await tween.finished
	_model.visible = false
	await get_tree().create_timer(respawn_time, false).timeout
	for i in _tiles.size():
		_tiles[i].transform = _tile_rest[i]
	_model.visible = true
	_model.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shape.set_deferred("disabled", false)
	_busy = false
