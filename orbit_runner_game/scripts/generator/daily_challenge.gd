class_name DailyChallenge
extends RefCounted
## Specs of the daily challenge and of the weekly tower, derived from the UTC
## date so every device generates the same level without a download.

const ROTATION := [LevelSpec.Difficulty.MEDIUM, LevelSpec.Difficulty.HARD, LevelSpec.Difficulty.EXTREME]
const SEEDS_PATH := "res://resources/generator/daily_seeds.tres"
const TARGET_SECONDS := 45.0
const SECONDS_PER_DAY := 86400


static func today_key() -> String:
	return Time.get_date_string_from_system(true)


static func day_number(key: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(key + "T00:00:00")) / SECONDS_PER_DAY


static func key_for_day(day: int) -> String:
	return Time.get_date_string_from_unix_time(day * SECONDS_PER_DAY)


## Spec of the daily challenge for `key` ("YYYY-MM-DD").
static func spec_for(key: String) -> LevelSpec:
	var day := day_number(key)
	var parts := key.split("-")
	var seed_value := int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])
	var spec := LevelSpec.create(seed_value, ROTATION[day % 3], LevelSpec.BIOMES[(day / 3) % 3],
			LevelSpec.Mode.DAILY, TARGET_SECONDS)
	var entry := verified_entry(key)
	if not entry.is_empty():
		spec.seed_value = int(entry["seed"])
		spec.difficulty = int(entry["difficulty"]) as LevelSpec.Difficulty
		spec.biome = StringName(entry["biome"])
		for motif in entry.get("adjustments", {}):
			spec.adjustments[int(motif)] = entry["adjustments"][motif]
	return spec


## Bot-validated data for the day, or {} when only the local seed exists.
static func verified_entry(key: String) -> Dictionary:
	if not ResourceLoader.exists(SEEDS_PATH):
		return {}
	var table := load(SEEDS_PATH) as DailySeedTable
	return table.entries.get(key, {}) if table else {}


## Monday-based week index since 1970 (1970-01-01 was a Thursday).
static func week_index(key := "") -> int:
	return (day_number(key if key != "" else today_key()) + 3) / 7


static func week_key(key := "") -> String:
	return "W%d" % week_index(key)


## The tower changes every week; everyone climbs the same floors.
static func tower_spec(week := -1) -> LevelSpec:
	if week < 0:
		week = week_index()
	return LevelSpec.create(900000 + week, LevelSpec.Difficulty.EASY, LevelSpec.BIOMES[week % 3],
			LevelSpec.Mode.TOWER, 0.0)


static func seconds_until_tomorrow() -> int:
	var now := int(Time.get_unix_time_from_system())
	return SECONDS_PER_DAY - now % SECONDS_PER_DAY
