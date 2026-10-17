extends Node
## Bootstrap generator for the cosmetic and achievement catalogs and the
## level generator's difficulty table.
##   godot --headless --path . res://tools/build_data.tscn
## The generated .tres files are the editable source afterwards; re-running
## this script overwrites them.

const OUTFIT_KEYS := ["M_Jacket", "M_Accent", "M_Pants", "M_Hair", "M_Teal"]
const YOYO_KEYS := ["M_Yoyo", "M_YoyoAccent", "M_DiscCyan"]


func _ready() -> void:
	_build_cosmetics()
	_build_achievements()
	_build_difficulty_table()
	print("build_data: done")
	get_tree().quit()


func _outfit(id: String, unlock: int, cost: int, colors: Array, achievement := "") -> CosmeticInfo:
	var c := CosmeticInfo.new()
	c.id = StringName(id)
	c.kind = CosmeticInfo.Kind.OUTFIT
	c.title_key = "COS_" + id.to_upper()
	c.unlock = unlock
	c.cost = cost
	c.achievement_id = StringName(achievement)
	var dict := {}
	for i in OUTFIT_KEYS.size():
		dict[OUTFIT_KEYS[i]] = Color(colors[i])
	c.colors = dict
	return c


func _yoyo(id: String, unlock: int, cost: int, colors: Array, trail: String, achievement := "") -> CosmeticInfo:
	var c := CosmeticInfo.new()
	c.id = StringName(id)
	c.kind = CosmeticInfo.Kind.YOYO
	c.title_key = "COS_" + id.to_upper()
	c.unlock = unlock
	c.cost = cost
	c.achievement_id = StringName(achievement)
	var dict := {}
	for i in YOYO_KEYS.size():
		dict[YOYO_KEYS[i]] = Color(colors[i])
	c.colors = dict
	c.trail_color = Color(trail)
	return c


func _build_cosmetics() -> void:
	var U := CosmeticInfo.Unlock
	var catalog := CosmeticCatalog.new()
	var items: Array[CosmeticInfo] = [
		_outfit("outfit_explorer", U.DEFAULT, 0, ["#2d5fb8", "#f58a2c", "#4c5c6e", "#f07a22", "#27b7c4"]),
		_outfit("outfit_sunset", U.SPARKS, 150, ["#e8553d", "#ffd04a", "#5a3d5c", "#ffb347", "#ff8fb1"]),
		_outfit("outfit_forest", U.GEMS, 9, ["#2f8f4e", "#f2d16b", "#4b3b2a", "#c8662a", "#9be15d"]),
		_outfit("outfit_midnight", U.SPARKS, 400, ["#2a2f5c", "#b48cff", "#1d2033", "#4ad3ff", "#7a5cff"]),
		_outfit("outfit_polar", U.ACHIEVEMENT, 0, ["#e9f2fb", "#4aa3ff", "#7f93ad", "#f5f5f5", "#8fe3ff"], "yoyo_master"),
		_outfit("outfit_coral", U.GEMS, 21, ["#ff6f91", "#2ec4b6", "#3d405b", "#ffd166", "#2ec4b6"]),
		_outfit("outfit_solar", U.GOLD_MEDALS, 10, ["#f2c14e", "#ffffff", "#8a5a2b", "#ff6b2c", "#fff1a8"]),
		_outfit("outfit_shadow", U.GEMS, 30, ["#1b1b24", "#e03a9a", "#2b2b38", "#e03a9a", "#22d3ee"]),
		_yoyo("yoyo_classic", U.DEFAULT, 0, ["#22d3ee", "#ff9a2e", "#22d3ee"], "#22d3ee"),
		_yoyo("yoyo_ember", U.SPARKS, 120, ["#ff5a36", "#ffd04a", "#ff7b3a"], "#ff8a3a"),
		_yoyo("yoyo_lime", U.SPARKS, 250, ["#8ef05a", "#2f6fdb", "#9bff6a"], "#9bff6a"),
		_yoyo("yoyo_storm", U.GEMS, 15, ["#4a6cff", "#e6f3ff", "#6f8bff"], "#8fa6ff"),
		_yoyo("yoyo_violet", U.ACHIEVEMENT, 0, ["#a66bff", "#22d3ee", "#b98bff"], "#c09bff", "air_ace"),
		_yoyo("yoyo_gold", U.GOLD_MEDALS, 5, ["#ffd447", "#ffffff", "#ffe27a"], "#ffe27a"),
		_yoyo("yoyo_prism", U.ACHIEVEMENT, 0, ["#ff6fd8", "#3ef7ff", "#fff36b"], "#ff9ff0", "campaign_complete"),
	]
	catalog.items = items
	_save(catalog, "res://resources/cosmetics/cosmetic_catalog.tres")


func _ach(id: String, condition: int, target: int, reward: int, stat := "") -> AchievementInfo:
	var a := AchievementInfo.new()
	a.id = StringName(id)
	a.title_key = "ACH_%s" % id.to_upper()
	a.description_key = "ACH_%s_DESC" % id.to_upper()
	a.condition = condition
	a.target = target
	a.reward_sparks = reward
	a.stat = StringName(stat)
	return a


