class_name Leaderboard
extends RefCounted
## Season standings: the player plus simulated runners (global) or plus
## friends (friends). Real players from the online service will be merged in
## here. Entry: {id, name, outfit, points, time, levels, rank, is_player,
## simulated}.

const PLAYER_ID := "player"


static func build(season: Dictionary, now: int, friends_only: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var mine := Progress.season_totals(String(season["id"]))
	entries.append({"id": PLAYER_ID, "name": Services.display_name(), "outfit": Progress.equipped(CosmeticInfo.Kind.OUTFIT).id,
			"points": mine["points"], "time": mine["time"], "levels": mine["levels"], "is_player": true,
			"simulated": false})
	var indices: Array[int] = []
	if friends_only:
		for f in Services.social.friends():
			indices.append(int(f["rival"]))
	else:
		for i in RivalRoster.COUNT:
			indices.append(i)
	for i in indices:
		var r := RivalRoster.season_result(i, season, now)
		if int(r["levels"]) == 0:
			continue
		var rival := RivalRoster.get_rival(i)
		entries.append({"id": rival["id"], "name": rival["name"], "outfit": rival["outfit"], "points": r["points"],
				"time": r["time"], "levels": r["levels"], "is_player": false, "simulated": true, "rival": i})
	entries.sort_custom(_better)
	for i in entries.size():
		entries[i]["rank"] = i + 1
	return entries


## Global position of the player (1 = first) and the board size.
static func player_rank(season: Dictionary, now: int) -> Vector2i:
	var board := build(season, now, false)
	for e in board:
		if e["is_player"]:
			return Vector2i(int(e["rank"]), board.size())
	return Vector2i(board.size(), board.size())


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if int(a["points"]) != int(b["points"]):
		return int(a["points"]) > int(b["points"])
	if int(a["levels"]) != int(b["levels"]):
		return int(a["levels"]) > int(b["levels"])
	if not is_equal_approx(float(a["time"]), float(b["time"])):
		return float(a["time"]) < float(b["time"])
	return bool(a["is_player"]) and not bool(b["is_player"])
