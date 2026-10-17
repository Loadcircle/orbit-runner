"""Builds the protagonist (CHR_Adventurer) and the kinetic yo-yo assets.

  blender --background --factory-startup --python build_character.py -- [CHR_Adventurer|PROP_Yoyo|PROP_YoyoDisc|ALL]

v2 (2026-10-17): chibi-heroic proportions (big head, big hands and shoes),
modelled face with layered eyes, brows, open smile and blush, chunky swept
hair, goggles on the forehead and a blinking eye bone. Body parts are still
rigidly weighted (100 % per bone, like a toy figure): crisp silhouettes and a
cheap rig on mobile. Faces +Y in Blender (=> -Z in Godot); origin between the
feet. Bones use roll so local +Z points forward (+Y): a positive X rotation
swings the bone tip forward; positive Z swings left-side limbs outward.

Material names are part of the cosmetics contract (cosmetic_catalog.tres):
M_Hair, M_Jacket, M_Accent, M_Teal, M_Pants, M_Yoyo, M_YoyoAccent, M_DiscCyan.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import or_common as C  # noqa: E402

FPS = 30
HEAD_C = Vector((0.0, 0.0, 1.2))
HEAD_R = 0.27
HEAD_SCALE = Vector((1.05, 0.98, 0.96))

# name: (head, tail, parent, roll_axis)
BONES = {
    "root": ((0, 0, 0), (0, 0, 0.25), None, (0, 1, 0)),
    "hips": ((0, 0, 0.56), (0, 0, 0.66), "root", (0, 1, 0)),
    "spine": ((0, 0, 0.66), (0, 0, 0.93), "hips", (0, 1, 0)),
    "head": ((0, 0, 0.95), (0, 0, 1.45), "spine", (0, 1, 0)),
    "eyes": ((0, 0.2, 1.18), (0, 0.2, 1.28), "head", (0, 1, 0)),
    "upper_arm.L": ((-0.25, 0, 0.88), (-0.29, 0, 0.72), "spine", (0, 1, 0)),
    "forearm.L": ((-0.29, 0, 0.72), (-0.31, 0, 0.57), "upper_arm.L", (0, 1, 0)),
    "hand.L": ((-0.31, 0, 0.57), (-0.31, 0, 0.47), "forearm.L", (0, 1, 0)),
    "upper_arm.R": ((0.25, 0, 0.88), (0.29, 0, 0.72), "spine", (0, 1, 0)),
    "forearm.R": ((0.29, 0, 0.72), (0.31, 0, 0.57), "upper_arm.R", (0, 1, 0)),
    "hand.R": ((0.31, 0, 0.57), (0.31, 0, 0.47), "forearm.R", (0, 1, 0)),
    "thigh.L": ((-0.1, 0, 0.56), (-0.1, 0, 0.34), "hips", (0, 1, 0)),
    "shin.L": ((-0.1, 0, 0.34), (-0.1, 0, 0.12), "thigh.L", (0, 1, 0)),
    "foot.L": ((-0.1, 0, 0.12), (-0.1, 0.17, 0.05), "shin.L", (0, 0, 1)),
    "thigh.R": ((0.1, 0, 0.56), (0.1, 0, 0.34), "hips", (0, 1, 0)),
    "shin.R": ((0.1, 0, 0.34), (0.1, 0, 0.12), "thigh.R", (0, 1, 0)),
    "foot.R": ((0.1, 0, 0.12), (0.1, 0.17, 0.05), "shin.R", (0, 0, 1)),
}


def make_armature():
    arm_data = bpy.data.armatures.new("SK_Adventurer")
    arm_obj = bpy.data.objects.new("SK_Adventurer", arm_data)
    C._link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    with bpy.context.temp_override(active_object=arm_obj, object=arm_obj):
        bpy.ops.object.mode_set(mode="EDIT")
        for name, (head, tail, parent_name, roll_axis) in BONES.items():
            eb = arm_data.edit_bones.new(name)
            eb.head = head
            eb.tail = tail
            eb.align_roll(Vector(roll_axis))
        for name, (_h, _t, parent_name, _r) in BONES.items():
            if parent_name:
                arm_data.edit_bones[name].parent = arm_data.edit_bones[parent_name]
        bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def weight(obj, bone):
    vg = obj.vertex_groups.new(name=bone)
    vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    return obj


# ---------------------------------------------------------------- shape helpers

def capsule(name, radius, length, loc, mat, rot=(0, 0, 0), scale=(1, 1, 1), segments=14, rings=10, radius_top=None):
    """Capsule along local Z (length = distance between the cap centres)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    half = length * 0.5
    for v in bm.verts:
        if radius_top is not None and v.co.z > 1e-5:
            k = radius_top / radius
            v.co.x *= k
            v.co.y *= k
            v.co.z *= k
        v.co.z += half if v.co.z > 1e-5 else -half
    obj = C._mesh_object(name, bm, mat, smooth=True)
    return C._place(obj, loc, rot, scale)


