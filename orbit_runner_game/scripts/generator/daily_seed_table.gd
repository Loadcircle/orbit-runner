class_name DailySeedTable
extends Resource
## Daily challenge levels already validated by the bot pipeline on PC
## (tools/generate_levels.tscn -- dailies=N). Until the online service
## publishes official seeds, the phone uses this table and falls back to the
## date seed with static validation only.

## "YYYY-MM-DD" -> {seed, difficulty, biome, adjustments, gold, silver, index, route_hash}
@export var entries: Dictionary = {}
