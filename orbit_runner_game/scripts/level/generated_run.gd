class_name GeneratedRun
extends RefCounted
## Builds the Level for a generated mode on the device (daily challenge,
## tower, season levels) and the LevelInfo that the HUD, results and saves
## use for it.


## `key`: daily date ("YYYY-MM-DD"), tower week ("W2909") or season level ("S1-07").
static func build(spec: LevelSpec, key: String) -> Level:
	var level: Level
	if spec.mode == LevelSpec.Mode.TOWER:
		level = TowerMode.create(spec)
	else:
		var result := LevelGenerator.new().generate(spec)
		level = result["level"]
		if level == null:
			# Every attempt failed the static checks: play the first one anyway.
			level = LevelGenerator.new().build(spec, 0)
		var entry := {}
		if spec.mode == LevelSpec.Mode.DAILY:
			entry = DailyChallenge.verified_entry(key)
		elif spec.mode == LevelSpec.Mode.SEASON:
			entry = Season.entry_for_key(key)
		var meta: Dictionary = level.get_meta("generated")
		meta["verified"] = not entry.is_empty() and entry.get("route_hash", "") == meta["route_hash"]
		if meta["verified"]:
			meta["gold"] = float(entry["gold"])
			meta["silver"] = float(entry["silver"])
		level.set_meta("generated", meta)
	level.set_meta("run_key", key)
	return level


static func info_for(level: Level, spec: LevelSpec) -> LevelInfo:
	var key: String = level.get_meta("run_key", "")
	match spec.mode:
		LevelSpec.Mode.DAILY:
			return LevelGenerator.make_info(level, "daily_" + key, "MODE_DAILY")
		LevelSpec.Mode.TOWER:
			return LevelGenerator.make_info(level, "tower_" + key, "MODE_TOWER")
		LevelSpec.Mode.SEASON:
			return LevelGenerator.make_info(level, "season_" + key, "MODE_SEASON")
	return LevelGenerator.make_info(level, "gen_" + spec.key(), "MODE_GENERATED")
