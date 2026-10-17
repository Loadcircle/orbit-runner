"""Shared helpers for Orbit Runner Blender asset scripts.

Conventions (see ../PARAMETROS_ASSETS_ORBIT_RUNNER.md):
- 1 Blender unit = 1 metre, Z up, asset front faces +Y (=> -Z in Godot).
- Editable modifiers stay in the .blend; the GLB export applies them.
- Flat Principled materials (glTF Metallic-Roughness friendly) + a "Col" vertex
  colour attribute that Godot's toon shader multiplies into the albedo.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLEND_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
GAME_DIR = os.path.normpath(os.path.join(BLEND_DIR, "..", ".."))
MODELS_DIR = os.path.join(GAME_DIR, "art", "models")

# Functional palette (sRGB hex). Colour is never the only signal: shapes,
# stripes and animation reinforce each function.
PALETTE = {
    # v2 "vivid" palette (2026-10-17): saturated hues, strong value steps.
    "grass": "#4cb83a", "grass_light": "#86d24a", "grass_dark": "#25863a", "stone": "#efe0c4",
    "stone_dark": "#b49577", "cliff": "#f0a35e", "cliff_dark": "#b8603a", "rock": "#9a5236",
    "dirt": "#8b5e3c", "wood": "#a8642e", "leaf": "#38b048", "leaf_light": "#7cd04a", "leaf_dark": "#1c7a40",
    "impulse": "#ffd21f", "impulse_dark": "#ff7a1a", "temp": "#29d4ff", "temp_dark": "#2a5cff",
    "hazard": "#ff2d9a", "hazard_dark": "#8a1fe0", "hazard_red": "#8e1f3a",
    "yoyo": "#22e0f0", "yoyo_accent": "#ff8a1e", "yoyo_core": "#f4fbff",
    "metal": "#9fb2c8", "metal_dark": "#4b5a73", "cream": "#fff3d6", "toy_red": "#ff4646",
    "toy_yellow": "#ffc61a", "toy_blue": "#2f7bff", "toy_teal": "#16c9b4", "toy_purple": "#9b5cff",
    "sand": "#f4e3c6", "sandstone": "#e0814e", "sandstone_dark": "#a64a30",
    "gold": "#ffbf2e", "turquoise": "#1fd6c4", "white": "#f6f7f9", "dark": "#262b45",
    "ink": "#1b1f3a", "glow": "#5ff4ff", "cloud": "#ffffff",
}


COLOR_ATTR = "Col"


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(value, alpha=1.0):
    value = PALETTE.get(value, value).lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), alpha)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 30
    return scene


def material(name, color, roughness=0.75, metallic=0.0, emission=None, emission_strength=1.5, vcol=False):
    """Flat Principled material. Godot's toon shader multiplies the albedo by
    the "Col" vertex attribute; vcol=True shows that in Blender too (use a
    white base colour so the vertex colours carry the hue)."""
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if vcol:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = COLOR_ATTR
        links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    if not vcol:
        bsdf.inputs["Base Color"].default_value = hex_rgba(color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = hex_rgba(emission)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    mat.diffuse_color = hex_rgba(color)
    return mat


def collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


_ACTIVE_COLLECTION = [None]


def use_collection(name):
    _ACTIVE_COLLECTION[0] = collection(name)
    return _ACTIVE_COLLECTION[0]


def _link(obj):
    col = _ACTIVE_COLLECTION[0] or bpy.context.scene.collection
    col.objects.link(obj)
    return obj


def _mesh_object(name, bm, mat, smooth):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    if mat is not None:
        mesh.materials.append(mat)
    return _link(obj)


def _place(obj, loc, rot, scale):
    obj.location = Vector(loc)
    obj.rotation_euler = tuple(math.radians(a) for a in rot)
    obj.scale = scale
    return obj


def add_bevel(obj, width, segments=2, harden=True):
    if width <= 0:
        return obj
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = harden
    return obj


def box(name, size, loc=(0, 0, 0), mat=None, bevel=0.04, segments=2, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    obj = _mesh_object(name, bm, mat, smooth=bevel > 0)
    add_bevel(obj, min(bevel, min(size) * 0.45), segments)
    return _place(obj, loc, rot, (1, 1, 1))


def cylinder(name, radius, depth, loc=(0, 0, 0), mat=None, verts=20, rot=(0, 0, 0), radius_top=None,
             bevel=0.0, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=depth)
    obj = _mesh_object(name, bm, mat, smooth)
    if bevel > 0:
        add_bevel(obj, bevel, 2)
    elif smooth:
        smooth_by_angle(obj)
    return _place(obj, loc, rot, (1, 1, 1))


def cone(name, radius, depth, loc=(0, 0, 0), mat=None, verts=12, rot=(0, 0, 0), smooth=False):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=verts, radius1=radius, radius2=0.0,
                          depth=depth)
    obj = _mesh_object(name, bm, mat, smooth)
    return _place(obj, loc, rot, (1, 1, 1))


def sphere(name, radius, loc=(0, 0, 0), mat=None, segments=20, rings=12, scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    obj = _mesh_object(name, bm, mat, smooth=True)
    return _place(obj, loc, rot, scale)


def ico(name, radius, loc=(0, 0, 0), mat=None, subdivisions=1, scale=(1, 1, 1), rot=(0, 0, 0), smooth=False):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    obj = _mesh_object(name, bm, mat, smooth)
    return _place(obj, loc, rot, scale)


def torus(name, major, minor, loc=(0, 0, 0), mat=None, major_segments=28, minor_segments=10, rot=(0, 0, 0)):
    bm = bmesh.new()
    for i in range(major_segments):
        a = 2 * math.pi * i / major_segments
        for j in range(minor_segments):
            b = 2 * math.pi * j / minor_segments
            r = major + minor * math.cos(b)
            bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b)))
    bm.verts.ensure_lookup_table()
    for i in range(major_segments):
        for j in range(minor_segments):
            a = i * minor_segments + j
            b = ((i + 1) % major_segments) * minor_segments + j
            c = ((i + 1) % major_segments) * minor_segments + (j + 1) % minor_segments
            d = i * minor_segments + (j + 1) % minor_segments
            bm.faces.new((bm.verts[a], bm.verts[b], bm.verts[c], bm.verts[d]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _mesh_object(name, bm, mat, smooth=True)
    return _place(obj, loc, rot, (1, 1, 1))


def prism(name, points, height, loc=(0, 0, 0), mat=None, rot=(0, 0, 0), bevel=0.0):
    """Extrude a 2D polygon (XY, counter-clockwise) along +Z."""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, 0.0)) for x, y in points]
    top = [bm.verts.new((x, y, height)) for x, y in points]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    n = len(points)
    for i in range(n):
        bm.faces.new((bottom[i], bottom[(i + 1) % n], top[(i + 1) % n], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _mesh_object(name, bm, mat, smooth=bevel > 0)
    add_bevel(obj, bevel, 2)
    return _place(obj, loc, rot, (1, 1, 1))


def rock_blob(name, radius, loc, mat, seed=0, squash=(1.0, 1.0, 0.7), rot=(0, 0, 0)):
    """Low-poly stylised rock: icosphere with deterministic jitter."""
    import random
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    for v in bm.verts:
        v.co *= 1.0 + rng.uniform(-0.18, 0.18)
        v.co.x *= squash[0]
        v.co.y *= squash[1]
        v.co.z *= squash[2]
    obj = _mesh_object(name, bm, mat, smooth=False)
    return _place(obj, loc, rot, (1, 1, 1))


def island_underside(name, top_size, depth, loc, mat, seed=0, segments=10):
    """Tapered rocky underside for a floating island (top at local z=0)."""
    import random
    rng = random.Random(seed)
    sx, sy = top_size[0] * 0.5, top_size[1] * 0.5
    bm = bmesh.new()
    rings = [(0.0, 1.0), (-depth * 0.35, 0.86), (-depth * 0.7, 0.55), (-depth, 0.18)]
    ring_verts = []
    for z, f in rings:
        verts = []
        for i in range(segments):
            a = 2 * math.pi * i / segments + math.pi / segments
            jitter = 1.0 if z == 0.0 else 1.0 + rng.uniform(-0.12, 0.1)
            # Superellipse so the top outline stays close to the rectangular walkable area.
            ca, sa = math.cos(a), math.sin(a)
            px = math.copysign(abs(ca) ** 0.45, ca) * sx * f * jitter
            py = math.copysign(abs(sa) ** 0.45, sa) * sy * f * jitter
            verts.append(bm.verts.new((px, py, z)))
        ring_verts.append(verts)
    bm.faces.new(ring_verts[0])
    for r in range(len(ring_verts) - 1):
        a_ring, b_ring = ring_verts[r], ring_verts[r + 1]
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((a_ring[i], b_ring[i], b_ring[j], a_ring[j]))
    tip = bm.verts.new((0, 0, -depth * 1.2))
    last = ring_verts[-1]
    for i in range(segments):
        bm.faces.new((last[i], tip, last[(i + 1) % segments]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _mesh_object(name, bm, mat, smooth=False)
    return _place(obj, loc, (0, 0, 0), (1, 1, 1))


def smooth_by_angle(obj, angle_deg=40.0):
    mesh = obj.data
    if hasattr(mesh, "set_sharp_from_angle"):
        mesh.set_sharp_from_angle(angle=math.radians(angle_deg))


def parent(child, parent_obj, keep_transform=True):
    bpy.context.view_layer.update()
    matrix = child.matrix_world.copy()
    child.parent = parent_obj
    if keep_transform:
        child.matrix_parent_inverse = parent_obj.matrix_world.inverted()
        child.matrix_world = matrix
    return child


def empty(name, loc=(0, 0, 0), rot=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    _link(obj)
    return _place(obj, loc, rot, (1, 1, 1))


def apply_object_transforms(objs):
    for obj in objs:
        if obj.type != "MESH" or obj.data.users > 1:
            continue
        mat = obj.matrix_basis.copy()
        if obj.parent is None:
            obj.data.transform(mat)
            obj.matrix_basis = Matrix.Identity(4)


def join(objs, name):
    """Apply modifiers and join meshes into one object (uses standard operators)."""
    ensure_colors(objs)  # parts without colours would turn black when joined
    bpy.context.view_layer.update()
    for obj in objs:
        for mod in list(obj.modifiers):
            with bpy.context.temp_override(object=obj, active_object=obj):
                bpy.ops.object.modifier_apply(modifier=mod.name)
    target = objs[0]
    with bpy.context.temp_override(active_object=target, selected_objects=objs,
                                   selected_editable_objects=objs):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


def triangle_count(objs):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in objs:
        if obj.type != "MESH":
            continue
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        eval_obj.to_mesh_clear()
    return total


# ---------------------------------------------------------------- vertex colour

def _color_attr(mesh):
    attr = mesh.color_attributes.get(COLOR_ATTR)
    if attr is None:
        attr = mesh.color_attributes.new(COLOR_ATTR, "FLOAT_COLOR", "CORNER")
    mesh.color_attributes.active_color = attr
    mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(attr)
    return attr


def paint(obj, color="#ffffff", bottom=None, z_range=None, jitter=0.0, seed=0, fn=None):
    """Writes the "Col" attribute (linear RGBA) on every face corner.

    color/bottom: hex or palette keys; with `bottom` the colour blends from
    bottom (z_range[0]) to color (z_range[1]) in object space. jitter varies
    the value per face (cheap hand-painted look). fn(co, normal) -> factor
    multiplies the result (AO, edge darkening...).
    """
    import random
    rng = random.Random(seed)
    mesh = obj.data
    attr = _color_attr(mesh)
    top_c = Vector(hex_rgba(color)[:3])
    bot_c = Vector(hex_rgba(bottom)[:3]) if bottom else top_c
    if z_range is None:
        zs = [v.co.z for v in mesh.vertices] or [0.0]
        z_range = (min(zs), max(zs))
    span = max(z_range[1] - z_range[0], 1e-5)
    for poly in mesh.polygons:
        k = 1.0 + rng.uniform(-jitter, jitter)
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            t = min(max((co.z - z_range[0]) / span, 0.0), 1.0)
            c = bot_c.lerp(top_c, t) * k
            if fn is not None:
                c = c * fn(co, poly.normal)
            attr.data[li].color = (c.x, c.y, c.z, 1.0)
    return obj


def ensure_colors(objs):
    """Meshes without "Col" get white so every GLB primitive has COLOR_0."""
    for obj in objs:
        if obj.type == "MESH" and obj.data.color_attributes.get(COLOR_ATTR) is None:
            paint(obj, "#ffffff")


def outline_shell(obj, thickness, mat, name=None):
    """Inverted-hull outline: a copy pushed along the normals with flipped
    faces. Back-face culling shows only the rim, so it needs no extra pass.
    Built from the evaluated mesh (modifiers included)."""
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    bm = bmesh.new()
    bm.from_mesh(eval_obj.to_mesh())
    eval_obj.to_mesh_clear()
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * thickness
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = 0
    shell = _mesh_object(name or (obj.name + "_Outline"), bm, mat, smooth=True)
    shell.matrix_world = obj.matrix_world.copy()
    if obj.parent:
        parent(shell, obj.parent)
    paint(shell, "#ffffff")
    return shell


def superellipse(sx, sy, n, power=0.35, scale=1.0, jitter=0.0, rng=None, phase=0.0):
    """Points of a rounded-rectangle outline (half sizes sx, sy)."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n + phase
        ca, sa = math.cos(a), math.sin(a)
        j = 1.0 + (rng.uniform(-jitter, jitter) if rng and jitter else 0.0)
        pts.append((math.copysign(abs(ca) ** power, ca) * sx * scale * j,
                    math.copysign(abs(sa) ** power, sa) * sy * scale * j))
    return pts


