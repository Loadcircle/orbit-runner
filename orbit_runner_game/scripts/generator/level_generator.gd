class_name LevelGenerator
extends RefCounted
## Builds a level from a LevelSpec by chaining motifs (short route sections of
## proven design, see MotifLibrary) whose parameters come from the difficulty
## table. Every level is checked by LevelValidator; a failed attempt is
## rebuilt with the next sub-seed. The same code runs in the editor for
## batches (tools/generate_levels.tscn) and on the phone (daily, tower).

const VERSION := 1
const TABLE: DifficultyTable = preload("res://resources/generator/difficulty_profiles.tres")
const BIOMES := {
	&"isles": preload("res://resources/biomes/isles.tres"),
	&"toyworks": preload("res://resources/biomes/toyworks.tres"),
	&"ruins": preload("res://resources/biomes/ruins.tres"),
}
const PREFIXES := {&"isles": "isle", &"toyworks": "toy", &"ruins": "ruin"}
const MAX_ATTEMPTS := 12
## Average speed of a confident run, used for the time estimate (D7).
const EXPERT_SPEED := 7.0
const SIZE_ORDER: Array[String] = ["S", "Strip", "M", "Wide", "L", "XL"]
## Technique families counted by DifficultyProfile.techniques.
const FAMILIES: Array[String] = ["jump", "long", "dash", "boost", "disc", "slide", "timing", "trampoline", "wind"]
## A gap demanding a technique must be longer than what this weaker one clears.
const WEAKER := {"long": "jump", "dash": "jump", "boost": "jump", "yoyo_air": "dash"}
## Tower: floors per checkpoint and the difficulty band of each floor.
const TOWER_CHECKPOINT_FLOORS := 10
const TOWER_BANDS := [[0, 10], [10, 20], [20, 35], [35, 1000000]]

var reach := MovementReach.new()
var rng := RandomNumberGenerator.new()
var spec: LevelSpec
var profile: DifficultyProfile
var b: LevelBuilder
var families := PackedStringArray()
## Placed motifs: {id, first, last, hazards, rest, floor}.
var motifs: Array[Dictionary] = []
## Footprints off the route (gem islands), for the overlap check.
var extras: Array[Dictionary] = []
var hazards := 0
var since_rest := 0
var since_checkpoint := 0
var gems_placed := 0
var last_clean := true
var floor_number := 0
var extra_time := 0.0

var _attempt := 0
var _ramp := -1.0
var _hazard_target := 0.0
var _previous_motif := ""
var _used: Dictionary = {}


# ------------------------------------------------------------------ public API

## Builds and validates a level. Returns {"level": Level or null, "attempt",
## "validation", "meta"}. The caller owns (adds to the tree or frees) the level.
func generate(level_spec: LevelSpec) -> Dictionary:
	var validator := LevelValidator.new(reach)
	var last_check := {}
	for attempt in MAX_ATTEMPTS:
		var level := build(level_spec, attempt)
		var check := validator.validate(level, TABLE.get_profile(level_spec.difficulty))
		last_check = check
		if check["ok"]:
			return {"level": level, "attempt": attempt, "validation": check, "meta": level.get_meta("generated")}
		level.free()
	return {"level": null, "attempt": MAX_ATTEMPTS, "validation": last_check, "meta": {}}


## One generation attempt, without validation.
func build(level_spec: LevelSpec, attempt := 0) -> Level:
	_reset(level_spec, attempt)
	_choose_families()
	_start()
	while estimate_seconds() + 4.0 < spec.target_seconds:
		if since_rest >= profile.motifs_without_rest:
			rest()
		else:
			add_motif(_pick_motif())
	return _finish()


## Tower mode: start platform plus the first floors. Extend with extend_tower().
func begin_tower(level_spec: LevelSpec, floors := TOWER_CHECKPOINT_FLOORS) -> Level:
	_reset(level_spec, 0)
	families = PackedStringArray(FAMILIES)
	_start()
	extend_tower(floors)
	var level := b.finish_in_memory()
	_write_meta(level)
	return level


