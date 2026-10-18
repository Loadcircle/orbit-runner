class_name SeasonSchedule
extends Resource
## Seasons ready to go live, with their levels validated by the bot pipeline
## (tools/generate_levels.tscn -- season=N). Launching a season early or late
## is editing its start date; the online service will publish this list
## through remote configuration.
##
## Each season: {id, number, start ("YYYY-MM-DD", 00:00 UTC), days, difficulty,
## levels: [{seed, difficulty, biome, adjustments, gold, silver, index, route_hash}]}

@export var seasons: Array = []
