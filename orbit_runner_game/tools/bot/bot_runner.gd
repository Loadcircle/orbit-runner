extends Node
## Plays levels with the validation bot, one attempt at a time (Input is
## global, so attempts never run in parallel inside one process).

const BotPilot := preload("res://tools/bot/bot_pilot.gd")

var trace := false


func _ready() -> void:
	# Validation runs never touch the player's save file.
	SaveService.persist = false
	Engine.max_fps = 0


## One attempt on a fresh instance of `packed`. Returns the pilot's result.
func play(packed: PackedScene, profile: Dictionary, seed_value: int, time_limit: float) -> Dictionary:
	get_tree().paused = false
	var level := packed.instantiate() as Level
	add_child(level)
	await get_tree().physics_frame
	var pilot := BotPilot.new()
	add_child(pilot)
	pilot.trace = trace
	pilot.setup(level, profile, seed_value, time_limit)
	var result: Dictionary = await pilot.run_finished
	result["profile"] = profile["name"]
	result["seed"] = seed_value
	pilot.queue_free()
	level.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return result


## `attempts` runs with one profile; seeds derive from `base_seed`.
func play_many(packed: PackedScene, profile: Dictionary, attempts: int, base_seed: int, time_limit: float) -> Array:
	var results: Array = []
	for i in attempts:
		results.append(await play(packed, profile, hash([base_seed, profile["name"], i]), time_limit))
	return results
