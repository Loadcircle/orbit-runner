class_name AchievementInfo
extends Resource
## A verifiable goal. Progress evaluates `condition` against saved data.

enum Condition {
	STAT,            ## stats[stat] >= target
	LEVELS_DONE,     ## completed campaign levels (tutorial excluded) >= target
	WORLD_DONE,      ## every level of world `target` completed
	GEMS,            ## gems collected >= target
	GOLD_MEDALS,     ## gold medals >= target
	NO_RESPAWN_RUN,  ## a level finished without respawning (target = count)
	ALL_SPARKS_RUN,  ## a level finished with every spark (target = count)
	COSMETICS_OWNED, ## non-default cosmetics owned >= target
	TUTORIAL_DONE,
}

@export var id: StringName
@export var title_key: String
@export var description_key: String
@export var condition: Condition = Condition.STAT
@export var stat: StringName
@export var target: int = 1
## Sparks granted when unlocked.
@export var reward_sparks: int = 0
