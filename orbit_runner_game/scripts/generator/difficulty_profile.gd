class_name DifficultyProfile
extends Resource
## One row of the difficulty table: generation parameters and the bot
## acceptance rule for a category. Values are prototype hypotheses: the bot
## and the calibration with players adjust them.

@export var difficulty: LevelSpec.Difficulty = LevelSpec.Difficulty.MEDIUM

@export_group("Generation")
## Gap as a fraction of the maximum reach of the technique it demands (min, max).
@export var gap_fraction := Vector2(0.55, 0.70)
@export var platform_sizes := PackedStringArray(["M", "L"])
## Largest climb between two platforms for a plain jump (metres).
@export var max_rise := 1.5
## Hazards for every 100 m of route (min, max).
@export var hazards_per_100m := Vector2(2.0, 3.0)
## Distinct techniques the level demands (min, max).
@export var techniques := Vector2i(2, 3)
## Technique gaps chained without a resting platform (0 = no chains).
@export var combo_pieces := 2
## Visible time of timed platforms (seconds).
@export var timed_on_time := 2.2
@export var timed_off_time := 1.4
@export var spinner_speed := 70.0
@export var patrol_speed := 3.0
## Challenge motifs allowed in a row before a resting platform.
@export var motifs_without_rest := 3
## Challenge motifs between checkpoints (checkpoints always sit on a rest).
@export var checkpoint_every := 3
## Minimum landing platform length after a long-jump, dash or disc gap.
@export var landing_after_long_gap := 6.0
## Number of crumbling tiles in a chain (min, max).
@export var crumble_chain := Vector2i(3, 4)

@export_group("Acceptance")
## Difficulty index range (0..100) that belongs to this category.
@export var index_range := Vector2(25.0, 50.0)
## Success rate ranges per bot profile as [min, max]; max 1.0 = no upper bound.
@export var expert_success := Vector2(0.0, 1.0)
@export var casual_success := Vector2(0.6, 0.9)
@export var novice_success := Vector2(0.0, 1.0)
