class_name LevelCatalog
extends Resource
## Ordered campaign. A level unlocks when the previous one is completed.

@export var levels: Array[LevelInfo] = []
## Translation keys for world names, indexed by LevelInfo.world_index.
@export var world_title_keys: PackedStringArray = []


func index_of(id: StringName) -> int:
	for i in levels.size():
		if levels[i].id == id:
			return i
	return -1


func get_level(id: StringName) -> LevelInfo:
	var i := index_of(id)
	return levels[i] if i >= 0 else null


func levels_in_world(world_index: int) -> Array[LevelInfo]:
	var result: Array[LevelInfo] = []
	for level in levels:
		if level.world_index == world_index:
			result.append(level)
	return result
