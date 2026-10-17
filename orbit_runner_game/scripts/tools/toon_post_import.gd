@tool
extends EditorScenePostImport
## Converts imported glTF materials to the shared Orbit Runner toon shader
## (resources/shaders/toon.gdshader) so every Blender asset gets the same
## cel-shaded look, coloured shadows and rim. Materials named M_Outline* become
## flat ink for the inverted-hull outline shells.
## Registered as the default scene import script in project.godot.

const ToonMaterialsScript := preload("res://scripts/rendering/toon_materials.gd")


func _post_import(scene: Node) -> Object:
	var converted := {}
	_convert(scene, converted)
	return scene


func _convert(node: Node, converted: Dictionary) -> void:
	if node is ImporterMeshInstance3D:
		var mesh: ImporterMesh = node.mesh
		if mesh:
			for i in mesh.get_surface_count():
				var material := mesh.get_surface_material(i)
				if material is StandardMaterial3D:
					mesh.set_surface_material(i, _toon(material, converted))
			if _is_outline_only(mesh):
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				node.mesh.surface_set_material(i, _toon(material, converted))
	for child in node.get_children():
		_convert(child, converted)


func _toon(material: StandardMaterial3D, converted: Dictionary) -> Material:
	if not converted.has(material):
		converted[material] = ToonMaterialsScript.from_standard(material)
	return converted[material]


func _is_outline_only(mesh: ImporterMesh) -> bool:
	for i in mesh.get_surface_count():
		var material := mesh.get_surface_material(i)
		if material == null or not material.resource_name.begins_with(ToonMaterialsScript.OUTLINE_PREFIX):
			return false
	return mesh.get_surface_count() > 0
