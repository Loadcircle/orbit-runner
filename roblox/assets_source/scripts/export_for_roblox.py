"""Exporta assets de Orbit Runner a datos de malla listos para Roblox (EditableMesh).

Se ejecuta con Blender en segundo plano sobre los .blend del juego, que se abren SOLO
en lectura (nunca se guardan). Para cada asset:
  1. quita los contornos de casco invertido (material M_Outline / objetos *Outline);
  2. aplica modificadores y triangula;
  3. convierte ejes Blender (Z arriba) -> Roblox/Godot (Y arriba, adelante -Z), como el
     exportador glTF: (x, y, z) -> (x, z, -y), y escala x K (3.5 studs/m);
  4. separa las piezas que se animan en Godot (brazo del spinner, parche del trampolín,
     bandera, halo, rotor, losetas...) con su pivote; el resto se une en "Body";
  5. agrupa las caras por apariencia: "Solid" (color por vértice) y "Glow" (materiales
     emisivos, que en Roblox se ven con material Neon y el color medio del grupo);
  6. guarda colores por esquina en sRGB y normales por esquina (sombreado plano/toon).

Salida: roblox/assets_source/meshes/<ASSET>.json (generado; ver .gitignore).

Uso:
  blender --background --factory-startup --python export_for_roblox.py -- <src_dir> <out_dir> [ASSET ...]
"""
import bpy
import json
import math
import os
import sys

K = 3.5

PHASE1_ASSETS = [
    "PLAT_Isle_S", "PLAT_Isle_M", "PLAT_Isle_L", "PLAT_Isle_XL", "PLAT_Isle_Strip", "PLAT_Isle_Wide",
    "PLAT_Moving", "PLAT_Timed", "PLAT_Crumble",
    "PROP_Trampoline", "PROP_BoostPad", "PROP_WindRing", "PROP_Checkpoint", "PROP_GoalGate",
    "PROP_Yoyo", "PROP_YoyoDisc", "PROP_Gem", "PROP_Spark",
    "HAZ_Spinner", "HAZ_PatrolBot", "HAZ_LaserPost",
    "ENV_Tree", "ENV_Pine",
]

# Piezas que se animan por separado en Godot (nombre del objeto raíz de la pieza).
DYNAMIC = {
    "PROP_Trampoline": ["Pad"],
    "PROP_WindRing": ["Rotor"],
    "PROP_Checkpoint": ["Flag"],
    "PROP_GoalGate": ["Halo"],
    "HAZ_Spinner": ["Arm"],
    "PLAT_Crumble": ["Tile_*"],
}


def is_outline(obj):
    if obj.name.lower().endswith("outline"):
        return True
    return any(slot.material and slot.material.name.startswith("M_Outline") for slot in obj.material_slots)


def is_glow(material):
    """Material emisivo (Emission Strength > 0 en el Principled BSDF)."""
    if material is None or not material.use_nodes:
        return False
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            strength = node.inputs.get("Emission Strength")
            color = node.inputs.get("Emission Color") or node.inputs.get("Emission")
            if strength is not None and strength.default_value > 0.01 and color is not None:
                c = color.default_value
                if max(c[0], c[1], c[2]) > 0.01:
                    return True
    return False


def linear_to_srgb(value):
    if value <= 0.0031308:
        return 12.92 * value
    return 1.055 * (value ** (1 / 2.4)) - 0.055


def to_roblox(v):
    return (v[0] * K, v[2] * K, -v[1] * K)


def matches(name, patterns):
    for pattern in patterns:
        if pattern.endswith("*") and name.startswith(pattern[:-1]):
            return True
        if name == pattern:
            return True
    return False


def dynamic_root(obj, patterns):
    """Objeto raíz de pieza dinámica al que pertenece `obj` (él mismo o un ancestro)."""
    current = obj
    while current is not None:
        if matches(current.name, patterns):
            return current
        current = current.parent
    return None


def round_list(values, digits=4):
    return [round(v, digits) for v in values]


