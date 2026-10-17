class_name BiomeTheme
extends Resource
## Look and sound of a world: sky, light, toon shading, fog and music.

@export var id: StringName
@export_group("Sky")
@export var sky_top: Color = Color(0.12, 0.36, 0.86)
@export var sky_mid: Color = Color(0.35, 0.66, 0.98)
@export var sky_horizon: Color = Color(0.82, 0.93, 1.0)
@export var ground_bottom: Color = Color(0.45, 0.7, 0.95)
@export_group("Light")
@export var sun_color: Color = Color(1.0, 0.96, 0.88)
@export var sun_energy: float = 1.2
@export var sun_rotation_degrees: Vector3 = Vector3(-50, -35, 0)
## Flat ambient added everywhere (keeps shadows coloured and readable).
@export var ambient_color: Color = Color(0.55, 0.65, 0.95)
@export var ambient_energy: float = 0.45
@export_group("Toon")
## Multiplies the sunlight in the shadow band (cool tint = vivid shadows).
@export var shadow_color: Color = Color(0.42, 0.45, 0.78)
@export var rim_color: Color = Color(1.0, 0.97, 0.9)
@export_range(0.005, 0.2) var band_softness: float = 0.035
@export_group("Atmosphere")
@export var fog_color: Color = Color(0.72, 0.86, 0.98)
## Depth fog: crisp play space, aerial perspective only on distant scenery.
@export var fog_begin: float = 45.0
@export var fog_end: float = 260.0
@export_range(0.0, 1.0) var fog_max: float = 0.75
## Tint of the cloud sea under the islands.
@export var cloud_color: Color = Color(1, 1, 1)
@export var cloud_shadow: Color = Color(0.7, 0.78, 0.98)
@export_group("Audio")
@export var music_id: StringName = &"isles"
