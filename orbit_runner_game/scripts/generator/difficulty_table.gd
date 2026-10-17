class_name DifficultyTable
extends Resource
## The four difficulty categories (resources/generator/difficulty_profiles.tres).

@export var profiles: Array[DifficultyProfile] = []


func get_profile(difficulty: LevelSpec.Difficulty) -> DifficultyProfile:
	for profile in profiles:
		if profile.difficulty == difficulty:
			return profile
	return profiles[clampi(difficulty, 0, profiles.size() - 1)]


## Category whose index range contains `index`.
func category_for_index(index: float) -> LevelSpec.Difficulty:
	for profile in profiles:
		if index >= profile.index_range.x and index < profile.index_range.y:
			return profile.difficulty
	return LevelSpec.Difficulty.EXTREME if index >= 50.0 else LevelSpec.Difficulty.EASY