def loft(name, rings, mat, cap_top=True, tip=None, smooth=False):
    """Stacks closed rings [(points[(x, y)], z), ...] (top first) into a mesh.
    cap_top adds a fan cap on the first ring; tip=(x, y, z) closes the bottom."""
    bm = bmesh.new()
    verts = [[bm.verts.new((x, y, z)) for x, y in pts] for pts, z in rings]
    n = len(verts[0])
    if cap_top:
        zc = rings[0][1]
        center = bm.verts.new((sum(p[0] for p in rings[0][0]) / n, sum(p[1] for p in rings[0][0]) / n, zc))
        for i in range(n):
            bm.faces.new((center, verts[0][i], verts[0][(i + 1) % n]))
    for r in range(len(verts) - 1):
        a, b = verts[r], verts[r + 1]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], b[i], b[j], a[j]))
    if tip is not None:
        t = bm.verts.new(tip)
        last = verts[-1]
        for i in range(n):
            bm.faces.new((last[i], t, last[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _mesh_object(name, bm, mat, smooth)


def save_and_export(asset_name, export_animations=False):
    """Save the editable .blend and export a GLB of the whole scene."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    blend_path = os.path.join(BLEND_DIR, asset_name + ".blend")
    glb_path = os.path.join(MODELS_DIR, asset_name + ".glb")
    objs = [o for o in bpy.context.scene.objects]
    ensure_colors(objs)
    tris = triangle_count(objs)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=True)
    kwargs = dict(
        filepath=glb_path,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=export_animations,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
    )
    if export_animations:
        kwargs.update(export_animation_mode="ACTIONS", export_force_sampling=True, export_skins=True,
                      export_def_bones=True)
    bpy.ops.export_scene.gltf(**kwargs)
    return {"asset": asset_name, "triangles": tris, "blend": blend_path, "glb": glb_path}