def rounded(name, size, loc, mat, radius=None, rot=(0, 0, 0)):
    """Soft toy-like box: big bevel, three segments, smooth shading."""
    r = radius if radius is not None else min(size) * 0.42
    return C.box(name, size, loc, mat, bevel=r, segments=3, rot=rot)


def look_rot(direction):
    """Euler that turns local +Z towards `direction`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_euler()


def face_rot(az, el, roll=0.0):
    """Euler (degrees) turning local +Y to the head direction (az, el)."""
    return (el, roll, -az)


def head_dir(az, el):
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))


def head_point(az, el, offset=0.0):
    d = head_dir(az, el)
    p = Vector((d.x * HEAD_SCALE.x, d.y * HEAD_SCALE.y, d.z * HEAD_SCALE.z)) * HEAD_R
    return HEAD_C + p + d * offset


def hair_cap(name, mat):
    """Head-hugging hair shell with the face cut out."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=HEAD_R * 1.07)
    doomed = []
    for v in bm.verts:
        n = v.co.normalized()
        # Face window: front, below the hairline; sideburns stay.
        if n.y > 0.25 and n.z < 0.42 - 0.25 * abs(n.x):
            doomed.append(v)
        elif n.z < -0.25 and n.y > -0.55:
            doomed.append(v)
        elif n.z < -0.55:
            doomed.append(v)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    for v in bm.verts:
        v.co.x *= HEAD_SCALE.x * 1.02
        v.co.y *= HEAD_SCALE.y
        v.co.z *= HEAD_SCALE.z
    obj = C._mesh_object(name, bm, mat, smooth=True)
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = 0.03
    mod.offset = 1.0
    return C._place(obj, HEAD_C + Vector((0, -0.012, 0.018)), (0, 0, 0), (1, 1, 1))


