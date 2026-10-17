extends Node
## Functional check of the generated modes (not shipped).
##   godot --headless --fixed-fps 60 --path . res://tools/_modes.tscn -- [daily|tower|replay] [seconds]
## daily: the bot plays today's challenge through GeneratedRun (results + record).
## tower: the bot climbs for N seconds; prints the floors reached and built.
## replay: records a bot run of w1_l1, replays its input and compares the times.

const BotPilot := preload("res://tools/bot/bot_pilot.gd")
const BotSkills := preload("res://tools/bot/bot_skills.gd")


func _ready() -> void:
	SaveService.persist = false
	var args := OS.get_cmdline_user_args()
	var what := args[0] if args.size() > 0 else "daily"
	var seconds := float(args[1]) if args.size() > 1 else 120.0
	match what:
		"daily":
			await _daily(seconds)
		"tower":
			await _tower(seconds)
		"replay":
			await _replay(args[1] if args.size() > 1 else "res://scenes/levels/w1_l1.tscn")
	get_tree().quit()


func _daily(seconds: float) -> void:
	var key := DailyChallenge.today_key()
	var spec := DailyChallenge.spec_for(key)
	SceneRouter.current_spec = spec
	var t0 := Time.get_ticks_msec()
	var level := GeneratedRun.build(spec, key)
	print("MODES daily %s spec=%s build=%d ms hash=%s verified=%s" % [key, spec.key(), Time.get_ticks_msec() - t0,
			level.get_meta("generated")["route_hash"], level.get_meta("generated")["verified"]])
	add_child(level)
	await get_tree().physics_frame
	var result: Dictionary = await _pilot(level, seconds)
	print("MODES daily finished=%s time=%.2f info=%s gold=%.1f" % [result["finished"], result["time"], level.info.id,
			level.info.gold_time])
	await get_tree().create_timer(2.0).timeout
	print("MODES daily record=%s replay_ticks=%d samples=%d" % [Progress.daily_record(key),
			level.recorder.replay.tick_count(), level.recorder.replay.sample_count()])


func _tower(seconds: float) -> void:
	var week := DailyChallenge.week_key()
	var spec := DailyChallenge.tower_spec()
	SceneRouter.current_spec = spec
	var level := GeneratedRun.build(spec, week)
	add_child(level)
	await get_tree().physics_frame
	var result: Dictionary = await _pilot(level, seconds)
	print("MODES tower reason=%s floors_reached=%d floors_built=%d deaths=%d kill=%.1f" % [result["reason"],
			level.tower.floor_reached, level.tower.generator.floor_number, result["deaths"], level.kill_height])
	level.end_tower_run()
	await get_tree().create_timer(1.0).timeout
	print("MODES tower record=%s" % [Progress.tower_record(week)])


func _replay(path: String) -> void:
	var packed := load(path) as PackedScene
	var level := packed.instantiate() as Level
	add_child(level)
	await get_tree().physics_frame
	var result: Dictionary = await _pilot(level, 200.0)
	var replay := level.recorder.finish(level.elapsed, level.respawns)
	var bytes := replay.to_bytes()
	print("MODES replay recorded time=%.3f ticks=%d bytes=%d" % [result["time"], replay.tick_count(), bytes.size()])
	level.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var again := packed.instantiate() as Level
	add_child(again)
	var replayer := InputReplayer.new()
	replayer.level = again
	replayer.replay = RunReplay.from_bytes(bytes)
	add_child(replayer)
	var limit := replayer.replay.tick_count() + 120
	for i in limit:
		await get_tree().physics_frame
		if again.finished:
			break
	print("MODES replay replayed finished=%s time=%.3f (recorded %.3f)" % [again.finished, again.elapsed, replay.time])


func _pilot(level: Level, seconds: float) -> Dictionary:
	var pilot := BotPilot.new()
	add_child(pilot)
	pilot.setup(level, BotSkills.get_profile("perfect"), 1, seconds)
	var result: Dictionary = await pilot.run_finished
	pilot.queue_free()
	return result
