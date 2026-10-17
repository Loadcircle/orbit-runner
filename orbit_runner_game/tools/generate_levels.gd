extends Node
## Batch pipeline: generate -> static check -> bot profiles -> difficulty
## index -> accept / reclassify / repair / discard (service plan, phase A).
##   godot --headless --fixed-fps 60 --path . res://tools/generate_levels.tscn -- count=20 workers=4
## Options (key=value):
##   count=8          levels to produce (one seed each)
##   seed=1000        first seed (seed + i for level i)
##   difficulty=all   0..3 or "all" (rotates easy..extreme)
##   biome=rotate     isles | toyworks | ruins | rotate
##   mode=campaign    campaign | daily
##   target=45        expert seconds per level
##   attempts=10      bot attempts per noisy profile (perfect plays twice)
##   repairs=3        repair rounds before discarding
##   workers=1        parallel processes (each takes every n-th level)
##   out=res://build/generated
##   dailies=N        instead of count: validate the daily challenges of N days
##   start=YYYY-MM-DD from this date (default: today); writes
##                    resources/generator/daily_seeds.tres (seed variants are
##                    tried when a day's level is discarded)
## Output: <out>/levels/<category>/<key>.tscn for kept levels,
## <out>/reports/<seed>.json per level and <out>/summary.csv for the batch.

const BotRunner := preload("res://tools/bot/bot_runner.gd")
const BotSkills := preload("res://tools/bot/bot_skills.gd")
const LevelRating := preload("res://tools/bot/level_rating.gd")
const CATEGORY_DIRS := ["easy", "medium", "hard", "extreme"]
const CSV_HEADER := "seed,biome,requested,measured,status,index,perfect,expert,casual,novice,hardest_motif,narrowest_window_ms,expert_time,gold,silver,repairs,attempt,route_hash,seconds"

var options := {
	"count": "8", "seed": "1000", "difficulty": "all", "biome": "rotate", "mode": "campaign", "target": "45",
	"attempts": "10", "repairs": "3", "workers": "1", "worker": "-1", "out": "res://build/generated",
	"dailies": "0", "start": "",
}
const SEED_VARIANTS := 4
const VARIANT_STEP := 1000003
var runner: Node
var generator := LevelGenerator.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	var out := ProjectSettings.globalize_path(options["out"])
	DirAccess.make_dir_recursive_absolute(out + "/reports")
	if int(options["dailies"]) > 0:
		options["count"] = options["dailies"]
		if options["start"] == "":
			options["start"] = DailyChallenge.today_key()
	if int(options["workers"]) > 1 and int(options["worker"]) < 0:
		await _run_master(out)
	else:
		runner = BotRunner.new()
		add_child(runner)
		await _run_worker(out)
	get_tree().quit()


# ------------------------------------------------------------------ processes

