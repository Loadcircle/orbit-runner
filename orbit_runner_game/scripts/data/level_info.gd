class_name LevelInfo
extends Resource
## Static description of one campaign level. Runtime results live in Progress.

@export var id: StringName
## Translation key of the level name.
@export var title_key: String
@export var world_index: int = 0
@export_file("*.tscn") var scene_path: String
@export var biome: BiomeTheme
## Time (seconds) needed for the gold and silver medals; finishing gives bronze.
@export var gold_time: float = 60.0
@export var silver_time: float = 80.0
## True for the interactive tutorial: it is replayable but excluded from medals.
@export var is_tutorial: bool = false
## Translation key of the short hint shown on the level card.
@export var hint_key: String
