class_name ShaderWarmup
extends RefCounted
## Pre-compiles every shader/material combination a level can show, while the
## scene-change fade still covers the screen. The Compatibility (OpenGL)
## renderer compiles a shader the first time it is drawn, which causes a hitch;
## this includes things hidden at start (yo-yo disc, string, particle bursts).
##
## Each unique mesh/material set is drawn once, tiny, just in front of the
## camera (keeping its shadow setting so shadow variants compile too), and the
## particle systems emit once; after a few frames everything is removed.

const FRAMES := 3
const DISTANCE := 2.0
const SIZE := 0.03


static func run(root: Node, camera: Camera3D) -> void:
	if camera == null or not root.is_inside_tree():
		return
	var holder := Node3D.new()
	holder.name = "ShaderWarmup"
	camera.add_child(holder)
	holder.position = Vector3(0, 0, -DISTANCE)
	var seen := {}
	var count := 0
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node == holder or holder.is_ancestor_of(node):
			continue
		if node is MeshInstance3D:
			var source := node as MeshInstance3D
			# Skinned meshes (the protagonist) are on screen from the first frame.
			if source.mesh == null or source.skin != null:
				continue
			var key := _key(source)
			if seen.has(key):
				continue
			seen[key] = true
			holder.add_child(_copy_mesh(source, count))
			count += 1
		elif node is CPUParticles3D:
			var particles := (node as CPUParticles3D).duplicate() as CPUParticles3D
			particles.emitting = false
			holder.add_child(particles)
			particles.one_shot = true
			particles.local_coords = true
			particles.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * SIZE * 4.0), _slot(count))
			particles.emitting = true
			count += 1
	for i in FRAMES:
		await RenderingServer.frame_post_draw
	if is_instance_valid(holder):
		holder.queue_free()


static func _copy_mesh(source: MeshInstance3D, index: int) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.mesh = source.mesh
	for i in source.get_surface_override_material_count():
		copy.set_surface_override_material(i, source.get_surface_override_material(i))
	copy.material_override = source.material_override
	copy.material_overlay = source.material_overlay
	copy.transparency = source.transparency
	copy.cast_shadow = source.cast_shadow
	var aabb := source.mesh.get_aabb()
	var k := SIZE / maxf(aabb.get_longest_axis_size(), 0.01)
	copy.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), _slot(index) - aabb.get_center() * k)
	return copy


## Lays copies out on a small grid so none of them is fully hidden.
static func _slot(index: int) -> Vector3:
	return Vector3((index % 12 - 5.5) * SIZE * 1.3, (index / 12 - 3.0) * SIZE * 1.3, 0.0)


static func _key(mi: MeshInstance3D) -> String:
	var parts := PackedStringArray([str(mi.mesh.get_rid().get_id())])
	for i in mi.get_surface_override_material_count():
		var m := mi.get_surface_override_material(i)
		parts.append(str(m.get_rid().get_id()) if m else "-")
	for m in [mi.material_override, mi.material_overlay]:
		parts.append(str(m.get_rid().get_id()) if m else "-")
	parts.append(str(mi.transparency > 0.0))
	return ":".join(parts)