func _build_achievements() -> void:
	var C := AchievementInfo.Condition
	var catalog := AchievementCatalog.new()
	var list: Array[AchievementInfo] = [
		_ach("first_steps", C.TUTORIAL_DONE, 1, 30),
		_ach("isles_done", C.WORLD_DONE, 0, 60),
		_ach("toyworks_done", C.WORLD_DONE, 1, 80),
		_ach("campaign_complete", C.WORLD_DONE, 2, 150),
		_ach("gems_10", C.GEMS, 10, 50),
		_ach("gems_all", C.GEMS, 30, 200),
		_ach("first_gold", C.GOLD_MEDALS, 1, 40),
		_ach("gold_5", C.GOLD_MEDALS, 5, 100),
		_ach("gold_all", C.GOLD_MEDALS, 10, 300),
		_ach("flawless", C.NO_RESPAWN_RUN, 1, 50),
		_ach("flawless_5", C.NO_RESPAWN_RUN, 5, 120),
		_ach("collector", C.ALL_SPARKS_RUN, 1, 40),
		_ach("collector_5", C.ALL_SPARKS_RUN, 5, 120),
		_ach("jumper", C.STAT, 500, 40, "jumps"),
		_ach("yoyo_master", C.STAT, 100, 80, "yoyo_bounces"),
		_ach("air_ace", C.STAT, 150, 60, "dashes"),
		_ach("slider", C.STAT, 100, 40, "slides"),
		_ach("long_jumper", C.STAT, 50, 50, "long_jumps"),
		_ach("trampoline_fan", C.STAT, 60, 40, "trampolines"),
		_ach("booster", C.STAT, 40, 30, "boosts"),
		_ach("wealthy", C.STAT, 1500, 100, "sparks_total"),
		_ach("fashion", C.COSMETICS_OWNED, 1, 20),
		_ach("persistent", C.STAT, 100, 30, "respawns"),
	]
	catalog.achievements = list
	_save(catalog, "res://resources/achievements/achievement_catalog.tres")


func _difficulty(d: int, gap: Vector2, sizes: Array, rise: float, hazards: Vector2, techs: Vector2i, combo: int,
		timed: Vector2, spinner: float, patrol: float, no_rest: int, checkpoint: int, landing: float, crumble: Vector2i,
		index: Vector2, expert: Vector2, casual: Vector2, novice: Vector2) -> DifficultyProfile:
	var p := DifficultyProfile.new()
	p.difficulty = d
	p.gap_fraction = gap
	p.platform_sizes = PackedStringArray(sizes)
	p.max_rise = rise
	p.hazards_per_100m = hazards
	p.techniques = techs
	p.combo_pieces = combo
	p.timed_on_time = timed.x
	p.timed_off_time = timed.y
	p.spinner_speed = spinner
	p.patrol_speed = patrol
	p.motifs_without_rest = no_rest
	p.checkpoint_every = checkpoint
	p.landing_after_long_gap = landing
	p.crumble_chain = crumble
	p.index_range = index
	p.expert_success = expert
	p.casual_success = casual
	p.novice_success = novice
	return p


## Starting values from the service plan ("Parámetros por dificultad").
func _build_difficulty_table() -> void:
	var D := LevelSpec.Difficulty
	var table := DifficultyTable.new()
	var profiles: Array[DifficultyProfile] = [
		_difficulty(D.EASY, Vector2(0.35, 0.55), ["L", "XL", "Wide"], 1.0, Vector2(0, 1), Vector2i(1, 2), 0,
				Vector2(2.6, 1.6), 50.0, 2.5, 2, 2, 8.0, Vector2i(3, 3),
				Vector2(0, 25), Vector2(0, 1), Vector2(0.9, 1), Vector2(0.6, 1)),
		_difficulty(D.MEDIUM, Vector2(0.55, 0.70), ["M", "L"], 1.5, Vector2(2, 3), Vector2i(2, 3), 2,
				Vector2(2.2, 1.4), 70.0, 3.0, 3, 3, 6.0, Vector2i(3, 4),
				Vector2(25, 50), Vector2(0, 1), Vector2(0.6, 0.9), Vector2(0, 1)),
		_difficulty(D.HARD, Vector2(0.70, 0.85), ["S", "M", "Strip"], 2.0, Vector2(4, 5), Vector2i(3, 4), 3,
				Vector2(1.7, 1.1), 95.0, 3.5, 4, 4, 4.0, Vector2i(4, 5),
				Vector2(50, 75), Vector2(0.8, 1), Vector2(0, 0.6), Vector2(0, 1)),
		_difficulty(D.EXTREME, Vector2(0.85, 0.95), ["S", "Strip"], 2.3, Vector2(6, 8), Vector2i(4, 6), 4,
				Vector2(1.3, 1.0), 120.0, 4.0, 6, 5, 3.0, Vector2i(5, 6),
				Vector2(75, 100.01), Vector2(0.4, 0.8), Vector2(0, 1), Vector2(0, 1)),
	]
	table.profiles = profiles
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/generator"))
	_save(table, "res://resources/generator/difficulty_profiles.tres")


func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	print("saved %s -> %s" % [path, error_string(err)])
