extends Node
## Campaign progress, economy, cosmetics, statistics and achievements.
## Everything is stored in SaveService.section("progress") as plain JSON data.

signal achievement_unlocked(achievement: AchievementInfo)
signal cosmetic_unlocked(item: CosmeticInfo)
signal wallet_changed(sparks: int)
signal equipment_changed
signal missions_changed

enum Medal { NONE, BRONZE, SILVER, GOLD }

const LEVEL_CATALOG: LevelCatalog = preload("res://resources/levels/level_catalog.tres")
const COSMETIC_CATALOG: CosmeticCatalog = preload("res://resources/cosmetics/cosmetic_catalog.tres")
const ACHIEVEMENT_CATALOG: AchievementCatalog = preload("res://resources/achievements/achievement_catalog.tres")
const GEMS_PER_LEVEL := 3

var _data: Dictionary
var missions: MissionBoard


func _ready() -> void:
	_data = SaveService.section("progress")
	for key in ["levels", "stats", "achievements"]:
		if typeof(_data.get(key)) != TYPE_DICTIONARY:
			_data[key] = {}
	if typeof(_data.get("owned")) != TYPE_ARRAY:
		_data["owned"] = []
	if not _data.has("sparks"):
		_data["sparks"] = 0
	for item in COSMETIC_CATALOG.items:
		if item.unlock == CosmeticInfo.Unlock.DEFAULT and not owns(item.id):
			_data["owned"].append(String(item.id))
	if not _data.has("outfit"):
		_data["outfit"] = "outfit_explorer"
	if not _data.has("yoyo"):
		_data["yoyo"] = "yoyo_classic"
	for key in ["daily", "tower", "missions", "seasons"]:
		if typeof(_data.get(key)) != TYPE_DICTIONARY:
			_data[key] = {}
	missions = MissionBoard.new(_data["missions"], stat)
	refresh_missions()
	_refresh_free_unlocks()


# ------------------------------------------------------------------ levels

func levels() -> Array[LevelInfo]:
	return LEVEL_CATALOG.levels


func record(level_id: StringName) -> Dictionary:
	var levels_data: Dictionary = _data["levels"]
	var key := String(level_id)
	if typeof(levels_data.get(key)) != TYPE_DICTIONARY:
		levels_data[key] = {"completed": false, "best_time": 0.0, "gems": [false, false, false], "medal": 0,
				"best_sparks": 0}
	var rec: Dictionary = levels_data[key]
	for extra in [["flawless", false], ["all_sparks", false], ["sparks_total", 0]]:
		if not rec.has(extra[0]):
			rec[extra[0]] = extra[1]
	return rec


func is_completed(level_id: StringName) -> bool:
	var levels_data: Dictionary = _data["levels"]
	return levels_data.has(String(level_id)) and bool(record(level_id).get("completed", false))


func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var catalog := LEVEL_CATALOG.levels
	if index >= catalog.size():
		return false
	return is_completed(catalog[index - 1].id)


## First unlocked level not yet completed (or the last one when all are done).
func next_level_index() -> int:
	var catalog := LEVEL_CATALOG.levels
	for i in catalog.size():
		if not is_completed(catalog[i].id):
			return i
	return catalog.size() - 1


func medal_for_time(info: LevelInfo, time: float) -> Medal:
	if time <= info.gold_time:
		return Medal.GOLD
	if time <= info.silver_time:
		return Medal.SILVER
	return Medal.BRONZE