def export_asset(src_dir, out_dir, asset):
    path = os.path.join(src_dir, asset + ".blend")
    if not os.path.exists(path):
        return {"asset": asset, "error": "no existe " + path}
    bpy.ops.wm.open_mainfile(filepath=path)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    patterns = DYNAMIC.get(asset, [])
    groups = {}  # nombre de pieza -> {pivot, mesh data}
    removed = []

    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if is_outline(obj):
            removed.append(obj.name)
            continue
        root = dynamic_root(obj, patterns)
        part_name = root.name if root else "Body"
        pivot_world = root.matrix_world.translation if root else None
        pivot = to_roblox(pivot_world) if pivot_world is not None else (0.0, 0.0, 0.0)
        group = groups.setdefault(part_name, {"pivot": pivot, "positions": [], "pos_index": {},
                                              "colors": [], "color_index": {}, "normals": [],
                                              "normal_index": {}, "faces": {"Solid": [], "Glow": []}})

        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()  # triangulación sin modificar la malla
        color_attr = mesh.color_attributes.active_color or (mesh.color_attributes[0] if mesh.color_attributes else None)
        matrix = obj.matrix_world
        normal_matrix = matrix.to_3x3().inverted_safe().transposed()

        def add(table, index, key, value):
            if key not in index:
                index[key] = len(table)
                table.append(value)
            return index[key]

        for tri in mesh.loop_triangles:
            material = obj.material_slots[tri.material_index].material if obj.material_slots else None
            kind = "Glow" if is_glow(material) else "Solid"
            corner_pos, corner_col, corner_nor = [], [], []
            for loop_index, vertex_index in zip(tri.loops, tri.vertices):
                world = matrix @ mesh.vertices[vertex_index].co
                p = to_roblox(world)
                p = (p[0] - pivot[0], p[1] - pivot[1], p[2] - pivot[2])
                key = tuple(round(c, 4) for c in p)
                corner_pos.append(add(group["positions"], group["pos_index"], key, list(key)))
                if color_attr is not None:
                    if color_attr.domain == "CORNER":
                        c = color_attr.data[loop_index].color
                    else:
                        c = color_attr.data[vertex_index].color
                    srgb = tuple(round(linear_to_srgb(max(0.0, min(1.0, c[i]))), 3) for i in range(3))
                else:
                    srgb = (1.0, 1.0, 1.0)
                corner_col.append(add(group["colors"], group["color_index"], srgb, list(srgb)))
                n = normal_matrix @ mesh.corner_normals[loop_index].vector
                n = n.normalized()
                rn = (round(n[0], 3), round(n[2], 3), round(-n[1], 3))
                corner_nor.append(add(group["normals"], group["normal_index"], rn, list(rn)))
            group["faces"][kind].append(corner_pos + corner_col + corner_nor)
        evaluated.to_mesh_clear()

    parts = {}
    total = 0
    for name, group in groups.items():
        for kind in ("Solid", "Glow"):
            faces = group["faces"][kind]
            if not faces:
                continue
            total += len(faces)
            parts[name + ("" if kind == "Solid" else "_Glow")] = {
                "pivot": round_list(group["pivot"]),
                "kind": kind,
                "positions": group["positions"],
                "colors": group["colors"],
                "normals": group["normals"],
                # cada cara: 3 índices de posición, 3 de color y 3 de normal (base 0)
                "faces": faces,
            }
    data = {"asset": asset, "scale": K, "parts": parts}
    with open(os.path.join(out_dir, asset + ".json"), "w", encoding="utf-8") as handle:
        json.dump(data, handle, separators=(",", ":"))
    return {"asset": asset, "parts": {k: len(v["faces"]) for k, v in parts.items()}, "triangles": total,
            "outlines_removed": removed}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src_dir, out_dir = argv[0], argv[1]
    assets = argv[2:] or PHASE1_ASSETS
    os.makedirs(out_dir, exist_ok=True)
    report = []
    for asset in assets:
        try:
            report.append(export_asset(src_dir, out_dir, asset))
        except Exception as error:  # se informa y se sigue con el resto
            report.append({"asset": asset, "error": repr(error)})
    with open(os.path.join(out_dir, "_report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=1)


main()