def hair_spike(name, base, direction, length, radius, mat, bend=0.35):
    """Chunky curved hair lock: a cone bent towards `bend` * gravity/back."""
    bm = bmesh.new()
    rings = 5
    segments = 8
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    ring_verts = []
    for r in range(rings):
        t = r / (rings - 1)
        rad = radius * (1.0 - t) ** 0.8
        # Swept curve: tip falls back/down a little.
        center = Vector(base) + d * (length * t) + Vector((0, -0.6, -0.4)).normalized() * (bend * length * t * t)
        verts = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            verts.append(bm.verts.new(center + (side * math.cos(a) + up * math.sin(a)) * max(rad, 0.004)))
        ring_verts.append(verts)
    for r in range(rings - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((ring_verts[r][i], ring_verts[r][j], ring_verts[r + 1][j], ring_verts[r + 1][i]))
    tip = bm.verts.new(Vector(base) + d * length * 1.08 + Vector((0, -0.6, -0.4)).normalized() * bend * length)
    for i in range(segments):
        bm.faces.new((ring_verts[-1][i], ring_verts[-1][(i + 1) % segments], tip))
    bm.faces.new(list(reversed(ring_verts[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return C._mesh_object(name, bm, mat, smooth=True)


def d_shape(name, width, height, depth, mat, segments=12):
    """Open-smile 'D' (flat top, round bottom) in the XZ plane, extruded along Y."""
    pts = [(-width, 0.0)]
    for i in range(segments + 1):
        a = math.pi + math.pi * i / segments
        pts.append((math.cos(a) * width, math.sin(a) * height))
    pts.append((width, 0.0))
    bm = bmesh.new()
    front = [bm.verts.new((x, depth * 0.5, z)) for x, z in pts]
    back = [bm.verts.new((x, -depth * 0.5, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return C._mesh_object(name, bm, mat, smooth=False)


# ---------------------------------------------------------------- body

def build_body(arm_obj):
    M = {
        "skin": C.material("M_Skin", "#ffb98c", 0.75),
        "hair": C.material("M_Hair", "#ff7417", 0.6),
        "brow": C.material("M_Brow", "#c2410c", 0.7),
        "jacket": C.material("M_Jacket", "#2667f0", 0.65),
        "accent": C.material("M_Accent", "#ff8a1e", 0.55),
        "teal": C.material("M_Teal", "#16c8d0", 0.45),
        "pants": C.material("M_Pants", "#46597a", 0.8),
        "shoe": C.material("M_Shoe", "#f7f8fb", 0.45),
        "sole": C.material("M_Sole", "#ff8a1e", 0.6),
        "glove": C.material("M_Glove", "#20253a", 0.7),
        "lens": C.material("M_Lens", "#8ff1ff", 0.15, emission="#5fe6ff", emission_strength=0.6),
        "strap": C.material("M_Strap", "#2a2f45", 0.7),
        "white": C.material("M_EyeWhite", "#ffffff", 0.35),
        "iris": C.material("M_Iris", "#6b3a12", 0.3),
        "pupil": C.material("M_Pupil", "#120d16", 0.3),
        "shine": C.material("M_EyeShine", "#ffffff", 0.2, emission="#ffffff", emission_strength=0.6),
        "mouth": C.material("M_Mouth", "#6e1626", 0.6),
        "tongue": C.material("M_Tongue", "#ff6b7a", 0.6),
        "blush": C.material("M_Blush", "#ff8e8e", 0.8),
    }
    parts = []

    def add(obj, bone):
        parts.append(weight(obj, bone))
        return obj

    # --- legs and bounce sneakers (big, readable feet)
    for side, sx in (("L", -1), ("R", 1)):
        x = 0.1 * sx
        add(capsule("Thigh" + side, 0.1, 0.12, (x, 0, 0.46), M["pants"], radius_top=0.11), "thigh." + side)
        add(C.cylinder("Cuff" + side, 0.112, 0.07, (x, 0, 0.35), M["pants"], verts=14, bevel=0.02), "shin." + side)
        add(C.box("PantStripe" + side, (0.03, 0.05, 0.2), (x + 0.1 * sx, 0, 0.46), M["accent"], bevel=0.012),
            "thigh." + side)
        add(capsule("Shin" + side, 0.062, 0.14, (x, 0, 0.24), M["skin"]), "shin." + side)
        add(C.cylinder("Sock" + side, 0.075, 0.07, (x, 0, 0.17), M["shoe"], verts=14, bevel=0.015), "shin." + side)
        add(rounded("Shoe" + side, (0.19, 0.34, 0.15), (x, 0.045, 0.085), M["shoe"], radius=0.065), "foot." + side)
        add(C.sphere("Toe" + side, 0.095, (x, 0.17, 0.075), M["shoe"], segments=14, rings=8, scale=(1.0, 0.85, 0.75)),
            "foot." + side)
        add(rounded("Sole" + side, (0.205, 0.37, 0.05), (x, 0.05, 0.025), M["sole"], radius=0.022), "foot." + side)
        for k, y in enumerate((0.02, 0.1)):
            add(rounded("Strap%s%d" % (side, k), (0.2, 0.045, 0.04), (x, y, 0.15), M["accent"], radius=0.016,
                        rot=(-18, 0, 0)), "foot." + side)
        add(C.sphere("Heel" + side, 0.04, (x + 0.07 * sx, -0.08, 0.1), M["teal"], segments=10, rings=6,
                     scale=(0.4, 1, 1)), "foot." + side)

    # --- hips, torso, jacket details, backpack
    add(rounded("Hips", (0.32, 0.22, 0.16), (0, 0, 0.6), M["pants"], radius=0.07), "hips")
    add(rounded("Belt", (0.34, 0.24, 0.045), (0, 0, 0.665), M["strap"], radius=0.02), "hips")
    add(rounded("Buckle", (0.07, 0.03, 0.045), (0, 0.12, 0.665), M["accent"], radius=0.012), "hips")
    add(rounded("Torso", (0.38, 0.27, 0.3), (0, 0, 0.8), M["jacket"], radius=0.11), "spine")
    add(rounded("Hem", (0.4, 0.29, 0.06), (0, 0, 0.675), M["accent"], radius=0.025), "spine")
    for s in (-1, 1):
        add(rounded("Chevron%d" % s, (0.2, 0.04, 0.05), (0.08 * s, 0.13, 0.85), M["accent"], radius=0.018,
                    rot=(0, -28 * s, 0)), "spine")
        add(C.sphere("ShoulderPad%d" % s, 0.085, (0.2 * s, 0, 0.9), M["accent"], segments=14, rings=8,
                     scale=(1.1, 1.0, 0.8)), "spine")
    add(C.box("Zipper", (0.022, 0.03, 0.24), (0, 0.137, 0.79), M["teal"], bevel=0.008), "spine")
    add(C.cylinder("Collar", 0.13, 0.08, (0, 0.0, 0.95), M["jacket"], verts=16, radius_top=0.145, bevel=0.02), "spine")
    add(C.cylinder("CollarIn", 0.118, 0.085, (0, 0.0, 0.955), M["teal"], verts=16, radius_top=0.133), "spine")
    add(rounded("Backpack", (0.28, 0.15, 0.26), (0, -0.2, 0.81), M["teal"], radius=0.06), "spine")
    add(rounded("BackpackFlap", (0.29, 0.16, 0.09), (0, -0.2, 0.92), M["accent"], radius=0.035), "spine")
    add(C.cylinder("BackpackBadge", 0.045, 0.02, (0, -0.28, 0.8), M["accent"], verts=14, rot=(90, 0, 0)), "spine")
    for s in (-1, 1):
        add(rounded("Strap%d" % s, (0.04, 0.03, 0.26), (0.11 * s, 0.13, 0.81), M["strap"], radius=0.012,
                    rot=(0, 8 * s, 0)), "spine")

    # --- arms with big gloves
    for side, sx in (("L", -1), ("R", 1)):
        add(capsule("UpperArm" + side, 0.064, 0.12, (0.27 * sx, 0, 0.8), M["jacket"], rot=(0, -12 * sx, 0)),
            "upper_arm." + side)
        add(capsule("Forearm" + side, 0.058, 0.09, (0.3 * sx, 0, 0.645), M["jacket"]), "forearm." + side)
        add(C.cylinder("Sleeve" + side, 0.068, 0.05, (0.305 * sx, 0, 0.585), M["accent"], verts=14, bevel=0.015),
            "forearm." + side)
        add(C.sphere("Glove" + side, 0.078, (0.31 * sx, 0.005, 0.51), M["glove"], segments=16, rings=10,
                     scale=(0.85, 1.0, 1.05)), "hand." + side)
        add(C.cylinder("GloveCuff" + side, 0.07, 0.045, (0.31 * sx, 0, 0.56), M["teal"], verts=14, bevel=0.012),
            "hand." + side)
        add(capsule("Thumb" + side, 0.026, 0.04, (0.28 * sx, 0.055, 0.525), M["glove"], rot=(30, 0, 30 * sx)),
            "hand." + side)

    # --- head
    add(C.sphere("Head", HEAD_R, tuple(HEAD_C), M["skin"], segments=28, rings=18, scale=tuple(HEAD_SCALE)), "head")
    add(C.cylinder("Neck", 0.075, 0.08, (0, 0, 0.97), M["skin"], verts=14), "head")
    for s in (-1, 1):
        add(C.sphere("Ear%d" % s, 0.05, tuple(head_point(88 * s, -4, -0.02)), M["skin"], segments=12, rings=8,
                     scale=(0.55, 0.8, 1.05)), "head")
    add(C.sphere("Nose", 0.024, tuple(head_point(0, -12, -0.004)), M["skin"], segments=10, rings=6,
                 scale=(1.1, 0.9, 0.8)), "head")
    # Eyes: sclera, iris, pupil and two highlights, each following the head curve.
    for s in (-1, 1):
        az, el = 21 * s, -4
        rot = face_rot(az, el)
        add(C.sphere("EyeWhite%d" % s, 1.0, tuple(head_point(az, el, -0.014)), M["white"], segments=18, rings=12,
                     scale=(0.06, 0.045, 0.082), rot=rot), "eyes")
        iris_az = az - 2.5 * s
        add(C.sphere("Iris%d" % s, 1.0, tuple(head_point(iris_az, el - 1, -0.004)), M["iris"], segments=18, rings=12,
                     scale=(0.05, 0.04, 0.068), rot=face_rot(iris_az, el - 1)), "eyes")
        add(C.sphere("Pupil%d" % s, 1.0, tuple(head_point(iris_az, el - 1, 0.012)), M["pupil"], segments=14,
                     rings=8, scale=(0.026, 0.03, 0.038), rot=face_rot(iris_az, el - 1)), "eyes")
        add(C.sphere("Shine%d" % s, 0.017, tuple(head_point(iris_az + 3 * s, el + 5, 0.036)), M["shine"],
                     segments=8, rings=6), "eyes")
        add(C.sphere("ShineSmall%d" % s, 0.009, tuple(head_point(iris_az - 3 * s, el - 7, 0.034)), M["shine"],
                     segments=6, rings=4), "eyes")
        brow = capsule("Brow%d" % s, 0.017, 0.07, tuple(head_point(20 * s, 19, 0.004)), M["brow"], segments=10, rings=6)
        a = math.radians(20 * s)
        brow.rotation_euler = look_rot((math.cos(a), -math.sin(a), -0.2 * s))  # outer end slightly lower
        add(brow, "head")
        add(C.sphere("Blush%d" % s, 1.0, tuple(head_point(40 * s, -14, -0.006)), M["blush"], segments=12, rings=6,
                     scale=(0.036, 0.012, 0.022), rot=face_rot(40 * s, -14)), "head")
    # Open, friendly smile with teeth and tongue.
    mrot = face_rot(0, -24)
    mouth = d_shape("Mouth", 0.062, 0.05, 0.03, M["mouth"])
    C._place(mouth, tuple(head_point(0, -24, -0.01)), mrot, (1, 1, 1))
    add(mouth, "head")
    teeth = C.box("Teeth", (0.1, 0.02, 0.018), tuple(head_point(0, -26, -0.004)), M["white"], bevel=0.006, rot=mrot)
    add(teeth, "head")
    add(C.sphere("Tongue", 1.0, tuple(head_point(0, -29, -0.006)), M["tongue"], segments=12, rings=6,
                 scale=(0.036, 0.016, 0.018), rot=mrot), "head")

    # --- hair: cap + swept chunky locks (silhouette readable from behind)
    add(hair_cap("HairCap", M["hair"]), "head")
    locks = [
        # (az, el, length, radius, extra direction)
        (0, 70, 0.3, 0.1, (0, -0.2, 1.0)), (-38, 58, 0.27, 0.095, (-0.4, -0.3, 0.9)),
        (38, 58, 0.27, 0.095, (0.4, -0.3, 0.9)), (-75, 35, 0.22, 0.085, (-0.9, -0.4, 0.4)),
        (75, 35, 0.22, 0.085, (0.9, -0.4, 0.4)), (180, 45, 0.28, 0.1, (0, -1.0, 0.45)),
        (140, 30, 0.25, 0.09, (0.5, -1.0, 0.1)), (-140, 30, 0.25, 0.09, (-0.5, -1.0, 0.1)),
        (180, 5, 0.22, 0.09, (0, -1.0, -0.35)), (115, 60, 0.26, 0.09, (0.45, -0.6, 0.75)),
        (-115, 60, 0.26, 0.09, (-0.45, -0.6, 0.75)),
        # Bangs over the forehead, above the goggles.
        (-22, 44, 0.2, 0.075, (-0.35, 0.8, 0.55)), (6, 47, 0.22, 0.08, (0.1, 0.85, 0.6)),
        (32, 42, 0.18, 0.07, (0.45, 0.75, 0.45)),
    ]
    for i, (az, el, length, radius, extra) in enumerate(locks):
        base = head_point(az, el, 0.0)
        direction = (head_dir(az, el) + Vector(extra)).normalized()
        add(hair_spike("Lock_%d" % i, base, direction, length, radius, M["hair"], bend=0.28), "head")

    # --- goggles resting on the forehead
    strap = C.torus("GoggleStrap", 0.27, 0.022, tuple(head_point(0, 31, 0.0) * Vector((0, 0, 1))), M["strap"],
                    major_segments=28, minor_segments=6)
    strap.scale = (1.0, 0.9, 1.0)
    add(strap, "head")
    for s in (-1, 1):
        az, el = 17 * s, 31
        d = head_dir(az, el)
        rot = look_rot(d)
        center = head_point(az, el, 0.035)
        lens_rim = C.torus("LensRim%d" % s, 0.066, 0.022, tuple(center), M["teal"], major_segments=18,
                           minor_segments=6)
        lens_rim.rotation_euler = rot
        add(lens_rim, "head")
        lens = C.cylinder("Lens%d" % s, 0.064, 0.04, tuple(center - d * 0.005), M["lens"], verts=18)
        lens.rotation_euler = rot
        add(lens, "head")
        add(C.sphere("LensGlint%d" % s, 0.016, tuple(center + d * 0.02 + Vector((0.02 * s, 0, 0.025))), M["shine"],
                     segments=6, rings=4), "head")
    add(rounded("GoggleBridge", (0.05, 0.03, 0.03), tuple(head_point(0, 31, 0.03)), M["strap"], radius=0.01,
                rot=(31, 0, 0)), "head")

    body = C.join(parts, "CHR_Adventurer_Body")
    body.parent = arm_obj
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj

    # The holstered yo-yo is a separate mesh so gameplay can hide it while the yo-yo is out.
    yoyo = C.material("M_Yoyo", "yoyo", 0.35, emission="yoyo", emission_strength=0.5)
    accent = C.material("M_YoyoAccent", "yoyo_accent", 0.4)
    yoyo_parts = [
        weight(C.cylinder("HipYoyoA", 0.1, 0.05, (0.2, 0.02, 0.6), yoyo, verts=18, rot=(0, 90, 0), bevel=0.015), "hips"),
        weight(C.cylinder("HipYoyoB", 0.062, 0.06, (0.2, 0.02, 0.6), accent, verts=14, rot=(0, 90, 0)), "hips"),
    ]
    hip_yoyo = C.join(yoyo_parts, "HipYoyo")
    hip_yoyo.parent = arm_obj
    mod = hip_yoyo.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    return body


# ---------------------------------------------------------------- animation

def pose_key(arm_obj, frame, pose):
    """pose: {bone: (rx, ry, rz) degrees}, optional 'root_z'/'root_y' offsets
    (metres) and 'blink' (0 open .. 1 closed)."""
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"
        rot = pose.get(pb.name, (0, 0, 0))
        pb.rotation_euler = tuple(math.radians(a) for a in rot)
        pb.keyframe_insert("rotation_euler", frame=frame)
    root = arm_obj.pose.bones["root"]
    # root bone points up: local Y == world Z, local Z == world -Y... keep forward offset on local Z.
    root.location = (0, pose.get("root_z", 0.0), -pose.get("root_y", 0.0))
    root.keyframe_insert("location", frame=frame)
    eyes = arm_obj.pose.bones["eyes"]
    closed = pose.get("blink", 0.0)
    eyes.scale = (1.0, 1.0 - 0.9 * closed, 1.0)  # eyes bone points up: local Y == world Z
    eyes.keyframe_insert("scale", frame=frame)


def make_action(arm_obj, name, keys):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = action
    for frame, pose in keys:
        pose_key(arm_obj, frame, pose)
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(keys[0][0]), action)
    strip.name = name
    track.mute = True
    arm_obj.animation_data.action = None
    return action


def merge(*poses, **extra):
    out = {}
    for p in poses:
        out.update(p)
    out.update(extra)
    return out


def build_animations(arm_obj):
    rest = {"upper_arm.L": (0, 0, 10), "upper_arm.R": (0, 0, -10), "forearm.L": (14, 0, 0), "forearm.R": (14, 0, 0)}

    # Idle (3 s loop): breathing, weight shift, head look and a blink.
    idle_a = merge(rest, spine=(2, 0, 0), head=(-3, 0, 0))
    idle_b = merge(rest, spine=(-1, 0, 2), head=(2, 6, -2), hips=(0, 0, -2), root_z=-0.012,
                   **{"upper_arm.L": (4, 0, 13), "upper_arm.R": (-3, 0, -13), "forearm.L": (20, 0, 0)})
    idle_c = merge(idle_a, head=(-4, -5, 2))
    make_action(arm_obj, "Idle", [
        (1, idle_a), (24, idle_b), (40, merge(idle_b, blink=0.0)), (43, merge(idle_b, blink=1.0)),
        (46, merge(idle_b, blink=0.0)), (66, idle_c), (91, idle_a)])

    # Run (16-frame cycle, two steps): bounce, pump, torso twist.
    def run_pose(phase):
        s = math.sin(phase)
        c = math.cos(phase)
        return {
            "spine": (16, 8 * s, 0), "head": (-12, -6 * s, 0), "hips": (0, -10 * s, 0),
            "thigh.L": (55 * s, 0, 0), "thigh.R": (-55 * s, 0, 0),
            "shin.L": (-80 * max(0.0, -s) - 12, 0, 0), "shin.R": (-80 * max(0.0, s) - 12, 0, 0),
            "foot.L": (20 * s, 0, 0), "foot.R": (-20 * s, 0, 0),
            "upper_arm.L": (-60 * s, 0, 14), "upper_arm.R": (60 * s, 0, -14),
            "forearm.L": (85, 0, 0), "forearm.R": (85, 0, 0),
            "root_z": 0.06 * abs(c) - 0.035,
        }
    make_action(arm_obj, "Run", [(1 + i * 2, run_pose(i * math.pi / 4)) for i in range(9)])

    # Jump (rising): stretch, leading knee up, arm reaching. Holds.
    jump_a = {"spine": (-10, 0, 0), "head": (-8, 0, 0), "thigh.L": (25, 0, 0), "thigh.R": (-15, 0, 0),
              "shin.L": (-35, 0, 0), "shin.R": (-10, 0, 0), "upper_arm.L": (60, 0, 25), "upper_arm.R": (40, 0, -35),
              "forearm.L": (30, 0, 0), "forearm.R": (40, 0, 0), "root_z": 0.02}
    jump_b = {"spine": (6, 0, 0), "head": (-12, 0, 0), "thigh.L": (75, 0, 0), "thigh.R": (5, 0, 0),
              "shin.L": (-95, 0, 0), "shin.R": (-40, 0, 0), "upper_arm.L": (165, 0, -20), "upper_arm.R": (-35, 0, -45),
              "forearm.L": (15, 0, 0), "forearm.R": (55, 0, 0)}
    make_action(arm_obj, "Jump", [(1, jump_a), (6, jump_b), (12, jump_b)])

    # Fall: arms out for balance, legs reaching, small flail loop.
    fall_a = {"spine": (2, 0, 0), "head": (14, 0, 0), "thigh.L": (30, 0, 0), "thigh.R": (8, 0, 0),
              "shin.L": (-45, 0, 0), "shin.R": (-25, 0, 0), "upper_arm.L": (25, 0, 75), "upper_arm.R": (25, 0, -75),
              "forearm.L": (25, 0, 0), "forearm.R": (25, 0, 0)}
    fall_b = merge(fall_a, **{"upper_arm.L": (15, 0, 88), "upper_arm.R": (40, 0, -62), "thigh.L": (18, 0, 0),
                              "thigh.R": (22, 0, 0), "head": (10, 0, 4)})
    make_action(arm_obj, "Fall", [(1, fall_a), (9, fall_b), (17, fall_a)])

    # Slide: low lean back, front leg extended, hand trailing on the floor.
    slide = {"root_z": -0.36, "hips": (-32, 0, 0), "spine": (-22, 0, 0), "head": (32, 0, 0),
             "thigh.R": (95, 0, 0), "shin.R": (-5, 0, 0), "foot.R": (-25, 0, 0),
             "thigh.L": (40, 0, 0), "shin.L": (-115, 0, 0),
             "upper_arm.L": (-45, 0, 45), "upper_arm.R": (-65, 0, -30), "forearm.L": (20, 0, 0), "forearm.R": (15, 0, 0)}
    make_action(arm_obj, "Slide", [(1, slide), (6, merge(slide, **{"upper_arm.L": (-50, 0, 52)})), (11, slide)])

    # Air dash: superhero line, fist forward.
    dash = {"spine": (38, 0, 0), "head": (-32, 0, 0), "thigh.L": (-30, 0, 0), "thigh.R": (-12, 0, 0),
            "shin.L": (-45, 0, 0), "shin.R": (-70, 0, 0), "upper_arm.R": (172, 0, 5), "forearm.R": (5, 0, 0),
            "upper_arm.L": (-65, 0, 25), "forearm.L": (35, 0, 0)}
    make_action(arm_obj, "Dash", [(1, dash), (4, merge(dash, root_z=0.02)), (7, dash)])

    # Throw: wind-up with body twist, whip, follow-through and catch pose.
    wind = merge(rest, spine=(-8, -25, 0), hips=(0, -10, 0), head=(0, 18, 0),
                 **{"upper_arm.R": (-75, 0, -35), "forearm.R": (95, 0, 0), "upper_arm.L": (30, 0, 30)})
    whip = merge(rest, spine=(14, 22, 0), hips=(0, 10, 0), head=(-4, -10, 0),
                 **{"upper_arm.R": (105, 0, -8), "forearm.R": (4, 0, 0), "upper_arm.L": (-25, 0, 22),
                    "thigh.L": (15, 0, 0), "shin.L": (-15, 0, 0)})
    follow = merge(whip, spine=(10, 14, 0), **{"upper_arm.R": (80, 0, -14), "forearm.R": (25, 0, 0)})
    make_action(arm_obj, "Throw", [(1, rest), (4, wind), (7, whip), (11, follow), (16, rest)])

    # Bounce: tuck pose (Godot adds the flip on the visual root).
    tuck = {"root_z": 0.15, "spine": (32, 0, 0), "head": (22, 0, 0), "thigh.L": (105, 0, 0), "thigh.R": (105, 0, 0),
            "shin.L": (-135, 0, 0), "shin.R": (-135, 0, 0), "upper_arm.L": (65, 0, 18), "upper_arm.R": (65, 0, -18),
            "forearm.L": (95, 0, 0), "forearm.R": (95, 0, 0)}
    make_action(arm_obj, "Bounce", [(1, tuck), (6, merge(tuck, root_z=0.17)), (11, tuck)])

    # Land: deep squash, overshoot, settle.
    land = merge(rest, root_z=-0.14, spine=(24, 0, 0), head=(-10, 0, 0),
                 **{"thigh.L": (48, 0, 0), "thigh.R": (48, 0, 0), "shin.L": (-80, 0, 0), "shin.R": (-80, 0, 0),
                    "upper_arm.L": (20, 0, 30), "upper_arm.R": (20, 0, -30)})
    over = merge(rest, root_z=0.015, spine=(-4, 0, 0), head=(3, 0, 0))
    make_action(arm_obj, "Land", [(1, land), (6, over), (10, rest)])

    # Victory: hop with fist pump and a cheeky head tilt (loop).
    vic_a = {"upper_arm.R": (175, 0, 22), "forearm.R": (15, 0, 0), "upper_arm.L": (10, 0, 35), "forearm.L": (70, 0, 0),
             "spine": (-10, 0, 0), "head": (-12, 0, 8)}
    vic_b = merge(vic_a, root_z=0.12, **{"upper_arm.R": (150, 0, 30), "forearm.R": (70, 0, 0),
                                         "thigh.L": (35, 0, 0), "shin.L": (-60, 0, 0), "head": (-16, 0, -6)})
    make_action(arm_obj, "Victory", [(1, vic_a), (8, vic_b), (15, vic_a), (24, merge(vic_a, blink=0.0)),
                                     (26, merge(vic_a, blink=1.0)), (28, vic_a), (35, vic_a)])

    # Hurt: quick flinch with squeezed eyes (used on respawn).
    hurt = {"spine": (-25, 0, 10), "head": (-20, 0, 0), "upper_arm.L": (60, 0, 60), "upper_arm.R": (60, 0, -60),
            "forearm.L": (95, 0, 0), "forearm.R": (95, 0, 0), "thigh.L": (30, 0, 0), "shin.L": (-60, 0, 0), "blink": 0.85}
    make_action(arm_obj, "Hurt", [(1, rest), (4, hurt), (14, hurt)])

    for action in bpy.data.actions:
        for fc in getattr(action, "fcurves", []):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"


def build_adventurer():
    C.use_collection("CHR_Adventurer")
    arm_obj = make_armature()
    build_body(arm_obj)
    build_animations(arm_obj)
    bpy.context.scene.frame_end = 90
    return C.save_and_export("CHR_Adventurer", export_animations=True)


# ---------------------------------------------------------------- yo-yo

def sun_face(name, radius, rays, z, mat):
    """Sun emblem from the concept art: ring of triangular rays (XY plane)."""
    pts = []
    for i in range(rays * 2):
        a = i * math.pi / rays
        r = radius if i % 2 == 0 else radius * 0.72
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return C.prism(name, pts, 0.012, (0, 0, z), mat)


def build_yoyo():
    C.use_collection("PROP_Yoyo")
    cyan = C.material("M_Yoyo", "yoyo", 0.3, emission="yoyo", emission_strength=0.7)
    orange = C.material("M_YoyoAccent", "yoyo_accent", 0.35, emission="yoyo_accent", emission_strength=0.5)
    core = C.material("M_YoyoCore", "yoyo_core", 0.25, emission="yoyo_core", emission_strength=0.6)
    dark = C.material("M_YoyoDark", "#1d3550", 0.5)
    # Spins around its local X axis in Godot (axle along Blender X).
    pivot = C.empty("Yoyo", (0, 0, 0))
    for side in (-1, 1):
        half = C.cylinder("Half_%d" % side, 0.2, 0.085, (0, 0, 0), cyan, verts=24, bevel=0.025)
        half.location = (side * 0.07, 0, 0)
        half.rotation_euler = (0, math.radians(90), 0)
        sun = sun_face("Sun_%d" % side, 0.16, 10, 0.0, orange)
        sun.location = (side * 0.114, 0, 0)
        sun.rotation_euler = (0, math.radians(90 * side), 0)
        hub = C.cylinder("Hub_%d" % side, 0.075, 0.02, (side * 0.122, 0, 0), core, verts=16, rot=(0, 90, 0))
        for obj in (half, sun, hub):
            C.parent(obj, pivot)
    C.parent(C.cylinder("Axle", 0.06, 0.06, (0, 0, 0), dark, verts=12, rot=(0, 90, 0)), pivot)
    return C.save_and_export("PROP_Yoyo")


def build_disc():
    C.use_collection("PROP_YoyoDisc")
    cyan = C.material("M_DiscCyan", "yoyo", 0.25, emission="yoyo", emission_strength=1.3)
    orange = C.material("M_YoyoAccent", "yoyo_accent", 0.35, emission="yoyo_accent", emission_strength=0.8)
    core = C.material("M_YoyoCore", "yoyo_core", 0.25, emission="yoyo_core", emission_strength=1.2)
    dark = C.material("M_DiscUnder", "#173f63", 0.45)
    white = C.material("M_DiscWhite", "#ffffff", 0.4, emission="#dffbff", emission_strength=0.5)
    # Deployed bounce disc, walkable top at z=0, radius 1.3 m. "Spin" spins around Z.
    C.cylinder("Under", 1.05, 0.2, (0, 0, -0.16), dark, verts=40, radius_top=1.3, bevel=0.03)
    C.cylinder("Thruster", 0.45, 0.16, (0, 0, -0.32), orange, verts=24, radius_top=0.7)
    spin = C.empty("Spin", (0, 0, 0))
    parts = [
        C.cylinder("Top", 1.3, 0.08, (0, 0, -0.04), cyan, verts=48, bevel=0.035),
        C.torus("OuterRing", 1.18, 0.055, (0, 0, 0.005), white, major_segments=48, minor_segments=6),
        C.torus("MidRing", 0.92, 0.045, (0, 0, 0.005), orange, major_segments=40, minor_segments=6),
        C.torus("InnerRing", 0.55, 0.04, (0, 0, 0.005), white, major_segments=32, minor_segments=6),
        sun_face("Sun", 0.42, 12, 0.0, orange),
        C.cylinder("Core", 0.24, 0.1, (0, 0, 0.01), core, verts=24, bevel=0.02),
    ]
    for i in range(6):
        a = i * math.pi / 3
        parts.append(C.box("Mark_%d" % i, (0.22, 0.09, 0.025), (math.cos(a) * 1.05, math.sin(a) * 1.05, 0.005), orange,
                           bevel=0.01, rot=(0, 0, math.degrees(a) + 90)))
    for obj in parts:
        C.parent(obj, spin)
    return C.save_and_export("PROP_YoyoDisc")


BUILDERS = {"CHR_Adventurer": build_adventurer, "PROP_Yoyo": build_yoyo, "PROP_YoyoDisc": build_disc}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    argv = [a for a in argv if a and a != "ALL"]
    report = []
    for n in argv or list(BUILDERS):
        C.reset_scene()
        report.append(BUILDERS[n]())
    with open(os.path.join(C.BLEND_DIR, "scripts", "last_character_report.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1)


if __name__ == "__main__":
    main()
