class_name LevelSpec
extends Resource
## What the level generator is asked to build. The same seed and generator
## version produce the same level on every device.

enum Difficulty { EASY, MEDIUM, HARD, EXTREME }
enum Mode { CAMPAIGN, DAILY, TOWER }

const BIOMES: Array[StringName] = [&"isles", &"toyworks", &"ruins"]
## Everything a generated level may ask of the player. Seasons add new ids.
const ALL_MECHANICS: Array[String] = ["jump", "long", "dash", "boost", "yoyo", "wind", "trampoline", "timed",
		"crumble", "mover", "spinner", "patrol", "laser", "spikes"]
const DIFFICULTY_KEYS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD", "DIFF_EXTREME"]

@export var seed_value: int = 1
@export var generator_version: int = 1
@export var biome: StringName = &"isles"
@export var difficulty: Difficulty = Difficulty.MEDIUM
## Duration for an expert player; decides the number of motifs.
@export var target_seconds: float = 45.0
@export var mechanics := PackedStringArray(ALL_MECHANICS)
@export var mode: Mode = Mode.CAMPAIGN
## Repairs made by the bot pipeline: motif index -> {"gap": scale, "size": steps}.
## Part of the spec so the repaired level can be rebuilt on any device.
@export var adjustments: Dictionary = {}


static func create(seed_value: int, difficulty: Difficulty, biome := &"isles", mode := Mode.CAMPAIGN,
		target_seconds := 45.0) -> LevelSpec:
	var spec := LevelSpec.new()
	spec.seed_value = seed_value
	spec.difficulty = difficulty
	spec.biome = biome
	spec.mode = mode
	spec.target_seconds = target_seconds
	return spec


## Stable identifier used for saves, replays and report files.
func key() -> String:
	return "%s_v%d_%s_%d_%d" % [Mode.keys()[mode].to_lower(), generator_version, biome, difficulty, seed_value]


func to_dict() -> Dictionary:
	return {"seed": seed_value, "generator_version": generator_version, "biome": String(biome),
			"difficulty": difficulty, "target_seconds": target_seconds, "mechanics": Array(mechanics),
			"mode": mode, "adjustments": adjustments}


static func from_dict(data: Dictionary) -> LevelSpec:
	var spec := LevelSpec.new()
	spec.seed_value = int(data.get("seed", 1))
	spec.generator_version = int(data.get("generator_version", 1))
	spec.biome = StringName(data.get("biome", "isles"))
	spec.difficulty = clampi(int(data.get("difficulty", 1)), 0, 3) as Difficulty
	spec.target_seconds = float(data.get("target_seconds", 45.0))
	spec.mechanics = PackedStringArray(data.get("mechanics", ALL_MECHANICS))
	spec.mode = clampi(int(data.get("mode", 0)), 0, 2) as Mode
	var adjust: Dictionary = data.get("adjustments", {})
	for key in adjust:
		spec.adjustments[int(key)] = adjust[key]
	return spec


func allows(mechanic: String) -> bool:
	return mechanics.has(mechanic)