func _run_master(out: String) -> void:
	var workers := int(options["workers"])
	var pids: Array[int] = []
	var started := Time.get_ticks_msec()
	for i in workers:
		var args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path",
				ProjectSettings.globalize_path("res://"), "res://tools/generate_levels.tscn", "--"])
		for key in options:
			if key != "worker":
				args.append("%s=%s" % [key, options[key]])
		args.append("worker=%d" % i)
		pids.append(OS.create_process(OS.get_executable_path(), args))
	print("GEN master: %d workers %s" % [workers, pids])
	while true:
		var running := 0
		for pid in pids:
			if OS.is_process_running(pid):
				running += 1
		if running == 0:
			break
		await get_tree().create_timer(1.0).timeout
	_write_summary(out)
	if int(options["dailies"]) > 0:
		_write_daily_table(out)
	print("GEN done in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))


func _run_worker(out: String) -> void:
	var workers := maxi(int(options["workers"]), 1)
	var worker := maxi(int(options["worker"]), 0)
	for i in int(options["count"]):
		if i % workers != worker:
			continue
		var report: Dictionary
		if int(options["dailies"]) > 0:
			report = await _produce_daily(i, out)
		else:
			report = await _produce(i, out, _spec_for(i))
		var file := FileAccess.open("%s/reports/%d.json" % [out, report["seed"]], FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("GEN %d %s %s -> %s index=%s" % [report["seed"], CATEGORY_DIRS[report["requested"]], report["status"],
				CATEGORY_DIRS[report.get("measured", report["requested"])], report.get("index", "-")])
	if int(options["worker"]) < 0:
		_write_summary(out)
		if int(options["dailies"]) > 0:
			_write_daily_table(out)


# ------------------------------------------------------------------ one level

func _spec_for(i: int) -> LevelSpec:
	var seed_value := int(options["seed"]) + i
	var difficulty := i % 4 if options["difficulty"] == "all" else int(options["difficulty"])
	var biome: StringName = LevelSpec.BIOMES[i % 3] if options["biome"] == "rotate" else StringName(options["biome"])
	var mode := LevelSpec.Mode.DAILY if options["mode"] == "daily" else LevelSpec.Mode.CAMPAIGN
	return LevelSpec.create(seed_value, difficulty as LevelSpec.Difficulty, biome, mode, float(options["target"]))


## Daily challenge of start + i days: first variant accepted in its category.
func _produce_daily(i: int, out: String) -> Dictionary:
	var key := DailyChallenge.key_for_day(DailyChallenge.day_number(options["start"]) + i)
	var base := DailyChallenge.spec_for(key)
	var report := {}
	for variant in SEED_VARIANTS:
		var spec := LevelSpec.create(base.seed_value + variant * VARIANT_STEP, base.difficulty, base.biome,
				LevelSpec.Mode.DAILY, base.target_seconds)
		report = await _produce(i, out, spec)
		report["date"] = key
		report["variant"] = variant
		if report["status"] == "accepted":
			break
	DirAccess.make_dir_recursive_absolute(out + "/daily")
	var file := FileAccess.open("%s/daily/%s.json" % [out, key], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "	"))
	file.close()
	return report


func _produce(_i: int, out: String, spec: LevelSpec) -> Dictionary:
	var started := Time.get_ticks_msec()
	var report := {"seed": spec.seed_value, "biome": String(spec.biome), "requested": int(spec.difficulty),
			"status": "discarded", "repairs": 0}
	var max_repairs := int(options["repairs"])
	for repair in max_repairs + 1:
		report["repairs"] = repair
		var generated := generator.generate(spec)
		if generated["level"] == null:
			report["reason"] = "static validation: %s" % [generated["validation"].get("errors", [])]
			break
		var level: Level = generated["level"]
		var meta: Dictionary = level.get_meta("generated")
		report["attempt"] = generated["attempt"]
		report["route_hash"] = meta["route_hash"]
		report["motifs"] = _motif_ids(meta)
		var packed := PackedScene.new()
		LevelBuilder.set_owners(level)
		packed.pack(level)
		var time_limit := float(meta["estimate"]) * 4.0 + 40.0
		var runs := {}
		runs["perfect"] = await runner.play_many(packed, BotSkills.get_profile("perfect"), 2, spec.seed_value, time_limit)
		var perfect_ok := true
		for r in runs["perfect"]:
			perfect_ok = perfect_ok and r["finished"]
		if perfect_ok:
			for profile in ["expert", "casual", "novice"]:
				runs[profile] = await runner.play_many(packed, BotSkills.get_profile(profile), int(options["attempts"]),
						spec.seed_value, time_limit)
		var rating := LevelRating.rate(level, generated["validation"], runs, LevelGenerator.TABLE, spec.difficulty)
		report.merge(rating, true)
		report["spec"] = spec.to_dict()
		var status := ""
		if not perfect_ok:
			status = "unbeatable"
		elif rating["requested_ok"]:
			status = "accepted"
		elif rating["measured_ok"]:
			status = "reclassified"
		if status == "accepted" or status == "reclassified":
			report["status"] = status
			var category: int = spec.difficulty if status == "accepted" else rating["measured"]
			var path := "%s/levels/%s/%s.tscn" % [options["out"], CATEGORY_DIRS[category], spec.key()]
			_apply_medals(level, rating)
			report["scene"] = path
			report["save"] = error_string(LevelBuilder.save_scene(level, path))
			level.free()
			break
		level.free()
		if repair == max_repairs:
			report["reason"] = "perfect profile cannot finish" if status == "unbeatable" else "difficulty out of range"
			break
		_repair(spec, rating, status == "unbeatable")
	report["seconds"] = snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1)
	return report


