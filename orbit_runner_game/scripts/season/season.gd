class_name Season
extends RefCounted
## Reads the season schedule: which season is live, its levels and its dates.
## A season is a Dictionary from SeasonSchedule; run keys are "<id>-<level>".

const SCHEDULE_PATH := "res://resources/seasons/season_schedule.tres"
const TARGET_SECONDS := 40.0
## Seconds before the end when the "last day" reminder goes out.
const LAST_CALL := 86400

static var _cache: SeasonSchedule


static func schedule() -> SeasonSchedule:
	if _cache == null:
		_cache = load(SCHEDULE_PATH) as SeasonSchedule if ResourceLoader.exists(SCHEDULE_PATH) else SeasonSchedule.new()
	return _cache


static func all() -> Array:
	return schedule().seasons


static func by_id(id: String) -> Dictionary:
	for s in all():
		if s["id"] == id:
			return s
	return {}


static func starts_at(season: Dictionary) -> int:
	return int(Time.get_unix_time_from_datetime_string(String(season["start"]) + "T00:00:00"))


static func ends_at(season: Dictionary) -> int:
	return starts_at(season) + int(season.get("days", 7)) * 86400


## The live season, or {} between seasons.
static func current(now := -1) -> Dictionary:
	if now < 0:
		now = GameClock.now()
	for s in all():
		if now >= starts_at(s) and now < ends_at(s):
			return s
	return {}


## The next season to start after `now`, or {}.
static func upcoming(now := -1) -> Dictionary:
	if now < 0:
		now = GameClock.now()
	var best := {}
	for s in all():
		if starts_at(s) > now and (best.is_empty() or starts_at(s) < starts_at(best)):
			best = s
	return best


## Seasons already over, newest first.
static func finished(now := -1) -> Array:
	if now < 0:
		now = GameClock.now()
	var list := all().filter(func(s): return ends_at(s) <= now)
	list.sort_custom(func(a, b): return starts_at(a) > starts_at(b))
	return list


static func level_count(season: Dictionary) -> int:
	return (season.get("levels", []) as Array).size()


static func run_key(season: Dictionary, index: int) -> String:
	return "%s-%02d" % [season["id"], index + 1]


## [season id, level index] from a run key, or ["", -1].
static func parse_key(key: String) -> Array:
	var cut := key.rfind("-")
	if cut <= 0:
		return ["", -1]
	return [key.substr(0, cut), int(key.substr(cut + 1)) - 1]


static func entry(season: Dictionary, index: int) -> Dictionary:
	var levels: Array = season.get("levels", [])
	return levels[index] if index >= 0 and index < levels.size() else {}


## Validated entry behind a run key ({} if unknown).
static func entry_for_key(key: String) -> Dictionary:
	var parts := parse_key(key)
	return entry(by_id(parts[0]), parts[1])


static func level_spec(season: Dictionary, index: int) -> LevelSpec:
	var e := entry(season, index)
	var spec := LevelSpec.create(int(e["seed"]), int(e["difficulty"]) as LevelSpec.Difficulty, StringName(e["biome"]),
			LevelSpec.Mode.SEASON, TARGET_SECONDS)
	var adjust: Dictionary = e.get("adjustments", {})
	for motif in adjust:
		spec.adjustments[int(motif)] = adjust[motif]
	return spec


static func title(season: Dictionary) -> String:
	return TranslationServer.translate("SEASON_N") % int(season.get("number", 1))
