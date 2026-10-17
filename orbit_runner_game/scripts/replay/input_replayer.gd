class_name InputReplayer
extends Node
## Feeds a RunReplay's recorded input back through the InputMap actions, one
## tick at a time, and forces the camera yaw the player saw. Used to verify a
## run (the server-side anti-cheat check follows the same path).

signal finished

var level: Level
var replay: RunReplay
var tick := 0


func _ready() -> void:
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	if replay == null or level == null:
		return
	if tick >= replay.tick_count():
		_release()
		level.camera_rig.forced_yaw = NAN
		set_physics_process(false)
		finished.emit()
		return
	var offset := tick * RunReplay.TICK_BYTES
	var x := replay.ticks.decode_s16(offset) / 32767.0
	var y := replay.ticks.decode_s16(offset + 2) / 32767.0
	var buttons := replay.ticks.decode_u8(offset + 4)
	_axis(&"move_left", &"move_right", x)
	_axis(&"move_forward", &"move_back", y)
	for i in RunReplay.BUTTONS.size():
		if buttons & (1 << i):
			if not Input.is_action_pressed(RunReplay.BUTTONS[i]):
				Input.action_press(RunReplay.BUTTONS[i])
		else:
			Input.action_release(RunReplay.BUTTONS[i])
	level.camera_rig.forced_yaw = replay.ticks.decode_float(offset + 5)
	tick += 1


func _axis(negative: StringName, positive: StringName, value: float) -> void:
	if value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release() -> void:
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back"] + RunReplay.BUTTONS:
		Input.action_release(action)
