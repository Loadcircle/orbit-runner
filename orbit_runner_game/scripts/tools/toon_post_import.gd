@tool
extends EditorScenePostImport
## Converts imported glTF materials to Godot's built-in toon shading so every
## Blender asset shares the cel-shaded look without custom shaders.
## Registered as the default scene import script in project.godot.

const RIM_AMOUNT := 0.22
const RIM_TINT := 0.6


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
	elif node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is StandardMaterial3D:
				node.mesh.surface_set_material(i, _toon(material, converted))
	for child in node.get_children():
		_convert(child, converted)


func _toon(material: StandardMaterial3D, converted: Dictionary) -> StandardMaterial3D:
	if converted.has(material):
		return converted[material]
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if material.metallic < 0.5:
		material.metallic = 0.0
		material.metallic_specular = 0.25
	material.roughness = maxf(material.roughness, 0.55)
	material.rim_enabled = true
	material.rim = RIM_AMOUNT
	material.rim_tint = RIM_TINT
	converted[material] = material
	return material
