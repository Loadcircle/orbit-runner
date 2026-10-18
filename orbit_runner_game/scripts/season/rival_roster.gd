class_name RivalRoster
extends RefCounted
## Simulated runners that fill the leaderboards when the player is offline, has
## no friends yet or few people are playing. Everything is derived from seeds,
## so a rival's progress is the same on every launch and grows with real time
## during a season. Rivals are always marked `simulated` and the boards say so;
## they can be removed once there are enough real players.

const COUNT := 60
const NAME_HEADS := ["Nova", "Kiwi", "Pixel", "Zuri", "Milo", "Tika", "Bolt", "Luma", "Rio", "Coco", "Yuki", "Taro",
		"Nilo", "Fizz", "Momo", "Juno", "Kai", "Lila", "Orbi", "Zeta", "Pipo", "Suki", "Toto", "Mika"]
const NAME_TAILS := ["Run", "Jump", "Star", "Wave", "Spin", "Dash", "Fly", "Hop", "Zip", "Ray", "Bee", "Fox"]
## Skill profiles (the bot profiles): share of rivals, time over gold,
## chance per gem, spark ratio, chance of a flawless run, levels per day.
const SKILLS := {
	"perfect": {"share": 0.06, "time": [0.9, 1.0], "gem": 0.95, "sparks": [0.9, 1.0], "flawless": 0.75, "pace": [4.0, 9.0]},
	"expert": {"share": 0.24, "time": [0.98, 1.18], "gem": 0.8, "sparks": [0.75, 1.0], "flawless": 0.45, "pace": [3.0, 7.0]},
	"casual": {"share": 0.45, "time": [1.15, 1.6], "gem": 0.55, "sparks": [0.5, 0.9], "flawless": 0.15, "pace": [2.0, 5.0]},
	"novice": {"share": 0.25, "time": [1.5, 2.4], "gem": 0.3, "sparks": [0.3, 0.7], "flawless": 0.05, "pace": [0.8, 3.0]},
}

static var _rivals: Array[Dictionary] = []


## {id, name, outfit, skill, pace, delay, online}
static func get_rival(index: int) -> Dictionary:
	if _rivals.is_empty():
		_build()
	return _rivals[clampi(index, 0, COUNT - 1)]


static func all() -> Array[Dictionary]:
	if _rivals.is_empty():
		_build()
	return _rivals


static func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var outfits: Array[StringName] = []
	for item in Progress.COSMETIC_CATALOG.of_kind(CosmeticInfo.Kind.OUTFIT):
		outfits.append(item.id)
	var used := {}
	for i in COUNT:
		var name := ""
		while name == "" or used.has(name):
			name = NAME_HEADS[rng.randi_range(0, NAME_HEADS.size() - 1)] + NAME_TAILS[rng.randi_range(0, NAME_TAILS.size() - 1)]
			if rng.randf() < 0.4:
				name += str(rng.randi_range(2, 99))
		used[name] = true
		var roll := rng.randf()
		var skill := "novice"
		for key in SKILLS:
			roll -= float(SKILLS[key]["share"])
			if roll < 0.0:
				skill = key
				break
		var pace: Array = SKILLS[skill]["pace"]
		_rivals.append({"id": "rival_%02d" % i, "name": name, "outfit": outfits[rng.randi_range(0, outfits.size() - 1)],
				"skill": skill, "pace": rng.randf_range(pace[0], pace[1]),
				# Hours after the season start before the first run.
				"delay": rng.randi_range(0, 36) * 3600,
				# Chance of being "playing now" in a given hour.
				"online": rng.randf_range(0.05, 0.35), "simulated": true})


## Results of rival `index` in `season` as of `now`: {points, time, levels}.
static func season_result(index: int, season: Dictionary, now: int) -> Dictionary:
	var rival := get_rival(index)
	var played := mini(now, Season.ends_at(season)) - Season.starts_at(season) - int(rival["delay"])
	var result := {"points": 0, "time": 0.0, "levels": 0}
	if played <= 0:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s" % [rival["id"], season["id"]])
	var pace := float(rival["pace"]) * rng.randf_range(0.7, 1.3)
	var count := mini(int(played / 86400.0 * pace) + 1, Season.level_count(season))
	var skill: Dictionary = SKILLS[rival["skill"]]
	for i in count:
		var e := Season.entry(season, i)
		rng.seed = hash("%s|%s|%d" % [rival["id"], season["id"], i])
		var gold := float(e.get("gold", 40.0))
		var time := gold * rng.randf_range(skill["time"][0], skill["time"][1])
		var medal := 3 if time <= gold else (2 if time <= float(e.get("silver", gold * 1.5)) else 1)
		var gems := 0
		for g in 3:
			if rng.randf() < float(skill["gem"]):
				gems += 1
		var sparks := rng.randf_range(skill["sparks"][0], skill["sparks"][1])
		var flawless := rng.randf() < float(skill["flawless"])
		result["points"] += SeasonScoring.points(medal, gems, sparks, flawless)
		result["time"] += time
		result["levels"] += 1
	return result


static func is_playing(index: int, now: int) -> bool:
	return _online_in_hour(index, now / 3600)


## Hours since the rival was last playing (0 = now), up to 72.
static func hours_since_played(index: int, now: int) -> int:
	var hour := now / 3600
	for h in 72:
		if _online_in_hour(index, hour - h):
			return h
	return 72


static func _online_in_hour(index: int, hour: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d" % [index, hour])
	return rng.randf() < float(get_rival(index)["online"])