## Adds `count` floors to the tower. When the level is already in the tree the
## new pieces appear live; returns the route index of the first new piece.
func extend_tower(count: int) -> int:
	var first := b.route().size()
	for i in count:
		floor_number += 1
		_tower_profile()
		since_rest = 0
		add_motif(_pick_motif())
		b.tag({"floor": floor_number})
		if floor_number % TOWER_CHECKPOINT_FLOORS == 0:
			since_checkpoint = profile.checkpoint_every
			rest()
			b.tag({"floor": floor_number, "floor_checkpoint": true})
	if b.root.is_inside_tree():
		b.root.set_meta("route", b.route())
		_write_meta(b.root)
	return first


func estimate_seconds() -> float:
	return b.path_length / EXPERT_SPEED + b.wait_time * 1.6 + extra_time


# ------------------------------------------------------------------ helpers used by MotifLibrary

func fraction() -> float:
	if _ramp >= 0.0:
		var base := lerpf(profile.gap_fraction.x, profile.gap_fraction.y, _ramp)
		return clampf(base + rng.randf_range(-0.03, 0.03), profile.gap_fraction.x, profile.gap_fraction.y)
	return rng.randf_range(profile.gap_fraction.x, profile.gap_fraction.y)


## Gap for a technique: a fraction of its reach, never short enough for the
## weaker technique to clear it (so the technique is really demanded).
func gap_for(tech: String, rise := 0.0, cap := INF) -> float:
	var top := reach.max_gap(tech, rise)
	var gap := top * fraction()
	if WEAKER.has(tech):
		gap = maxf(gap, reach.max_gap(WEAKER[tech], rise) + 0.3)
	gap *= float(_adjustment().get("gap", 1.0))
	return clampf(minf(gap, cap), 1.5, top * 0.95)


func size_key() -> String:
	return profile.platform_sizes[rng.randi() % profile.platform_sizes.size()]


## Smallest size of the profile at least `min_len` long (any size if none).
func landing_size(min_len: float) -> String:
	for key in SIZE_ORDER:
		if profile.platform_sizes.has(key) and (LevelBuilder.SIZES[key] as Vector2).y >= min_len:
			return key
	for key in SIZE_ORDER:
		if (LevelBuilder.SIZES[key] as Vector2).y >= min_len:
			return key
	return "XL"


func difficulty() -> int:
	return profile.difficulty


func has_family(family: String) -> bool:
	return families.has(family)


## Random technique among `options` that this level demands.
func pick_tech(options: Array) -> String:
	var allowed: Array = []
	for tech in options:
		var family: String = "disc" if tech == "yoyo_air" or tech == "yoyo_ground" else tech
		if families.has(family):
			allowed.append(tech)
	if allowed.is_empty():
		return options[0]
	return allowed[rng.randi() % allowed.size()]


## Places a platform on the route and annotates the technique that reaches it.
func place_plat(size: String, tech: String, gap: float, rise := 0.0, side := 0.0) -> Node3D:
	var steps := int(_adjustment().get("size", 0))
	if steps != 0:
		size = SIZE_ORDER[clampi(SIZE_ORDER.find(size) + steps, 0, SIZE_ORDER.size() - 1)]
	var node := b.plat(size, gap, rise, side)
	tag_piece(tech)
	last_clean = true
	return node


func tag_piece(tech: String, extra := {}) -> void:
	var values := {"tech": tech, "motif": motifs.size() - 1}
	values.merge(extra, true)
	b.tag(values)


## Makes sure the route ends on a clean platform at least `min_len` long
## (run-up for long jumps, room for a trampoline, safe ground before waits).
func ensure_platform(min_len := 6.0) -> void:
	var piece: Dictionary = b.route()[-1]
	if piece["kind"] == "plat" and last_clean and b.last_size.y >= min_len:
		return
	var size := landing_size(min_len)
	place_plat(size, "jump", gap_for("jump", 0.0) * 0.8, 0.0)


