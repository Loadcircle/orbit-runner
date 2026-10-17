class_name BiomeTheme
extends Resource
## Look and sound of a world: sky, light, fog and music.

@export var id: StringName
@export var sky_top: Color = Color(0.25, 0.55, 0.92)
@export var sky_horizon: Color = Color(0.72, 0.88, 0.98)
@export var ground_bottom: Color = Color(0.36, 0.62, 0.86)
@export var sun_color: Color = Color(1.0, 0.96, 0.88)
@export var sun_energy: float = 1.2
@export var sun_rotation_degrees: Vector3 = Vector3(-50, -35, 0)
@export var ambient_energy: float = 0.8
@export var fog_color: Color = Color(0.72, 0.86, 0.98)
@export var fog_density: float = 0.006
@export var music_id: StringName = &"isles"
## Tint of the cloud sea under the islands.
@export var cloud_color: Color = Color(1, 1, 1)