## Stores a finished run. `run` keys: time, gems (Array[bool]), sparks,
## sparks_total, respawns. Returns a summary used by the results screen.
func submit_run(info: LevelInfo, run: Dictionary) -> Dictionary:
	var rec := record(info.id)
	var was_completed := bool(rec["completed"])
	var time := float(run["time"])
	var best := float(rec["best_time"])
	var summary := {
		"first_clear": not was_completed,
		"new_best": best <= 0.0 or time < best,
		"previous_best": best,
		"medal": Medal.NONE,
		"medal_improved": false,
		"new_gems": 0,
		"sparks_earned": int(run["sparks"]),
		"achievements": [],
		"cosmetics": [],
	}
	rec["completed"] = true
	if summary["new_best"]:
		rec["best_time"] = time
	if not info.is_tutorial:
		var medal := medal_for_time(info, time)
		summary["medal"] = medal
		if medal > int(rec["medal"]):
			rec["medal"] = medal
			summary["medal_improved"] = was_completed
	var gems: Array = rec["gems"]
	var run_gems: Array = run["gems"]
	for i in mini(gems.size(), run_gems.size()):
		if run_gems[i] and not gems[i]:
			gems[i] = true
			summary["new_gems"] += 1
	rec["best_sparks"] = maxi(int(rec["best_sparks"]), int(run["sparks"]))
	var stars_before := mastery_count(info)
	rec["sparks_total"] = int(run["sparks_total"])
	if not info.is_tutorial:
		rec["flawless"] = bool(rec["flawless"]) or int(run["respawns"]) == 0
		rec["all_sparks"] = bool(rec["all_sparks"]) or (int(run["sparks"]) >= int(run["sparks_total"]) \
			and int(run["sparks_total"]) > 0)
		if summary["medal"] == Medal.GOLD:
			add_stat(&"gold_runs", 1, false)
	summary["mastery"] = mastery(info)
	summary["mastery_new"] = mastery_count(info) - stars_before
	add_sparks(int(run["sparks"]))
	add_stat(&"levels_finished", 1, false)
	if int(run["respawns"]) == 0 and not info.is_tutorial:
		add_stat(&"no_respawn_runs", 1, false)
	if int(run["sparks"]) >= int(run["sparks_total"]) and int(run["sparks_total"]) > 0:
		add_stat(&"all_spark_runs", 1, false)
	if info.is_tutorial:
		_data["tutorial_done"] = true
	var before_achievements: Array = _data["achievements"].keys()
	var before_owned: Array = _data["owned"].duplicate()
	check_achievements()
	_refresh_free_unlocks()
	for id in _data["achievements"].keys():
		if not id in before_achievements:
			summary["achievements"].append(ACHIEVEMENT_CATALOG.get_achievement(StringName(id)))
	for id in _data["owned"]:
		if not id in before_owned:
			summary["cosmetics"].append(COSMETIC_CATALOG.get_item(StringName(id)))
	SaveService.request_save()
	return summary


func gems_collected() -> int:
	var total := 0
	for key in _data["levels"]:
		for g in _data["levels"][key].get("gems", []):
			if g:
				total += 1
	return total


func gems_available() -> int:
	var total := 0
	for info in LEVEL_CATALOG.levels:
		if not info.is_tutorial:
			total += GEMS_PER_LEVEL
	return total


func medal_count(medal: Medal) -> int:
	var total := 0
	for info in LEVEL_CATALOG.levels:
		if not info.is_tutorial and is_completed(info.id) and int(record(info.id)["medal"]) >= medal:
			total += 1
	return total


func campaign_levels_completed() -> int:
	var total := 0
	for info in LEVEL_CATALOG.levels:
		if not info.is_tutorial and is_completed(info.id):
			total += 1
	return total


func campaign_level_count() -> int:
	var total := 0
	for info in LEVEL_CATALOG.levels:
		if not info.is_tutorial:
			total += 1
	return total


func world_completed(world_index: int) -> bool:
	var levels_in_world := LEVEL_CATALOG.levels_in_world(world_index)
	if levels_in_world.is_empty():
		return false
	for info in levels_in_world:
		if not is_completed(info.id):
			return false
	return true


# ------------------------------------------------------------------ mastery

## The four mastery stars of a level: gold, all 3 gems, all sparks in one run,
## a run without respawning.
func mastery(info: LevelInfo) -> Array[bool]:
	var rec := record(info.id)
	var gems_all := true
	for g in rec["gems"]:
		gems_all = gems_all and bool(g)
	return [int(rec["medal"]) >= Medal.GOLD, gems_all, bool(rec["all_sparks"]), bool(rec["flawless"])]


func mastery_count(info: LevelInfo) -> int:
	if info.is_tutorial:
		return 0
	var count := 0
	for star in mastery(info):
		if star:
			count += 1
	return count


## [levels with 4 stars, levels] in a world.
func world_mastery(world_index: int) -> Vector2i:
	var done := 0
	var total := 0
	for info in LEVEL_CATALOG.levels_in_world(world_index):
		if info.is_tutorial:
			continue
		total += 1
		if mastery_count(info) == 4:
			done += 1
	return Vector2i(done, maxi(total, 1))