func add_hazards(count: int) -> void:
	hazards += count
	last_clean = false


# ------------------------------------------------------------------ motifs, rests and gems

func add_motif(id: String) -> void:
	var first := b.route().size()
	motifs.append({"id": id, "first": first, "last": first, "hazards": 0, "rest": false, "floor": floor_number})
	var hazards_before := hazards
	MotifLibrary.build(id, self)
	var record := motifs[-1]
	record["last"] = b.route().size() - 1
	record["hazards"] = hazards - hazards_before
	_previous_motif = id
	_used[id] = int(_used.get(id, 0)) + 1
	since_rest += 1
	since_checkpoint += 1


## A wide, safe platform: decoration, the checkpoint when due and a gem detour.
func rest(final := false) -> void:
	motifs.append({"id": "rest", "first": b.route().size(), "last": b.route().size(), "hazards": 0, "rest": true,
			"floor": floor_number})
	var sizes := ["L", "XL", "Wide"] if not final else ["XL"]
	var size: String = sizes[rng.randi() % sizes.size()]
	var rise := rng.randf_range(-0.5, 0.5)
	place_plat(size, "jump", reach.max_gap("jump", rise) * rng.randf_range(0.35, 0.5), rise)
	b.tag({"rest": true})
	b.decorate(2)
	since_rest = 0
	if final:
		b.goal(b.last_size.y * 0.5 - 3.0)
		while gems_placed < 3:
			gem_detour(-3.0 if gems_placed % 2 == 0 else 3.0)
		return
	if since_checkpoint >= profile.checkpoint_every:
		b.checkpoint(0.0)
		since_checkpoint = 0
	var due := (gems_placed + 1) * spec.target_seconds / 4.0
	if spec.mode != LevelSpec.Mode.TOWER and gems_placed < 3 and estimate_seconds() >= due:
		gem_detour(rng.randf_range(-2.0, 2.0))
	motifs[-1]["last"] = b.route().size() - 1


## Side island with a gem, one difficulty step above the main route.
func gem_detour(along: float) -> void:
	var dir := 1.0 if (gems_placed + rng.randi()) % 2 == 0 else -1.0
	var rise := rng.randf_range(-0.5, 1.0)
	var frac := minf(profile.gap_fraction.y + 0.12, 0.95)
	var gap := reach.max_gap("jump", rise) * frac
	var island := b.side_plat("S", gap, rise, along, dir)
	b.gem(gems_placed, island.position + Vector3.UP * 0.3)
	extras.append({"kind": "island", "pos": island.position, "yaw": b.yaw, "len": 3.0, "wid": 3.0})
	gems_placed += 1


# ------------------------------------------------------------------ internals

func _reset(level_spec: LevelSpec, attempt: int) -> void:
	spec = level_spec
	_attempt = attempt
	profile = TABLE.get_profile(spec.difficulty)
	rng.seed = hash([spec.seed_value, spec.generator_version, attempt, int(spec.difficulty), String(spec.biome)])
	b = LevelBuilder.new()
	var biome: BiomeTheme = BIOMES.get(spec.biome, BIOMES[&"isles"])
	b.begin("Generated_%d" % spec.seed_value, PREFIXES.get(spec.biome, "isle"), biome, rng.randi())
	families = PackedStringArray()
	motifs = []
	extras = []
	hazards = 0
	since_rest = 0
	since_checkpoint = 0
	gems_placed = 0
	last_clean = true
	floor_number = 0
	extra_time = 0.0
	_ramp = -1.0
	_previous_motif = ""
	_used = {}
	_hazard_target = rng.randf_range(profile.hazards_per_100m.x, profile.hazards_per_100m.y)


