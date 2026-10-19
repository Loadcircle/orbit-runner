extends RefCounted
## Campaign levels made by the level generator (validated by the bot) that
## follow the hand-authored ones of each world. Each world has 10 levels whose
## difficulty rises, and every world is harder than the previous one.
## `difficulty` is the generator category requested for the slot.
##   godot --headless --fixed-fps 60 --path . res://tools/generate_levels.tscn -- campaign=1 workers=12
## writes tools/campaign_generated.json; build_levels.gd turns it into scenes.

const RESULT_PATH := "res://tools/campaign_generated.json"
const SEED_BASE := 700000

## Mechanics a world may use: what its hand-authored levels (and the tutorial) taught.
const WORLD_MECHANICS := [
	["jump", "long", "dash", "yoyo", "wind", "trampoline", "mover", "crumble", "spikes", "laser"],
	["jump", "long", "dash", "boost", "yoyo", "wind", "trampoline", "timed", "mover", "crumble", "spinner",
			"patrol", "laser", "spikes"],
	["jump", "long", "dash", "boost", "yoyo", "wind", "trampoline", "timed", "mover", "crumble", "spinner",
			"patrol", "laser", "spikes"],
]
## Technique families that define each world (LevelSpec.focus). The list is
## rotated from slot to slot so consecutive levels lead with different ones.
const WORLD_FOCUS := [
	["timing", "wind", "trampoline", "disc"],
	["timing", "boost", "trampoline", "slide"],
	["timing", "slide", "wind", "disc"],
]
const WORLD_BIOMES := ["isles", "toyworks", "ruins"]
const WORLD_TARGET_SECONDS := [40.0, 45.0, 50.0]

## [level id, world, difficulty] in campaign order.
const SLOTS := [
	["w1_l5", 0, 0], ["w1_l6", 0, 0], ["w1_l7", 0, 1], ["w1_l8", 0, 1], ["w1_l9", 0, 1], ["w1_l10", 0, 2],
	["w2_l4", 1, 1], ["w2_l5", 1, 1], ["w2_l6", 1, 1], ["w2_l7", 1, 2], ["w2_l8", 1, 2], ["w2_l9", 1, 2],
	["w2_l10", 1, 2],
	["w3_l4", 2, 2], ["w3_l5", 2, 2], ["w3_l6", 2, 2], ["w3_l7", 2, 2], ["w3_l8", 2, 3], ["w3_l9", 2, 3],
	["w3_l10", 2, 3],
]


static func spec_for(slot: int, variant: int, variant_step: int) -> LevelSpec:
	var s: Array = SLOTS[slot]
	var world: int = s[1]
	var spec := LevelSpec.create(SEED_BASE + slot * 101 + 7 + variant * variant_step, s[2] as LevelSpec.Difficulty,
			StringName(WORLD_BIOMES[world]), LevelSpec.Mode.CAMPAIGN, WORLD_TARGET_SECONDS[world])
	spec.mechanics = PackedStringArray(WORLD_MECHANICS[world])
	var focus: Array = WORLD_FOCUS[world].duplicate()
	for i in slot % focus.size():
		focus.push_back(focus.pop_front())
	spec.focus = PackedStringArray(focus)
	return spec