## Softens the deadliest motif (gap -10 %, platform one size up) or hardens
## the gentlest part when the level measured easier than requested.
func _repair(spec: LevelSpec, rating: Dictionary, unbeatable: bool) -> void:
	var motif := int(rating.get("hardest_motif", -1))
	var too_easy := not unbeatable and float(rating.get("index", 0.0)) < \
		LevelGenerator.TABLE.get_profile(spec.difficulty).index_range.x
	if motif < 0:
		motif = 1 + (spec.adjustments.size() % 4)
	var current: Dictionary = spec.adjustments.get(motif, {"gap": 1.0, "size": 0})
	if too_easy:
		current["gap"] = float(current.get("gap", 1.0)) * 1.1
		current["size"] = int(current.get("size", 0)) - 1
	else:
		current["gap"] = float(current.get("gap", 1.0)) * 0.9
		current["size"] = int(current.get("size", 0)) + 1
	spec.adjustments[motif] = current


func _apply_medals(level: Level, rating: Dictionary) -> void:
	var meta: Dictionary = level.get_meta("generated")
	meta["gold"] = rating["gold"]
	meta["silver"] = rating["silver"]
	meta["index"] = rating["index"]
	meta["category"] = rating["measured"]
	level.set_meta("generated", meta)


func _motif_ids(meta: Dictionary) -> Array:
	var ids := []
	for m in meta["motifs"]:
		ids.append(m["id"])
	return ids


# ------------------------------------------------------------------ summary

## Merges the accepted dailies into resources/generator/daily_seeds.tres.
func _write_daily_table(out: String) -> void:
	var dir := DirAccess.open(out + "/daily")
	if dir == null:
		return
	var path := DailyChallenge.SEEDS_PATH
	var table: DailySeedTable = load(path) if ResourceLoader.exists(path) else DailySeedTable.new()
	var added := 0
	for f in dir.get_files():
		var r: Variant = JSON.parse_string(FileAccess.get_file_as_string(out + "/daily/" + f))
		if typeof(r) != TYPE_DICTIONARY or r.get("status", "") != "accepted":
			continue
		var spec: Dictionary = r["spec"]
		table.entries[r["date"]] = {"seed": int(spec["seed"]), "difficulty": int(spec["difficulty"]),
				"biome": spec["biome"], "adjustments": spec.get("adjustments", {}), "gold": r["gold"],
				"silver": r["silver"], "index": r["index"], "route_hash": r["route_hash"]}
		added += 1
	# Keep the table small: drop days already past.
	var today := DailyChallenge.today_key()
	for key in table.entries.keys():
		if key < today:
			table.entries.erase(key)
	print("GEN daily table: %d accepted -> %s (%s)" % [added, path, error_string(ResourceSaver.save(table, path))])


func _write_summary(out: String) -> void:
	var dir := DirAccess.open(out + "/reports")
	if dir == null:
		return
	var lines := PackedStringArray([CSV_HEADER])
	var counts := {}
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var r: Variant = JSON.parse_string(FileAccess.get_file_as_string(out + "/reports/" + f))
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = r.get("success", {})
		var measured := int(r.get("measured", r["requested"]))
		lines.append(",".join(PackedStringArray([str(int(r["seed"])), r.get("biome", ""),
				CATEGORY_DIRS[int(r["requested"])], CATEGORY_DIRS[measured], r["status"], str(r.get("index", "")),
				str(s.get("perfect", "")), str(s.get("expert", "")), str(s.get("casual", "")), str(s.get("novice", "")),
				r.get("hardest_motif_id", ""), str(r.get("narrowest_window_ms", "")), str(r.get("expert_time", "")),
				str(r.get("gold", "")), str(r.get("silver", "")), str(int(r.get("repairs", 0))),
				str(int(r.get("attempt", 0))), r.get("route_hash", ""), str(r.get("seconds", ""))])))
		counts[r["status"]] = int(counts.get(r["status"], 0)) + 1
	var file := FileAccess.open(out + "/summary.csv", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("GEN summary: %s -> %s/summary.csv" % [counts, out])
