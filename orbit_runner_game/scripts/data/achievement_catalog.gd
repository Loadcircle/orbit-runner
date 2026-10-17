class_name AchievementCatalog
extends Resource

@export var achievements: Array[AchievementInfo] = []


func get_achievement(id: StringName) -> AchievementInfo:
	for a in achievements:
		if a.id == id:
			return a
	return null