# ------------------------------------------------------------------ daily challenge & tower

func daily_record(key: String) -> Dictionary:
	var days: Dictionary = _data["daily"]
	if typeof(days.get(key)) != TYPE_DICTIONARY:
		days[key] = {"completed": false, "best_time": 0.0, "gems": [false, false, false], "medal": 0, "attempts": 0}
	return days[key]


func submit_daily(key: String, info: LevelInfo, run: Dictionary) -> Dictionary:
	var rec := daily_record(key)
	var time := float(run["time"])
	var best := float(rec["best_time"])
	var medal := medal_for_time(info, time)
	var summary := {"first_clear": not bool(rec["completed"]), "new_best": best <= 0.0 or time < best,
			"previous_best": best, "medal": medal, "medal_improved": medal > int(rec["medal"]),
			"sparks_earned": int(run["sparks"]), "achievements": [], "cosmetics": [], "new_gems": 0}
	rec["completed"] = true
	rec["attempts"] = int(rec.get("attempts", 0)) + 1
	if summary["new_best"]:
		rec["best_time"] = time
	rec["medal"] = maxi(int(rec["medal"]), medal)
	var gems: Array = rec["gems"]
	var run_gems: Array = run["gems"]
	for i in mini(gems.size(), run_gems.size()):
		if run_gems[i] and not gems[i]:
			gems[i] = true
			summary["new_gems"] += 1
	if summary["first_clear"]:
		add_stat(&"daily_finished", 1, false)
		_update_streak(key)
	if medal == Medal.GOLD:
		add_stat(&"gold_runs", 1, false)
	_prune(_data["daily"], 30)
	add_sparks(int(run["sparks"]))
	summary["streak"] = daily_streak()
	missions_changed.emit()
	SaveService.request_save()
	return summary


func tower_record(week: String) -> Dictionary:
	var weeks: Dictionary = _data["tower"]
	if typeof(weeks.get(week)) != TYPE_DICTIONARY:
		weeks[week] = {"best_floor": 0, "best_time": 0.0, "runs": 0}
	return weeks[week]


func tower_best_ever() -> int:
	var best := int(_data.get("tower_best", 0))
	for week in _data["tower"]:
		best = maxi(best, int(_data["tower"][week].get("best_floor", 0)))
	return best


func submit_tower(week: String, floors: int, time: float) -> Dictionary:
	var rec := tower_record(week)
	var previous := int(rec["best_floor"])
	var summary := {"floors": floors, "time": time, "new_best": floors > previous, "previous_best": previous,
			"best_ever": maxi(tower_best_ever(), floors), "achievements": [], "cosmetics": []}
	rec["runs"] = int(rec.get("runs", 0)) + 1
	if floors > previous or (floors == previous and floors > 0 \
			and (float(rec["best_time"]) <= 0.0 or time < float(rec["best_time"]))):
		rec["best_floor"] = floors
		rec["best_time"] = time
	_data["tower_best"] = summary["best_ever"]
	_prune(_data["tower"], 8)
	add_stat(&"tower_floors", floors)
	missions_changed.emit()
	return summary


func daily_streak() -> int:
	return int(_data.get("daily_streak", 0))


func _update_streak(key: String) -> void:
	var last: String = _data.get("daily_last", "")
	if last != "" and DailyChallenge.day_number(last) == DailyChallenge.day_number(key) - 1:
		_data["daily_streak"] = daily_streak() + 1
	elif last != key:
		_data["daily_streak"] = 1
	_data["daily_last"] = key


## Keeps only the newest `keep` keys (date and week keys sort chronologically).
func _prune(dict: Dictionary, keep: int) -> void:
	var keys := dict.keys()
	keys.sort()
	while keys.size() > keep:
		dict.erase(keys.pop_front())


# ------------------------------------------------------------------ seasons

## Saved state of a season: {levels: {"01": record}, final_rank, rewarded}.
func season_state(season_id: String) -> Dictionary:
	var seasons: Dictionary = _data["seasons"]
	if typeof(seasons.get(season_id)) != TYPE_DICTIONARY:
		seasons[season_id] = {"levels": {}, "final_rank": 0, "final_size": 0, "rewarded": false}
	return seasons[season_id]


