class_name ToonMaterials
extends RefCounted
## Builds and edits the shared toon ShaderMaterials (resources/shaders/).
## The GLB import script converts every glTF material with `from_standard`;
## gameplay code recolours or swaps variants through the helpers below so the
## shader parameter names live in one place.

const TOON := preload("res://resources/shaders/toon.gdshader")
const FADE := preload("res://resources/shaders/toon_fade.gdshader")
const GHOST := preload("res://resources/shaders/toon_ghost.gdshader")
const OUTLINE := preload("res://resources/shaders/toon_outline.gdshader")
const OUTLINE_PREFIX := "M_Outline"
## Skin keeps a warm shadow so it never turns grey under a cool biome tint.
const WARM_SHADOW := {"M_Skin": Color(0.95, 0.55, 0.5, 0.85)}


static func from_standard(source: StandardMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.resource_name = source.resource_name
	if source.resource_name.begins_with(OUTLINE_PREFIX):
		mat.shader = OUTLINE
		mat.set_shader_parameter("albedo", source.albedo_color)
		return mat
	mat.shader = TOON
	mat.set_shader_parameter("albedo", source.albedo_color)
	mat.set_shader_parameter("roughness", source.roughness)
	# Every Orbit Runner GLB carries a "Col" (COLOR_0) attribute; white when unused.
	mat.set_shader_parameter("use_vertex_color", true)
	if source.emission_enabled:
		mat.set_shader_parameter("emission", source.emission)
		mat.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
	# Glossy look for smooth or metallic surfaces (plastic toys, metal, gems).
	var gloss := clampf((0.6 - source.roughness) / 0.4, 0.0, 1.0)
	if source.metallic > 0.5:
		gloss = maxf(gloss, 0.6)
	mat.set_shader_parameter("gloss", gloss)
	if WARM_SHADOW.has(source.resource_name):
		mat.set_shader_parameter("shadow_override", WARM_SHADOW[source.resource_name])
		mat.set_shader_parameter("rim_amount", 0.25)
	return mat


static func is_toon(material: Material) -> bool:
	return material is ShaderMaterial and (material as ShaderMaterial).shader in [TOON, FADE, GHOST]


## Copy of `material` with a new base colour (emissive materials glow in it too).
static func recolored(material: Material, color: Color) -> Material:
	if material is ShaderMaterial:
		var mat := material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("albedo", color)
		var energy: Variant = mat.get_shader_parameter("emission_energy")  # null when left at default
		if energy != null and float(energy) > 0.0:
			mat.set_shader_parameter("emission", color)
		return mat
	if material is StandardMaterial3D:
		var std := material.duplicate() as StandardMaterial3D
		std.albedo_color = color
		if std.emission_enabled:
			std.emission = color
		return std
	return material


## Copy of a toon material using another shader variant (FADE or GHOST).
static func variant(material: Material, shader: Shader) -> Material:
	if not is_toon(material):
		return material
	var mat := material.duplicate() as ShaderMaterial
	mat.shader = shader
	return mat


## Applies `shader` to every toon surface under `root` (shared per source material).
static func apply_variant(root: Node, shader: Shader, cache := {}) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var base := mesh_instance.get_active_material(i)
			if not is_toon(base):
				continue
			if not cache.has(base):
				cache[base] = variant(base, shader)
			mesh_instance.set_surface_override_material(i, cache[base])
