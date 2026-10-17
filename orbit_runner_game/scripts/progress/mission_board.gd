class_name MissionBoard
extends RefCounted
## Daily (3) and weekly (7) missions. They are chosen from the date, so every
## player gets the same ones, and progress is the growth of a Progress stat
## since the mission was assigned. Rewards are sparks for now; the season
## pass will add XP (service plan, D4/D5). The official rotation will come
## from remote configuration once the online service exists.

const DAILY_COUNT := 3
const WEEKLY_COUNT := 7
## id, stat, target, reward (sparks). Text key: "MISSION_<ID>" with %d = target.
const DAILY := [
	["bounce", "yoyo_bounces", 15, 40], ["jumps", "jumps", 150, 30], ["slides", "slides", 20, 30],
	["dashes", "dashes", 20, 30], ["trampolines", "trampolines", 8, 30], ["boosts", "boosts", 6, 30],
	["levels", "levels_finished", 3, 50], ["sparks", "sparks_total", 150, 40], ["daily", "daily_finished", 1, 60],
	["tower", "tower_floors", 10, 50], ["long_jumps", "long_jumps", 8, 40], ["flawless", "no_respawn_runs", 1, 50],
]
const WEEKLY := [
	["bounce", "yoyo_bounces", 80, 120], ["jumps", "jumps", 800, 100], ["slides", "slides", 100, 100],
	["dashes", "dashes", 100, 100], ["levels", "levels_finished", 15, 150], ["sparks", "sparks_total", 800, 120],
	["daily", "daily_finished", 5, 200], ["tower", "tower_floors", 60, 160], ["long_jumps", "long_jumps", 40, 120],
	["flawless", "no_respawn_runs", 5, 150], ["gold", "gold_runs", 3, 150], ["all_sparks", "all_spark_runs", 3, 150],
]

var _data: Dictionary
var _stat: Callable


## `data`: the save section; `stat`: func(name: StringName) -> int.
func _init(data: Dictionary, stat: Callable) -> void:
	_data = data
	_stat = stat


## Assigns new missions when the day or the week changed. Returns true then.
func refresh(day_key: String, week_key: String) -> bool:
	var changed := false
	if _data.get("day", "") != day_key:
		_data["day"] = day_key
		_data["daily"] = _assign(DAILY, DAILY_COUNT, hash(day_key))
		changed = true
	if _data.get("week", "") != week_key:
		_data["week"] = week_key
		_data["weekly"] = _assign(WEEKLY, WEEKLY_COUNT, hash(week_key))
		changed = true
	return changed


## Missions of "daily" or "weekly" with their current progress.
func missions(kind: String) -> Array:
	var result := []
	for m in _data.get(kind, []):
		var entry: Dictionary = (m as Dictionary).duplicate()
		entry["progress"] = clampi(int(_stat.call(StringName(m["stat"]))) - int(m["start"]), 0, int(m["target"]))
		entry["done"] = entry["progress"] >= int(m["target"])
		result.append(entry)
	return result


## Marks a completed mission as claimed and returns its reward (0 if not claimable).
func claim(kind: String, index: int) -> int:
	var list: Array = _data.get(kind, [])
	if index < 0 or index >= list.size():
		return 0
	var m: Dictionary = list[index]
	if m["claimed"] or int(_stat.call(StringName(m["stat"]))) - int(m["start"]) < int(m["target"]):
		return 0
	m["claimed"] = true
	return int(m["reward"])


func claimable_count() -> int:
	var count := 0
	for kind in ["daily", "weekly"]:
		for m in missions(kind):
			if m["done"] and not m["claimed"]:
				count += 1
	return count


func _assign(pool: Array, count: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var order := range(pool.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var list := []
	for i in mini(count, pool.size()):
		var t: Array = pool[order[i]]
		list.append({"id": t[0], "stat": t[1], "target": t[2], "reward": t[3], "claimed": false,
				"start": int(_stat.call(StringName(t[1])))})
	return list