## Record of one season level, by run key ("S1-07").
func season_record(key: String) -> Dictionary:
	var parts := Season.parse_key(key)
	var levels: Dictionary = season_state(parts[0])["levels"]
	var slot := "%02d" % (int(parts[1]) + 1)
	if typeof(levels.get(slot)) != TYPE_DICTIONARY:
		levels[slot] = {"completed": false, "best_time": 0.0, "gems": [false, false, false], "medal": 0,
				"best_points": 0, "attempts": 0}
	return levels[slot]


func season_level_unlocked(season: Dictionary, index: int) -> bool:
	return index <= 0 or bool(season_record(Season.run_key(season, index - 1))["completed"])


## Sum of the best points and best times of the levels finished.
func season_totals(season_id: String) -> Dictionary:
	var totals := {"points": 0, "time": 0.0, "levels": 0}
	var seasons: Dictionary = _data["seasons"]
	if not seasons.has(season_id):
		return totals
	for slot in seasons[season_id]["levels"]:
		var rec: Dictionary = seasons[season_id]["levels"][slot]
		if bool(rec["completed"]):
			totals["points"] += int(rec["best_points"])
			totals["time"] += float(rec["best_time"])
			totals["levels"] += 1
	return totals


func submit_season(key: String, info: LevelInfo, run: Dictionary) -> Dictionary:
	var rec := season_record(key)
	var time := float(run["time"])
	var best := float(rec["best_time"])
	var medal := medal_for_time(info, time)
	var run_gems := 0
	for g in run["gems"]:
		if g:
			run_gems += 1
	var ratio := float(run["sparks"]) / maxf(float(run["sparks_total"]), 1.0)
	var points := SeasonScoring.points(medal, run_gems, ratio, int(run["respawns"]) == 0)
	var summary := {"first_clear": not bool(rec["completed"]), "new_best": best <= 0.0 or time < best,
			"previous_best": best, "medal": medal, "medal_improved": medal > int(rec["medal"]),
			"sparks_earned": int(run["sparks"]), "achievements": [], "cosmetics": [], "new_gems": 0,
			"season_points": points, "season_points_improved": points > int(rec["best_points"])}
	rec["completed"] = true
	rec["attempts"] = int(rec.get("attempts", 0)) + 1
	if summary["new_best"]:
		rec["best_time"] = time
	rec["medal"] = maxi(int(rec["medal"]), medal)
	rec["best_points"] = maxi(int(rec["best_points"]), points)
	var gems: Array = rec["gems"]
	var gem_list: Array = run["gems"]
	for i in mini(gems.size(), gem_list.size()):
		if gem_list[i] and not gems[i]:
			gems[i] = true
			summary["new_gems"] += 1
	if medal == Medal.GOLD:
		add_stat(&"gold_runs", 1, false)
	add_stat(&"season_levels", 1, false)
	add_sparks(int(run["sparks"]))
	missions_changed.emit()
	SaveService.request_save()
	return summary


# ------------------------------------------------------------------ missions

func refresh_missions() -> void:
	if missions.refresh(DailyChallenge.today_key(), DailyChallenge.week_key()):
		SaveService.request_save()
		missions_changed.emit()


func claim_mission(kind: String, index: int) -> int:
	var reward := missions.claim(kind, index)
	if reward > 0:
		add_sparks(reward)
		missions_changed.emit()
	return reward


# ------------------------------------------------------------------ economy & cosmetics

func sparks() -> int:
	return int(_data["sparks"])


func add_sparks(amount: int) -> void:
	_data["sparks"] = sparks() + amount
	add_stat(&"sparks_total", amount, false)
	wallet_changed.emit(sparks())
	SaveService.request_save()


func owns(id: StringName) -> bool:
	return String(id) in _data["owned"]


func can_buy(item: CosmeticInfo) -> bool:
	return item.unlock == CosmeticInfo.Unlock.SPARKS and not owns(item.id) and sparks() >= item.cost


func buy(item: CosmeticInfo) -> bool:
	if not can_buy(item):
		return false
	_data["sparks"] = sparks() - item.cost
	_grant(item)
	wallet_changed.emit(sparks())
	check_achievements()
	SaveService.request_save()
	return true


