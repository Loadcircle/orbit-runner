class_name RunRecorder
extends Node
## Records the current run into a RunReplay: the raw gameplay input of every
## physics tick and the protagonist's pose every 0.1 s of level time.

var level: Level
var replay := RunReplay.new()
var _sample_clock := 0.0


func _ready() -> void:
	process_physics_priority = -50


func _physics_process(delta: float) -> void:
	if level == null or level.finished or level.player == null:
		return
	_record_tick()
	if level.timer_running:
		_sample_clock -= delta
		if _sample_clock <= 0.0:
			_sample_clock += RunReplay.SAMPLE_INTERVAL
			_record_sample()


## Closes the replay with the final time.
func finish(time: float, respawns: int) -> RunReplay:
	replay.time = time
	replay.respawns = respawns
	_record_sample()
	return replay


func _record_tick() -> void:
	var x := Input.get_action_raw_strength(&"move_right") - Input.get_action_raw_strength(&"move_left")
	var y := Input.get_action_raw_strength(&"move_back") - Input.get_action_raw_strength(&"move_forward")
	var buttons := 0
	for i in RunReplay.BUTTONS.size():
		if Input.is_action_pressed(RunReplay.BUTTONS[i]):
			buttons |= 1 << i
	var offset := replay.ticks.size()
	replay.ticks.resize(offset + RunReplay.TICK_BYTES)
	replay.ticks.encode_s16(offset, roundi(clampf(x, -1.0, 1.0) * 32767.0))
	replay.ticks.encode_s16(offset + 2, roundi(clampf(y, -1.0, 1.0) * 32767.0))
	replay.ticks.encode_u8(offset + 4, buttons)
	replay.ticks.encode_float(offset + 5, level.camera_rig.get_yaw())


func _record_sample() -> void:
	var p := level.player
	var pos := p.global_position
	var yaw := atan2(-p.facing.x, -p.facing.z)
	replay.samples.append_array(PackedFloat32Array([pos.x, pos.y, pos.z, yaw]))
	var state := RunReplay.ANIMATIONS.find(p.visual.current_animation())
	replay.states.append(maxi(state, 0))