func _choose_families() -> void:
	var pool: Array[String] = []
	var checks := {
		"long": spec.allows("long"), "dash": spec.allows("dash"), "boost": spec.allows("boost"),
		"disc": spec.allows("yoyo"), "slide": spec.allows("laser"), "trampoline": spec.allows("trampoline"),
		"wind": spec.allows("wind"),
		"timing": spec.allows("timed") or spec.allows("mover") or spec.allows("spinner") or spec.allows("patrol"),
	}
	for family in FAMILIES:
		if family != "jump" and checks.get(family, false):
			pool.append(family)
	_shuffle(pool)
	var count := rng.randi_range(profile.techniques.x, profile.techniques.y) - 1
	families = PackedStringArray(["jump"])
	for i in mini(count, pool.size()):
		families.append(pool[i])


func _start() -> void:
	motifs.append({"id": "start", "first": 0, "last": 0, "hazards": 0, "rest": true, "floor": 0})
	b.start("L")
	b.tag({"tech": "walk", "motif": 0, "rest": true})
	b.decorate(2)


func _finish() -> Level:
	rest(true)
	var level := b.finish_in_memory()
	_write_meta(level)
	level.set_meta("extras", extras)
	return level


func _write_meta(level: Level) -> void:
	var estimate := estimate_seconds()
	var gold := snappedf(estimate + 4.0, 0.5)
	level.set_meta("generated", {
		"spec": spec.to_dict(),
		"generator_version": VERSION,
		"attempt": _attempt,
		"families": Array(families),
		"motifs": motifs.duplicate(true),
		"hazards": hazards,
		"length": b.path_length,
		"estimate": estimate,
		"gold": gold,
		"silver": snappedf(gold * 1.35 + 6.0, 0.5),
		"route_hash": route_hash(b.route()),
	})
	level.set_meta("extras", extras)


func _pick_motif() -> String:
	var options := MotifLibrary.available(self)
	var density := hazards * 100.0 / maxf(b.path_length, 30.0)
	var weights: Array[float] = []
	var total := 0.0
	for id in options:
		var info: Dictionary = MotifLibrary.MOTIFS[id]
		var w := 1.0
		if id == _previous_motif:
			w = 0.05
		elif not _used.has(id):
			w *= 3.0
		if info["hazard"]:
			if density < _hazard_target:
				w *= 3.0 + 2.0 * _hazard_target
			elif density > profile.hazards_per_100m.y:
				w *= 0.05
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[-1]


func _tower_profile() -> void:
	for i in TOWER_BANDS.size():
		var band: Array = TOWER_BANDS[i]
		if floor_number - 1 < band[1]:
			profile = TABLE.get_profile(i as LevelSpec.Difficulty)
			var span := float(mini(band[1], 60) - band[0])
			_ramp = clampf(float(floor_number - 1 - band[0]) / maxf(span, 1.0), 0.0, 1.0)
			_hazard_target = lerpf(profile.hazards_per_100m.x, profile.hazards_per_100m.y, _ramp)
			return


## Repair applied by the bot pipeline to the motif being built (LevelSpec.adjustments).
func _adjustment() -> Dictionary:
	if spec == null or spec.adjustments.is_empty():
		return {}
	return spec.adjustments.get(motifs.size() - 1, {})


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp


## Hash of the route rounded to centimetres: two devices that generated the
## same level from the same seed produce the same hash.
static func route_hash(route: Array) -> String:
	var parts := PackedStringArray()
	for piece in route:
		var p: Vector3 = piece["pos"]
		parts.append("%s:%d,%d,%d" % [piece["kind"], roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0)])
	return ",".join(parts).sha256_text().substr(0, 16)


## LevelInfo for a generated level (not part of the campaign catalog).
static func make_info(level: Level, id: String, title_key: String) -> LevelInfo:
	var meta: Dictionary = level.get_meta("generated", {})
	var info := LevelInfo.new()
	info.id = StringName(id)
	info.title_key = title_key
	info.world_index = -1
	info.biome = level.biome
	info.gold_time = float(meta.get("gold", 60.0))
	info.silver_time = float(meta.get("silver", 80.0))
	return info