## Progress towards a locked cosmetic as [current, required].
func unlock_progress(item: CosmeticInfo) -> Vector2i:
	match item.unlock:
		CosmeticInfo.Unlock.SPARKS:
			return Vector2i(mini(sparks(), item.cost), item.cost)
		CosmeticInfo.Unlock.GEMS:
			return Vector2i(mini(gems_collected(), item.cost), item.cost)
		CosmeticInfo.Unlock.GOLD_MEDALS:
			return Vector2i(mini(medal_count(Medal.GOLD), item.cost), item.cost)
		CosmeticInfo.Unlock.ACHIEVEMENT:
			return Vector2i(1 if is_achieved(item.achievement_id) else 0, 1)
		CosmeticInfo.Unlock.MASTERY:
			return world_mastery(item.cost)
	return Vector2i(1, 1)


func equipped(kind: CosmeticInfo.Kind) -> CosmeticInfo:
	var key := "outfit" if kind == CosmeticInfo.Kind.OUTFIT else "yoyo"
	var item := COSMETIC_CATALOG.get_item(StringName(_data[key]))
	if item == null:
		item = COSMETIC_CATALOG.of_kind(kind)[0]
	return item


func equip(item: CosmeticInfo) -> void:
	if not owns(item.id):
		return
	_data["outfit" if item.kind == CosmeticInfo.Kind.OUTFIT else "yoyo"] = String(item.id)
	equipment_changed.emit()
	SaveService.request_save()


func _grant(item: CosmeticInfo) -> void:
	if owns(item.id):
		return
	_data["owned"].append(String(item.id))
	cosmetic_unlocked.emit(item)


func _refresh_free_unlocks() -> void:
	for item in COSMETIC_CATALOG.items:
		if owns(item.id) or item.unlock == CosmeticInfo.Unlock.SPARKS:
			continue
		var p := unlock_progress(item)
		if p.x >= p.y:
			_grant(item)


# ------------------------------------------------------------------ stats & achievements

func stat(name: StringName) -> int:
	return int(_data["stats"].get(String(name), 0))


func add_stat(name: StringName, amount: int = 1, check := true) -> void:
	_data["stats"][String(name)] = stat(name) + amount
	if check:
		check_achievements()
	SaveService.request_save()


func is_achieved(id: StringName) -> bool:
	return _data["achievements"].has(String(id))


func achievement_progress(a: AchievementInfo) -> Vector2i:
	var current := 0
	match a.condition:
		AchievementInfo.Condition.STAT:
			current = stat(a.stat)
		AchievementInfo.Condition.LEVELS_DONE:
			current = campaign_levels_completed()
		AchievementInfo.Condition.WORLD_DONE:
			return Vector2i(1 if world_completed(a.target) else 0, 1)
		AchievementInfo.Condition.GEMS:
			current = gems_collected()
		AchievementInfo.Condition.GOLD_MEDALS:
			current = medal_count(Medal.GOLD)
		AchievementInfo.Condition.NO_RESPAWN_RUN:
			current = stat(&"no_respawn_runs")
		AchievementInfo.Condition.ALL_SPARKS_RUN:
			current = stat(&"all_spark_runs")
		AchievementInfo.Condition.COSMETICS_OWNED:
			for id in _data["owned"]:
				var item := COSMETIC_CATALOG.get_item(StringName(id))
				if item and item.unlock != CosmeticInfo.Unlock.DEFAULT:
					current += 1
		AchievementInfo.Condition.TUTORIAL_DONE:
			return Vector2i(1 if bool(_data.get("tutorial_done", false)) else 0, 1)
	return Vector2i(mini(current, a.target), a.target)


func check_achievements() -> void:
	for a in ACHIEVEMENT_CATALOG.achievements:
		if is_achieved(a.id):
			continue
		var p := achievement_progress(a)
		if p.x >= p.y:
			_data["achievements"][String(a.id)] = Time.get_unix_time_from_system()
			if a.reward_sparks > 0:
				_data["sparks"] = sparks() + a.reward_sparks
				wallet_changed.emit(sparks())
			achievement_unlocked.emit(a)
			_refresh_free_unlocks()
	SaveService.request_save()


func achievements_unlocked_count() -> int:
	return _data["achievements"].size()


func reset_all() -> void:
	SaveService.wipe()
	ReplayStore.delete_all()
	_ready()
	Settings._ready()
	Services.reload()
	SaveService.save_now()
	equipment_changed.emit()
	wallet_changed.emit(sparks())
