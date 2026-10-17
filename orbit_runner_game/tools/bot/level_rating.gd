extends RefCounted
## Difficulty index (0..100) and acceptance of a generated level from the
## validator's analysis and the bot runs (service plan, "Bot validador"):
##   ID = 35 (1 - Vn) + 20 (1 - E_casual) + 15 Cn + 15 Dn + 15 Rn
## Vn: mean take-off window, 300 ms or more counts as 1 (from the validator's
## kinematic model of every jump). E_casual: casual profile success rate.
## Cn, Dn, Rn: complexity, hazard density and longest run without a rest,
## normalised against the Extreme maximum. Weights are starting values.

const WINDOW_FULL := 0.3
const MAX_FAMILIES := 6.0
const MAX_CHAIN := 4.0
const MAX_DENSITY := 8.0
const MAX_RUN := 6.0
const CHAIN_TECHS := ["long", "dash", "boost", "yoyo_air", "yoyo_ground"]
const PROFILES := ["perfect", "expert", "casual", "novice"]


## runs: profile name -> Array of bot results. Returns the full report.
static func rate(level: Level, validation: Dictionary, runs: Dictionary, table: DifficultyTable,
		requested: int) -> Dictionary:
	var meta: Dictionary = level.get_meta("generated", {})
	var success := {}
	for profile in PROFILES:
		var list: Array = runs.get(profile, [])
		var wins := 0
		for r in list:
			if r["finished"]:
				wins += 1
		success[profile] = float(wins) / list.size() if not list.is_empty() else -1.0

	var windows: Array = validation.get("windows", [])
	var v_sum := 0.0
	var narrowest := INF
	for w in windows:
		v_sum += minf(float(w) / WINDOW_FULL, 1.0)
		narrowest = minf(narrowest, float(w))
	var v_n := v_sum / windows.size() if not windows.is_empty() else 1.0
	var e_casual := maxf(float(success.get("casual", 1.0)), 0.0)
	var families: Array = meta.get("families", [])
	var c_n := clampf(0.6 * (families.size() - 1) / (MAX_FAMILIES - 1.0) + 0.4 * _longest_chain(level) / MAX_CHAIN,
			0.0, 1.0)
	var length := maxf(float(meta.get("length", 100.0)), 1.0)
	var density := float(meta.get("hazards", 0)) * 100.0 / length
	var d_n := clampf(density / MAX_DENSITY, 0.0, 1.0)
	var r_n := clampf(_longest_run(meta) / MAX_RUN, 0.0, 1.0)
	var index := 35.0 * (1.0 - v_n) + 20.0 * (1.0 - e_casual) + 15.0 * c_n + 15.0 * d_n + 15.0 * r_n

	var measured := table.category_for_index(index)
	var deaths := {}
	var exposure := 0.0
	var exposure_runs := 0
	var margins: Array[float] = []
	for profile in runs:
		for r in runs[profile]:
			exposure += float(r.get("exposure", 0.0))
			exposure_runs += 1
			for m in r.get("landing_margins", []):
				margins.append(float(m))
			if profile == "perfect":
				continue
			for motif in r.get("deaths_by_motif", {}):
				deaths[int(motif)] = int(deaths.get(int(motif), 0)) + int(r["deaths_by_motif"][motif])
	var hardest := -1
	var most := 0
	for motif in deaths:
		if deaths[motif] > most:
			most = deaths[motif]
			hardest = motif
	margins.sort()
	var expert_time := _median_time(runs.get("expert", []))
	if expert_time <= 0.0:
		expert_time = _median_time(runs.get("perfect", [])) * 1.1
	var report := {
		"index": snappedf(index, 0.1),
		"components": {"window": snappedf(v_n, 0.001), "casual": e_casual, "complexity": snappedf(c_n, 0.001),
				"density": snappedf(d_n, 0.001), "run": snappedf(r_n, 0.001)},
		"hazards_per_100m": snappedf(density, 0.01),
		"success": success,
		"requested": requested,
		"measured": measured,
		"requested_ok": _meets(table.get_profile(requested as LevelSpec.Difficulty), success, index),
		"measured_ok": _meets(table.get_profile(measured), success, index),
		"perfect_ok": float(success.get("perfect", 0.0)) >= 1.0,
		"deaths_by_motif": deaths,
		"hardest_motif": hardest,
		"hardest_motif_id": _motif_id(meta, hardest),
		"narrowest_window_ms": roundi(narrowest * 1000.0) if narrowest != INF else -1,
		"min_landing_margin": snappedf(margins[0], 0.01) if not margins.is_empty() else -1.0,
		"exposure_s": snappedf(exposure / maxf(exposure_runs, 1), 0.01),
		"expert_time": snappedf(expert_time, 0.01),
		"gold": snappedf(expert_time * 1.15, 0.5),
		"silver": snappedf(expert_time * 1.7, 0.5),
	}
	return report


## Every condition of a category: index range, perfect 100 %, profile rates.
static func _meets(profile: DifficultyProfile, success: Dictionary, index: float) -> bool:
	if index < profile.index_range.x or index >= profile.index_range.y:
		return false
	if float(success.get("perfect", 0.0)) < 1.0:
		return false
	return _in(success, "expert", profile.expert_success) and _in(success, "casual", profile.casual_success) \
		and _in(success, "novice", profile.novice_success)


static func _in(success: Dictionary, profile: String, bounds: Vector2) -> bool:
	var rate := float(success.get(profile, -1.0))
	if rate < 0.0:
		return true
	if rate < bounds.x:
		return false
	return bounds.y >= 1.0 or rate <= bounds.y


static func _longest_chain(level: Level) -> float:
	var best := 0
	var run := 0
	for piece in level.get_meta("route", []):
		if piece.get("tech", "") in CHAIN_TECHS:
			run += 1
			best = maxi(best, run)
		elif piece.get("rest", false):
			run = 0
	return best


static func _longest_run(meta: Dictionary) -> float:
	var best := 0
	var run := 0
	for motif in meta.get("motifs", []):
		if motif["rest"]:
			run = 0
		else:
			run += 1
			best = maxi(best, run)
	return best


static func _median_time(list: Array) -> float:
	var times: Array[float] = []
	for r in list:
		if r["finished"]:
			times.append(float(r["time"]))
	if times.is_empty():
		return 0.0
	times.sort()
	return times[times.size() / 2]


static func _motif_id(meta: Dictionary, index: int) -> String:
	var motifs: Array = meta.get("motifs", [])
	return String(motifs[index]["id"]) if index >= 0 and index < motifs.size() else ""
