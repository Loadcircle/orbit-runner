"""Builds the protagonist (CHR_Adventurer) and the kinetic yo-yo assets.

  blender --background --factory-startup --python build_character.py -- [CHR_Adventurer|PROP_Yoyo|PROP_YoyoDisc|ALL]

The character is a stylised, rigid-skinned mesh: every body part is weighted
100% to one bone, which keeps silhouettes crisp (toon look) and makes the rig
cheap on mobile. Faces +Y in Blender (=> -Z in Godot); origin between the feet.
All bones use roll so that local +Z points forward (+Y): a positive X rotation
always swings the bone tip forward; positive Z swings left-side limbs outward.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import or_common as C  # noqa: E402

FPS = 30

# name: (head, tail, parent, roll_axis)
BONES = {
    "root": ((0, 0, 0), (0, 0, 0.25), None, (0, 1, 0)),
    "hips": ((0, 0, 0.7), (0, 0, 0.82), "root", (0, 1, 0)),
    "spine": ((0, 0, 0.82), (0, 0, 1.1), "hips", (0, 1, 0)),
    "head": ((0, 0, 1.12), (0, 0, 1.55), "spine", (0, 1, 0)),
    "upper_arm.L": ((-0.24, 0, 1.06), (-0.27, 0, 0.86), "spine", (0, 1, 0)),
    "forearm.L": ((-0.27, 0, 0.86), (-0.28, 0, 0.67), "upper_arm.L", (0, 1, 0)),
    "hand.L": ((-0.28, 0, 0.67), (-0.28, 0, 0.57), "forearm.L", (0, 1, 0)),
    "upper_arm.R": ((0.24, 0, 1.06), (0.27, 0, 0.86), "spine", (0, 1, 0)),
    "forearm.R": ((0.27, 0, 0.86), (0.28, 0, 0.67), "upper_arm.R", (0, 1, 0)),
    "hand.R": ((0.28, 0, 0.67), (0.28, 0, 0.57), "forearm.R", (0, 1, 0)),
    "thigh.L": ((-0.11, 0, 0.7), (-0.11, 0, 0.42), "hips", (0, 1, 0)),
    "shin.L": ((-0.11, 0, 0.42), (-0.11, 0, 0.12), "thigh.L", (0, 1, 0)),
    "foot.L": ((-0.11, 0, 0.12), (-0.11, 0.16, 0.05), "shin.L", (0, 0, 1)),
    "thigh.R": ((0.11, 0, 0.7), (0.11, 0, 0.42), "hips", (0, 1, 0)),
    "shin.R": ((0.11, 0, 0.42), (0.11, 0, 0.12), "thigh.R", (0, 1, 0)),
    "foot.R": ((0.11, 0, 0.12), (0.11, 0.16, 0.05), "shin.R", (0, 0, 1)),
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


def build_body(arm_obj):
    M = {
        "skin": C.material("M_Skin", "#f2c29b", 0.8),
        "hair": C.material("M_Hair", "#f07a22", 0.7),
        "jacket": C.material("M_Jacket", "#2d5fb8", 0.7),
        "accent": C.material("M_Accent", "#f58a2c", 0.6),
        "teal": C.material("M_Teal", "#27b7c4", 0.5),
        "pants": C.material("M_Pants", "#4c5c6e", 0.85),
        "shoe": C.material("M_Shoe", "#f3f4f6", 0.6),
        "glove": C.material("M_Glove", "#2a2f3a", 0.75),
        "lens": C.material("M_Lens", "#7fd8e8", 0.2, emission="#7fd8e8", emission_strength=0.3),
        "eye": C.material("M_Eye", "#1d2230", 0.4),
        "white": C.material("M_EyeWhite", "#ffffff", 0.4),
    }
    parts = []

    def add(obj, bone):
        parts.append(weight(obj, bone))
        return obj

    # Legs and shoes.
    for side, sx in (("L", -1), ("R", 1)):
        x = 0.11 * sx
        add(C.cylinder("Thigh" + side, 0.105, 0.3, (x, 0, 0.56), M["pants"], verts=10, radius_top=0.115), "thigh." + side)
        add(C.cylinder("Shin" + side, 0.075, 0.24, (x, 0, 0.3), M["skin"], verts=10), "shin." + side)
        add(C.cylinder("Cuff" + side, 0.11, 0.08, (x, 0, 0.43), M["pants"], verts=10), "shin." + side)
        add(C.box("Shoe" + side, (0.17, 0.32, 0.15), (x, 0.05, 0.08), M["shoe"], bevel=0.05), "foot." + side)
        add(C.box("ShoeStripe" + side, (0.175, 0.12, 0.05), (x, 0.08, 0.1), M["accent"], bevel=0.015), "foot." + side)
        add(C.box("Sole" + side, (0.18, 0.33, 0.04), (x, 0.05, 0.02), M["accent"], bevel=0.015), "foot." + side)
        add(C.cylinder("Sock" + side, 0.085, 0.07, (x, 0, 0.17), M["shoe"], verts=10), "shin." + side)

    # Hips, belt, torso, backpack.
    add(C.box("Hips", (0.34, 0.22, 0.16), (0, 0, 0.74), M["pants"], bevel=0.05), "hips")
    add(C.box("Belt", (0.36, 0.24, 0.05), (0, 0, 0.81), M["accent"], bevel=0.02), "hips")
    add(C.cylinder("Torso", 0.2, 0.32, (0, 0, 0.97), M["jacket"], verts=12, radius_top=0.22), "spine")
    add(C.box("Chevron", (0.44, 0.05, 0.06), (0, 0.19, 1.03), M["accent"], bevel=0.02, rot=(0, 0, 0)), "spine")
    add(C.box("Zipper", (0.03, 0.04, 0.3), (0, 0.205, 0.96), M["teal"], bevel=0.0), "spine")
    add(C.cylinder("Collar", 0.13, 0.08, (0, 0, 1.14), M["jacket"], verts=12, radius_top=0.14), "spine")
    add(C.box("Backpack", (0.3, 0.16, 0.3), (0, -0.25, 0.98), M["teal"], bevel=0.05), "spine")
    add(C.box("BackpackFlap", (0.31, 0.17, 0.08), (0, -0.25, 1.1), M["accent"], bevel=0.03), "spine")

    # Arms.
    for side, sx in (("L", -1), ("R", 1)):
        add(C.cylinder("UpperArm" + side, 0.065, 0.22, (0.255 * sx, 0, 0.96), M["jacket"], verts=10), "upper_arm." + side)
        add(C.sphere("Shoulder" + side, 0.085, (0.245 * sx, 0, 1.05), M["jacket"], segments=10, rings=6),
            "upper_arm." + side)
        add(C.cylinder("Forearm" + side, 0.055, 0.17, (0.275 * sx, 0, 0.77), M["skin"], verts=10), "forearm." + side)
        add(C.cylinder("Sleeve" + side, 0.07, 0.06, (0.27 * sx, 0, 0.84), M["accent"], verts=10), "forearm." + side)
        add(C.sphere("Glove" + side, 0.07, (0.28 * sx, 0, 0.63), M["glove"], segments=10, rings=8, scale=(0.9, 1, 1.1)),
            "hand." + side)

    # Head: big, readable from the follow camera.
    add(C.sphere("Head", 0.22, (0, 0.01, 1.34), M["skin"], segments=20, rings=12, scale=(1, 0.95, 1)), "head")
    add(C.sphere("HairCap", 0.235, (0, -0.06, 1.43), M["hair"], segments=16, rings=10, scale=(1.0, 0.95, 0.82)), "head")
    spikes = [(0, 0.05, 1.63, -20, 0), (-0.12, 0.0, 1.6, -15, -30), (0.12, 0.0, 1.6, -15, 30), (0, -0.15, 1.57, -60, 0),
              (-0.17, -0.1, 1.5, -40, -60), (0.17, -0.1, 1.5, -40, 60), (-0.06, 0.15, 1.57, 15, -15),
              (0.08, 0.16, 1.56, 25, 20), (0, -0.22, 1.42, -95, 0)]
    for i, (x, y, z, rx, ry) in enumerate(spikes):
        add(C.cone("Spike_%d" % i, 0.075, 0.24, (x, y, z), M["hair"], verts=6, rot=(rx, ry, 0)), "head")
    add(C.torus("GoggleStrap", 0.225, 0.025, (0, 0, 1.44), M["glove"], major_segments=20, minor_segments=6,
                rot=(-8, 0, 0)), "head")
    for side in (-1, 1):
        add(C.cylinder("Lens%d" % side, 0.06, 0.05, (0.075 * side, 0.2, 1.46), M["lens"], verts=12, rot=(80, 0, 0)), "head")
        add(C.torus("LensRim%d" % side, 0.06, 0.016, (0.075 * side, 0.205, 1.46), M["teal"], major_segments=14,
                    minor_segments=5, rot=(80, 0, 0)), "head")
        add(C.sphere("Eye%d" % side, 0.042, (0.075 * side, 0.195, 1.32), M["eye"], segments=10, rings=8,
                     scale=(0.8, 0.5, 1.15)), "head")
        add(C.sphere("Shine%d" % side, 0.014, (0.067 * side, 0.215, 1.34), M["white"], segments=6, rings=4), "head")
    add(C.sphere("Smile", 0.04, (0, 0.2, 1.23), C.material("M_Mouth", "#a3402a", 0.6), segments=10, rings=6,
                 scale=(1.2, 0.4, 0.45)), "head")

    body = C.join(parts, "CHR_Adventurer_Body")
    body.parent = arm_obj
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj

    # The holstered yo-yo is a separate mesh so gameplay can hide it while the yo-yo is out.
    yoyo_parts = [
        weight(C.cylinder("HipYoyoA", 0.1, 0.04, (0.215, 0.0, 0.73), C.material("M_Yoyo", "yoyo", 0.35, emission="yoyo",
                                                                                 emission_strength=0.6),
                          verts=16, rot=(0, 90, 0)), "hips"),
        weight(C.cylinder("HipYoyoB", 0.06, 0.06, (0.215, 0.0, 0.73), C.material("M_YoyoAccent", "yoyo_accent", 0.4),
                          verts=12, rot=(0, 90, 0)), "hips"),
    ]
    hip_yoyo = C.join(yoyo_parts, "HipYoyo")
    hip_yoyo.parent = arm_obj
    mod = hip_yoyo.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    return body


# ---------------------------------------------------------------- animation

def pose_key(arm_obj, frame, pose):
    """pose: {bone: (rx, ry, rz) degrees} plus optional 'root_z' offset (metres)."""
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"
        rot = pose.get(pb.name, (0, 0, 0))
        pb.rotation_euler = tuple(math.radians(a) for a in rot)
        pb.keyframe_insert("rotation_euler", frame=frame)
    root = arm_obj.pose.bones["root"]
    root.location = (0, pose.get("root_z", 0.0), 0)  # root bone local Y == world Z (bone points up)
    root.keyframe_insert("location", frame=frame)


def make_action(arm_obj, name, keys, cyclic=False):
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


def mirror(pose):
    out = {}
    for k, v in pose.items():
        if k.endswith(".L"):
            out[k[:-2] + ".R"] = (v[0], -v[1], -v[2])
        elif k.endswith(".R"):
            out[k[:-2] + ".L"] = (v[0], -v[1], -v[2])
        else:
            out[k] = v
    return out


def build_animations(arm_obj):
    rest_arms = {"upper_arm.L": (0, 0, 8), "upper_arm.R": (0, 0, -8), "forearm.L": (12, 0, 0), "forearm.R": (12, 0, 0)}

    # Idle: breathing + small sway (2 s loop).
    idle_a = dict(rest_arms, spine=(2, 0, 0), head=(-2, 0, 0))
    idle_b = dict(rest_arms, spine=(-1, 0, 2), head=(3, 4, 0), **{"upper_arm.L": (3, 0, 11), "upper_arm.R": (-3, 0, -11)})
    idle_b["root_z"] = -0.01
    make_action(arm_obj, "Idle", [(1, idle_a), (31, idle_b), (61, idle_a)], cyclic=True)

    # Run: 20-frame cycle (two steps).
    def run_pose(phase):
        s = math.sin(phase)
        c = math.cos(phase)
        return {
            "spine": (14, 0, -6 * s), "head": (-8, 0, 4 * s), "hips": (0, 0, 8 * s),
            "thigh.L": (45 * s, 0, 0), "thigh.R": (-45 * s, 0, 0),
            "shin.L": (-55 * max(0.0, -s) - 15, 0, 0), "shin.R": (-55 * max(0.0, s) - 15, 0, 0),
            "foot.L": (15 * s, 0, 0), "foot.R": (-15 * s, 0, 0),
            "upper_arm.L": (-50 * s, 0, 12), "upper_arm.R": (50 * s, 0, -12),
            "forearm.L": (70, 0, 0), "forearm.R": (70, 0, 0),
            "root_z": 0.05 * abs(c) - 0.03,
        }
    make_action(arm_obj, "Run", [(1 + i * 2.5, run_pose(i * math.pi / 4)) for i in range(9)], cyclic=True)

    # Jump (rising): tucked legs, arms up. Holds on last frame.
    jump_a = {"spine": (-6, 0, 0), "thigh.L": (20, 0, 0), "thigh.R": (-10, 0, 0), "shin.L": (-30, 0, 0),
              "shin.R": (-20, 0, 0), "upper_arm.L": (40, 0, 30), "upper_arm.R": (40, 0, -30), "forearm.L": (40, 0, 0),
              "forearm.R": (40, 0, 0), "root_z": -0.05}
    jump_b = {"spine": (8, 0, 0), "head": (-10, 0, 0), "thigh.L": (60, 0, 0), "thigh.R": (10, 0, 0),
              "shin.L": (-80, 0, 0), "shin.R": (-50, 0, 0), "upper_arm.L": (160, 0, -25), "upper_arm.R": (-30, 0, -40),
              "forearm.L": (20, 0, 0), "forearm.R": (60, 0, 0)}
    make_action(arm_obj, "Jump", [(1, jump_a), (7, jump_b), (12, jump_b)])

    # Fall: arms out, legs reaching for the ground (loop with slight flail).
    fall_a = {"spine": (4, 0, 0), "head": (12, 0, 0), "thigh.L": (25, 0, 0), "thigh.R": (5, 0, 0),
              "shin.L": (-40, 0, 0), "shin.R": (-20, 0, 0), "upper_arm.L": (30, 0, 70), "upper_arm.R": (30, 0, -70),
              "forearm.L": (30, 0, 0), "forearm.R": (30, 0, 0)}
    fall_b = dict(fall_a, **{"upper_arm.L": (20, 0, 80), "upper_arm.R": (40, 0, -60), "thigh.L": (15, 0, 0),
                            "thigh.R": (15, 0, 0)})
    make_action(arm_obj, "Fall", [(1, fall_a), (11, fall_b), (21, fall_a)], cyclic=True)

    # Slide: lean back, front leg extended, low root.
    slide = {"root_z": -0.38, "hips": (-30, 0, 0), "spine": (-25, 0, 0), "head": (35, 0, 0),
             "thigh.R": (95, 0, 0), "shin.R": (-5, 0, 0), "foot.R": (-20, 0, 0),
             "thigh.L": (40, 0, 0), "shin.L": (-110, 0, 0),
             "upper_arm.L": (-40, 0, 40), "upper_arm.R": (-60, 0, -30), "forearm.L": (20, 0, 0), "forearm.R": (20, 0, 0)}
    slide_b = dict(slide, **{"upper_arm.L": (-45, 0, 45)})
    make_action(arm_obj, "Slide", [(1, slide), (6, slide_b), (11, slide)], cyclic=True)

    # Air dash: streamlined, one fist forward.
    dash = {"spine": (35, 0, 0), "head": (-30, 0, 0), "thigh.L": (-30, 0, 0), "thigh.R": (-15, 0, 0),
            "shin.L": (-40, 0, 0), "shin.R": (-60, 0, 0), "upper_arm.R": (170, 0, 5), "forearm.R": (5, 0, 0),
            "upper_arm.L": (-60, 0, 20), "forearm.L": (30, 0, 0)}
    make_action(arm_obj, "Dash", [(1, dash), (6, dash)], cyclic=True)

    # Throw: right arm whips forward (the yo-yo launches around frame 5).
    throw_a = dict(rest_arms, **{"upper_arm.R": (-70, 0, -30), "forearm.R": (80, 0, 0), "spine": (-6, 0, -15)})
    throw_b = dict(rest_arms, **{"upper_arm.R": (100, 0, -10), "forearm.R": (5, 0, 0), "spine": (10, 0, 12),
                                 "upper_arm.L": (-20, 0, 20)})
    make_action(arm_obj, "Throw", [(1, rest_arms), (4, throw_a), (8, throw_b), (14, rest_arms)])

    # Bounce: tuck pose (Godot adds the flip/spin on the visual root).
    tuck = {"root_z": 0.15, "spine": (30, 0, 0), "head": (20, 0, 0), "thigh.L": (100, 0, 0), "thigh.R": (100, 0, 0),
            "shin.L": (-130, 0, 0), "shin.R": (-130, 0, 0), "upper_arm.L": (60, 0, 20), "upper_arm.R": (60, 0, -20),
            "forearm.L": (90, 0, 0), "forearm.R": (90, 0, 0)}
    make_action(arm_obj, "Bounce", [(1, tuck), (6, tuck)], cyclic=True)

    # Land: squash recovery.
    land = dict(rest_arms, root_z=-0.12, spine=(20, 0, 0), **{"thigh.L": (40, 0, 0), "thigh.R": (40, 0, 0),
                                                            "shin.L": (-70, 0, 0), "shin.R": (-70, 0, 0)})
    make_action(arm_obj, "Land", [(1, land), (8, rest_arms)])

    # Victory: fist pump loop.
    vic_a = {"upper_arm.R": (170, 0, 25), "forearm.R": (20, 0, 0), "upper_arm.L": (0, 0, 30), "forearm.L": (60, 0, 0),
             "spine": (-8, 0, 0), "head": (-12, 0, 0)}
    vic_b = dict(vic_a, **{"upper_arm.R": (150, 0, 30), "forearm.R": (60, 0, 0), "root_z": 0.06})
    make_action(arm_obj, "Victory", [(1, vic_a), (9, vic_b), (17, vic_a)], cyclic=True)

    # Hurt: quick flinch (used on respawn).
    hurt = {"spine": (-25, 0, 10), "head": (-20, 0, 0), "upper_arm.L": (60, 0, 60), "upper_arm.R": (60, 0, -60),
            "forearm.L": (90, 0, 0), "forearm.R": (90, 0, 0), "thigh.L": (30, 0, 0), "shin.L": (-60, 0, 0)}
    make_action(arm_obj, "Hurt", [(1, rest_arms), (4, hurt), (14, hurt)])

    for action in bpy.data.actions:
        for fc in getattr(action, "fcurves", []):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"


def build_adventurer():
    C.use_collection("CHR_Adventurer")
    arm_obj = make_armature()
    build_body(arm_obj)
    build_animations(arm_obj)
    bpy.context.scene.frame_end = 60
    return C.save_and_export("CHR_Adventurer", export_animations=True)


def build_yoyo():
    C.use_collection("PROP_Yoyo")
    cyan = C.material("M_Yoyo", "yoyo", 0.35, emission="yoyo", emission_strength=0.8)
    orange = C.material("M_YoyoAccent", "yoyo_accent", 0.4, emission="yoyo_accent", emission_strength=0.4)
    core = C.material("M_YoyoCore", "yoyo_core", 0.3, emission="yoyo_core", emission_strength=0.5)
    # Spins around its local X axis in Godot (axle along Blender X).
    for side in (-1, 1):
        C.cylinder("Half_%d" % side, 0.2, 0.09, (side * 0.07, 0, 0), cyan, verts=20, rot=(0, 90, 0), bevel=0.02)
        C.torus("Ring_%d" % side, 0.13, 0.025, (side * 0.118, 0, 0), orange, major_segments=18, minor_segments=5,
                rot=(0, 90, 0))
    C.cylinder("Axle", 0.07, 0.07, (0, 0, 0), core, verts=12, rot=(0, 90, 0))
    return C.save_and_export("PROP_Yoyo")


def build_disc():
    C.use_collection("PROP_YoyoDisc")
    cyan = C.material("M_DiscCyan", "yoyo", 0.3, emission="yoyo", emission_strength=1.2)
    orange = C.material("M_YoyoAccent", "yoyo_accent", 0.4, emission="yoyo_accent", emission_strength=0.6)
    core = C.material("M_YoyoCore", "yoyo_core", 0.3, emission="yoyo_core", emission_strength=1.0)
    dark = C.material("M_DiscUnder", "#1c5a73", 0.5)
    # Deployed bounce disc, walkable top at z=0, radius 1.3 m. "Spin" spins around Z.
    C.cylinder("Under", 1.1, 0.16, (0, 0, -0.14), dark, verts=32, radius_top=1.3)
    spin = C.empty("Spin", (0, 0, 0))
    for obj in (
        C.cylinder("Top", 1.3, 0.08, (0, 0, -0.04), cyan, verts=32, bevel=0.03),
        C.torus("OuterRing", 1.12, 0.06, (0, 0, 0.01), orange, major_segments=32, minor_segments=6),
        C.torus("InnerRing", 0.62, 0.05, (0, 0, 0.01), C.material("M_White", "white", 0.6), major_segments=24,
                minor_segments=6),
        C.cylinder("Core", 0.28, 0.12, (0, 0, 0.0), core, verts=16),
    ):
        C.parent(obj, spin)
    for i in range(3):
        a = i * 2 * math.pi / 3
        mark = C.box("Mark_%d" % i, (0.3, 0.12, 0.03), (math.cos(a) * 0.88, math.sin(a) * 0.88, 0.01), orange, bevel=0.0,
                     rot=(0, 0, math.degrees(a)))
        C.parent(mark, spin)
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
