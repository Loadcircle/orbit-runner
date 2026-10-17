extends Node
## Validation bot CLI (not shipped).
##   godot --headless --fixed-fps 60 --path . res://tools/bot/run_bot.tscn -- <level> [profile] [attempts] [max_s]
## <level> is a scene path (res://scenes/levels/w1_l1.tscn) or a generated
## spec "gen:<seed>:<difficulty 0-3>:<biome>". Profiles: perfect, expert,
## casual, novice or "all". Prints "BOT {json}" per attempt and a summary.

const BotRunner := preload("res://tools/bot/bot_runner.gd")
const BotSkills := preload("res://tools/bot/bot_skills.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var target := args[0] if args.size() > 0 else "res://scenes/levels/w1_l1.tscn"
	var profile_name := args[1] if args.size() > 1 else "perfect"
	var attempts := int(args[2]) if args.size() > 2 else 1
	var max_time := float(args[3]) if args.size() > 3 else 300.0
	var packed := _load(target)
	if packed == null:
		print("BOT ERROR cannot load ", target)
		get_tree().quit(1)
		return
	var runner := BotRunner.new()
	runner.trace = args.has("trace")
	add_child(runner)
	var names: Array = BotSkills.ORDER if profile_name == "all" else [profile_name]
	for n in names:
		var profile := BotSkills.get_profile(n)
		var results: Array = await runner.play_many(packed, profile, attempts, 7, max_time)
		var wins := 0
		for r in results:
			if r["finished"]:
				wins += 1
			print("BOT ", JSON.stringify(r))
		print("SUMMARY %s %s: %d/%d finished" % [target, n, wins, results.size()])
	get_tree().quit()


func _load(target: String) -> PackedScene:
	if target.begins_with("gen:"):
		var parts := target.split(":")
		var spec := LevelSpec.create(int(parts[1]), int(parts[2]) as LevelSpec.Difficulty,
				StringName(parts[3]) if parts.size() > 3 else &"isles")
		var generated := LevelGenerator.new().generate(spec)
		if generated["level"] == null:
			return null
		var packed := PackedScene.new()
		LevelBuilder.set_owners(generated["level"])
		packed.pack(generated["level"])
		(generated["level"] as Node).free()
		return packed
	return load(target) as PackedScene
