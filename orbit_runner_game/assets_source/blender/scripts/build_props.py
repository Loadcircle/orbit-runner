"""Builds Orbit Runner environment, platform, hazard and pickup assets.

Run headless (from any folder):
  blender --background --factory-startup --python build_props.py -- [ASSET ...]
Without names every asset is rebuilt. Each asset is saved as
assets_source/blender/<ASSET>.blend and exported to art/models/<ASSET>.glb.

Platform origin exception: platforms place their origin at the centre of the
walkable TOP surface so level layouts can use the walk height directly.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import or_common as C  # noqa: E402

PLATFORM_SIZES = {
    "S": (3.0, 3.0),
    "M": (4.0, 6.0),
    "L": (6.0, 10.0),
    "XL": (8.0, 14.0),
    "Strip": (2.5, 8.0),
    "Wide": (6.0, 6.0),
}


# ---------------------------------------------------------------- platforms

def isle_platform(size_key):
    sx, sy = PLATFORM_SIZES[size_key]
    name = "PLAT_Isle_" + size_key
    C.use_collection(name)
    grass = C.material("M_Grass", "grass", 0.85)
    grass_edge = C.material("M_GrassEdge", "grass_dark", 0.9)
    rock = C.material("M_Stone", "stone", 0.9)
    dirt = C.material("M_Dirt", "dirt", 0.95)
    C.box("Top", (sx, sy, 0.35), (0, 0, -0.175), grass, bevel=0.12, segments=3)
    C.box("TopLip", (sx - 0.1, sy - 0.1, 0.25), (0, 0, -0.42), grass_edge, bevel=0.08)
    C.box("Soil", (sx - 0.25, sy - 0.25, 0.4), (0, 0, -0.7), dirt, bevel=0.1)
    depth = min(2.4 + max(sx, sy) * 0.18, 4.5)
    C.island_underside("Underside", (sx - 0.2, sy - 0.2), depth, (0, 0, -0.85), rock, seed=len(name))
    # Pebbles on the top edges keep the outline readable but stay off the walkable centre.
    for i, (px, py) in enumerate([(0.42, 0.44), (-0.4, -0.38), (0.38, -0.45)]):
        if sx >= 4 or i == 0:
            C.rock_blob("Pebble_%d" % i, 0.18 + 0.05 * i, (px * sx, py * sy, 0.03), rock, seed=i + 3,
                        squash=(1.2, 1.0, 0.5))
    return C.save_and_export(name)


def toy_platform(size_key):
    sx, sy = PLATFORM_SIZES[size_key]
    name = "PLAT_Toy_" + size_key
    C.use_collection(name)
    cream = C.material("M_ToyTop", "#9edcb2", 0.65)
    teal = C.material("M_ToyTeal", "toy_teal", 0.55)
    red = C.material("M_ToyRed", "toy_red", 0.55)
    metal = C.material("M_Metal", "metal", 0.45, 0.6)
    C.box("Top", (sx, sy, 0.3), (0, 0, -0.15), cream, bevel=0.08)
    C.box("Band", (sx + 0.06, sy + 0.06, 0.28), (0, 0, -0.44), teal, bevel=0.06)
    C.box("Base", (sx - 0.3, sy - 0.3, 0.5), (0, 0, -0.83), metal, bevel=0.06)
    # Toy-block studs on the corners, red, to read as "safe toy surface".
    for ix in (-1, 1):
        for iy in (-1, 1):
            C.cylinder("Stud_%d_%d" % (ix, iy), 0.22, 0.12, (ix * (sx * 0.5 - 0.4), iy * (sy * 0.5 - 0.4), 0.06),
                       red, verts=16)
    # Support strut under the block.
    C.cylinder("Strut", 0.35, 3.0, (0, 0, -2.5), metal, verts=12)
    C.cylinder("StrutCap", 0.6, 0.25, (0, 0, -1.15), C.material("M_MetalDark", "metal_dark", 0.5, 0.6),
               verts=12)
    return C.save_and_export(name)


def ruin_platform(size_key):
    sx, sy = PLATFORM_SIZES[size_key]
    name = "PLAT_Ruin_" + size_key
    C.use_collection(name)
    sand = C.material("M_Sandstone", "sandstone", 0.9)
    sand_dark = C.material("M_SandstoneDark", "sandstone_dark", 0.95)
    tile = C.material("M_SandTile", "sand", 0.85)
    gold = C.material("M_Gold", "gold", 0.35, 0.8)
    # Tile grid on top: slight height jitter, never enough to trip the capsule.
    nx, ny = max(1, round(sx / 1.5)), max(1, round(sy / 1.5))
    tx, ty = sx / nx, sy / ny
    tiles = []
    for ix in range(nx):
        for iy in range(ny):
            cx = -sx * 0.5 + tx * (ix + 0.5)
            cy = -sy * 0.5 + ty * (iy + 0.5)
            tiles.append(C.box("Tile", (tx - 0.06, ty - 0.06, 0.25), (cx, cy, -0.125), tile, bevel=0.05))
    C.join(tiles, "Tiles")
    C.box("Slab", (sx, sy, 0.6), (0, 0, -0.55), sand, bevel=0.1)
    C.box("Trim", (sx + 0.1, sy + 0.1, 0.12), (0, 0, -0.32), gold, bevel=0.03)
    depth = 2.5
    C.island_underside("Underside", (sx - 0.4, sy - 0.4), depth, (0, 0, -0.85), sand_dark, seed=len(name) + 7)
    return C.save_and_export(name)


# ---------------------------------------------------------------- dynamic platforms

def moving_platform():
    name = "PLAT_Moving"
    C.use_collection(name)
    blue = C.material("M_TempBlue", "temp_dark", 0.5)
    cyan = C.material("M_TempCyan", "temp", 0.45, emission="temp", emission_strength=0.6)
    white = C.material("M_White", "white", 0.6)
    C.box("Body", (3.0, 3.0, 0.45), (0, 0, -0.225), blue, bevel=0.1)
    # Direction stripes (chevrons) on top: movement is communicated by shape, not only colour.
    for i, y in enumerate((-0.8, 0.0, 0.8)):
        C.prism("Chevron_%d" % i, [(-0.9, -0.2), (0, 0.25), (0.9, -0.2), (0.9, 0.1), (0, 0.55), (-0.9, 0.1)],
                0.03, (0, y - 0.15, 0.0), cyan)
    C.box("Rim", (3.15, 3.15, 0.12), (0, 0, -0.4), white, bevel=0.04)
    C.cylinder("Thruster", 0.45, 0.4, (0, 0, -0.65), cyan, verts=16, radius_top=0.6)
    return C.save_and_export(name)


def crumble_platform():
    name = "PLAT_Crumble"
    C.use_collection(name)
    cyan = C.material("M_CrumbleTile", "temp", 0.6)
    dark = C.material("M_CrumbleCrack", "temp_dark", 0.7)
    # Four separate tiles ("Tile_*") so Godot can shake and drop them individually.
    for ix in (-1, 1):
        for iy in (-1, 1):
            tile = C.box("Tile_%s%s" % ("L" if ix < 0 else "R", "B" if iy < 0 else "F"), (1.42, 1.42, 0.4),
                         (ix * 0.74, iy * 0.74, -0.2), cyan, bevel=0.07)
            crack = C.box("Crack_%s%s" % (ix, iy), (0.9, 0.08, 0.02), (ix * 0.74, iy * 0.74, 0.005), dark, bevel=0.0,
                          rot=(0, 0, 35 * ix * iy))
            C.parent(crack, tile)
    return C.save_and_export(name)


def timed_platform():
    name = "PLAT_Timed"
    C.use_collection(name)
    cyan = C.material("M_TimedTop", "temp", 0.45, emission="temp", emission_strength=0.4)
    blue = C.material("M_TempBlue", "temp_dark", 0.5)
    white = C.material("M_White", "white", 0.6)
    C.cylinder("Top", 1.6, 0.3, (0, 0, -0.15), cyan, verts=6, bevel=0.06)
    C.cylinder("Base", 1.45, 0.35, (0, 0, -0.45), blue, verts=6, bevel=0.05)
    C.torus("Band", 1.05, 0.05, (0, 0, 0.0), white, major_segments=6, minor_segments=4)
    return C.save_and_export(name)


# ---------------------------------------------------------------- impulse props

def trampoline():
    name = "PROP_Trampoline"
    C.use_collection(name)
    orange = C.material("M_ImpulseOrange", "impulse_dark", 0.55)
    yellow = C.material("M_ImpulseYellow", "impulse", 0.45, emission="impulse", emission_strength=0.35)
    dark = C.material("M_Dark", "dark", 0.7)
    white = C.material("M_White", "white", 0.6)
    C.cylinder("Base", 1.15, 0.35, (0, 0, 0.175), dark, verts=24, bevel=0.06)
    C.cylinder("Ring", 1.1, 0.18, (0, 0, 0.42), orange, verts=24, bevel=0.05)
    pad = C.cylinder("Pad", 0.92, 0.12, (0, 0, 0.5), yellow, verts=24, bevel=0.04)
    # Up-arrow glyph on the pad (separate node, parented so it squashes with the pad).
    arrow = C.prism("Arrow", [(-0.18, -0.45), (0.18, -0.45), (0.18, 0.0), (0.42, 0.0), (0.0, 0.48),
                               (-0.42, 0.0), (-0.18, 0.0)], 0.03, (0, 0, 0.56), white)
    C.parent(arrow, pad)
    for i in range(6):
        a = i * math.pi / 3
        C.cylinder("Spring_%d" % i, 0.07, 0.25, (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.42), white, verts=8)
    return C.save_and_export(name)


def wind_ring():
    name = "PROP_WindRing"
    C.use_collection(name)
    white = C.material("M_White", "white", 0.6)
    cyan = C.material("M_WindCyan", "temp", 0.4, emission="temp", emission_strength=0.8)
    dark = C.material("M_MetalDark", "metal_dark", 0.5, 0.6)
    C.torus("Ring", 1.5, 0.16, (0, 0, 0.35), white)
    C.torus("Glow", 1.3, 0.06, (0, 0, 0.42), cyan, minor_segments=6)
    for i in range(3):
        a = i * 2 * math.pi / 3
        C.box("Leg_%d" % i, (0.25, 0.25, 0.35), (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.175), dark, bevel=0.05)
    rotor = C.empty("Rotor", (0, 0, 0.3))
    hub = C.cylinder("Hub", 0.25, 0.2, (0, 0, 0.3), dark, verts=12)
    C.parent(hub, rotor)
    for i in range(4):
        blade = C.box("Blade_%d" % i, (1.0, 0.22, 0.04), (0.6, 0, 0.3), white, bevel=0.0, rot=(20, 0, 0))
        blade.rotation_euler.z = i * math.pi / 2
        blade.location = (math.cos(i * math.pi / 2) * 0.6, math.sin(i * math.pi / 2) * 0.6, 0.3)
        C.parent(blade, rotor)
    return C.save_and_export(name)


def boost_pad():
    name = "PROP_BoostPad"
    C.use_collection(name)
    orange = C.material("M_ImpulseOrange", "impulse_dark", 0.55)
    yellow = C.material("M_ImpulseYellow", "impulse", 0.45, emission="impulse", emission_strength=0.5)
    C.box("Plate", (2.2, 3.2, 0.12), (0, 0, 0.06), orange, bevel=0.04)
    for i, y in enumerate((-0.9, 0.0, 0.9)):
        C.prism("Chevron_%d" % i, [(-0.8, -0.25), (0, 0.25), (0.8, -0.25), (0.8, 0.05), (0, 0.55), (-0.8, 0.05)],
                0.04, (0, y - 0.15, 0.12), yellow)
    return C.save_and_export(name)


# ---------------------------------------------------------------- progress props

def checkpoint():
    name = "PROP_Checkpoint"
    C.use_collection(name)
    stone = C.material("M_Stone", "stone", 0.9)
    white = C.material("M_White", "white", 0.6)
    flag_mat = C.material("M_Flag", "temp", 0.6)
    C.cylinder("Base", 0.55, 0.25, (0, 0, 0.125), stone, verts=10, bevel=0.04)
    C.cylinder("Pole", 0.07, 2.4, (0, 0, 1.45), white, verts=10)
    C.sphere("Knob", 0.13, (0, 0, 2.68), C.material("M_Gold", "gold", 0.35, 0.8), segments=12, rings=8)
    flag = C.empty("Flag", (0.07, 0, 2.45))
    cloth = C.prism("Cloth", [(0, -0.02), (0.9, -0.02), (0.75, 0.0), (0.9, 0.02), (0, 0.02)], 0.6,
                    (0.07, 0, 1.85), flag_mat)
    C.parent(cloth, flag)
    return C.save_and_export(name)


def gem():
    name = "PROP_Gem"
    C.use_collection(name)
    gem_mat = C.material("M_Gem", "#6fdcff", 0.15, 0.1, emission="#4fc8ff", emission_strength=0.9)
    import bmesh
    bm = bmesh.new()
    top = bm.verts.new((0, 0, 0.55))
    bottom = bm.verts.new((0, 0, -0.45))
    ring = [bm.verts.new((math.cos(i * math.pi / 4) * 0.38, math.sin(i * math.pi / 4) * 0.38, 0.12)) for i in range(8)]
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((ring[i], ring[j], top))
        bm.faces.new((ring[j], ring[i], bottom))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    C._mesh_object("Gem", bm, gem_mat, smooth=False)
    return C.save_and_export(name)


def spark():
    name = "PROP_Spark"
    C.use_collection(name)
    mat = C.material("M_Spark", "impulse", 0.3, emission="impulse_dark", emission_strength=1.2)
    pts = []
    for i in range(8):
        r = 0.32 if i % 2 == 0 else 0.12
        a = i * math.pi / 4 + math.pi / 2
        pts.append((math.cos(a) * r, math.sin(a) * r))
    star = C.prism("Spark", pts, 0.1, (0, 0.05, 0), mat, rot=(90, 0, 0))
    return C.save_and_export(name)


def goal_gate():
    name = "PROP_GoalGate"
    C.use_collection(name)
    white = C.material("M_White", "white", 0.6)
    gold = C.material("M_Gold", "gold", 0.35, 0.8)
    cyan = C.material("M_GoalGlow", "yoyo", 0.4, emission="yoyo", emission_strength=1.2)
    orange = C.material("M_ImpulseOrange", "impulse_dark", 0.55)
    for side in (-1, 1):
        C.box("Pillar_%d" % side, (0.7, 0.7, 4.0), (side * 2.6, 0, 2.0), white, bevel=0.1)
        C.box("PillarBand_%d" % side, (0.78, 0.78, 0.3), (side * 2.6, 0, 3.4), orange, bevel=0.05)
        C.box("PillarFoot_%d" % side, (1.0, 1.0, 0.4), (side * 2.6, 0, 0.2), gold, bevel=0.06)
    C.torus("Halo", 2.1, 0.2, (0, 0, 4.4), gold, rot=(90, 0, 0))
    C.torus("HaloGlow", 1.75, 0.08, (0, 0, 4.4), cyan, rot=(90, 0, 0), minor_segments=6)
    C.box("Lintel", (5.9, 0.6, 0.45), (0, 0, 4.2), white, bevel=0.08)
    return C.save_and_export(name)


# ---------------------------------------------------------------- hazards

def spinner():
    name = "HAZ_Spinner"
    C.use_collection(name)
    purple = C.material("M_HazardPurple", "hazard_dark", 0.5)
    magenta = C.material("M_Hazard", "hazard", 0.45, emission="hazard", emission_strength=0.6)
    dark = C.material("M_Dark", "dark", 0.7)
    C.cylinder("Hub", 0.6, 1.2, (0, 0, 0.6), dark, verts=16, bevel=0.06)
    arm = C.empty("Arm", (0, 0, 0.7))
    bar = C.box("Bar", (6.0, 0.4, 0.4), (0, 0, 0.7), purple, bevel=0.08)
    C.parent(bar, arm)
    for i, x in enumerate((-2.4, -1.2, 1.2, 2.4)):
        stripe = C.box("Stripe_%d" % i, (0.3, 0.44, 0.44), (x, 0, 0.7), magenta, bevel=0.04)
        C.parent(stripe, arm)
    for side in (-1, 1):
        ball = C.ico("Ball_%d" % side, 0.38, (side * 3.0, 0, 0.7), magenta, subdivisions=1)
        C.parent(ball, arm)
        for k in range(6):
            dirs = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)][k]
            spike = C.cone("Spike_%d_%d" % (side, k), 0.12, 0.35,
                           (side * 3.0 + dirs[0] * 0.45, dirs[1] * 0.45, 0.7 + dirs[2] * 0.45), purple, verts=6)
            spike.rotation_mode = "QUATERNION"
            from mathutils import Vector
            spike.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(dirs))
            C.parent(spike, arm)
    return C.save_and_export(name)


def spikes():
    name = "HAZ_Spikes"
    C.use_collection(name)
    dark = C.material("M_Dark", "dark", 0.7)
    magenta = C.material("M_Hazard", "hazard", 0.45, emission="hazard", emission_strength=0.6)
    purple = C.material("M_HazardPurple", "hazard_dark", 0.5)
    C.box("Base", (2.0, 2.0, 0.15), (0, 0, 0.075), dark, bevel=0.03)
    spikes_list = []
    for ix in range(4):
        for iy in range(4):
            x = -0.75 + ix * 0.5
            y = -0.75 + iy * 0.5
            spikes_list.append(C.cone("Spike", 0.2, 0.55, (x, y, 0.42), purple if (ix + iy) % 2 else magenta, verts=4,
                                      rot=(0, 0, 45)))
    C.join(spikes_list, "Spikes")
    return C.save_and_export(name)


def patrol_bot():
    name = "HAZ_PatrolBot"
    C.use_collection(name)
    purple = C.material("M_HazardPurple", "hazard_dark", 0.5)
    magenta = C.material("M_Hazard", "hazard", 0.45, emission="hazard", emission_strength=0.6)
    white = C.material("M_White", "white", 0.6)
    dark = C.material("M_Dark", "dark", 0.7)
    body = C.ico("Body", 0.6, (0, 0, 0), purple, subdivisions=2, smooth=True)
    C.torus("Band", 0.6, 0.07, (0, 0, 0), magenta, minor_segments=6)
    C.sphere("Eye", 0.2, (0, 0.52, 0.12), white, segments=12, rings=8, scale=(1, 0.5, 1))
    C.sphere("Pupil", 0.09, (0, 0.6, 0.12), dark, segments=10, rings=6, scale=(1, 0.5, 1))
    from mathutils import Vector
    spikes_list = []
    for k in range(14):
        # Fibonacci sphere distribution for the spikes.
        y = 1 - (k / 13.0) * 2
        r = math.sqrt(max(0.0, 1 - y * y))
        theta = k * 2.399963
        d = Vector((math.cos(theta) * r, y, math.sin(theta) * r))
        if d.y > 0.7:
            continue
        spike = C.cone("Spike", 0.13, 0.4, tuple(d * 0.68), magenta, verts=5)
        spike.rotation_mode = "QUATERNION"
        spike.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        spikes_list.append(spike)
    C.join(spikes_list, "Spikes")
    return C.save_and_export(name)


def laser_post():
    name = "HAZ_LaserPost"
    C.use_collection(name)
    dark = C.material("M_Dark", "dark", 0.7)
    magenta = C.material("M_Hazard", "hazard", 0.45, emission="hazard", emission_strength=0.9)
    stripe = C.material("M_ImpulseYellow", "impulse", 0.45)
    C.box("Post", (0.4, 0.4, 2.2), (0, 0, 1.1), dark, bevel=0.06)
    for i in range(3):
        C.box("Warn_%d" % i, (0.44, 0.44, 0.12), (0, 0, 0.3 + i * 0.25), stripe, bevel=0.02)
    C.cylinder("Emitter", 0.16, 0.2, (0, 0, 1.05), magenta, verts=12, rot=(90, 0, 90))
    C.sphere("Lamp", 0.14, (0, 0, 2.28), magenta, segments=12, rings=8)
    return C.save_and_export(name)


# ---------------------------------------------------------------- decoration

def tree():
    name = "ENV_Tree"
    C.use_collection(name)
    wood = C.material("M_Wood", "wood", 0.9)
    leaf = C.material("M_Leaf", "leaf", 0.85)
    leaf2 = C.material("M_LeafLight", "leaf_light", 0.85)
    C.cylinder("Trunk", 0.28, 2.6, (0, 0, 1.3), wood, verts=8, radius_top=0.18, smooth=False)
    C.cylinder("Branch", 0.1, 1.1, (0.35, 0, 2.1), wood, verts=6, rot=(0, 50, 0), smooth=False)
    C.ico("Crown", 1.35, (0, 0, 3.1), leaf, subdivisions=1, scale=(1.1, 1.1, 0.85))
    C.ico("CrownB", 0.9, (0.9, 0.3, 2.7), leaf2, subdivisions=1)
    C.ico("CrownC", 0.8, (-0.8, -0.4, 2.8), leaf2, subdivisions=1)
    return C.save_and_export(name)


def pine():
    name = "ENV_Pine"
    C.use_collection(name)
    wood = C.material("M_Wood", "wood", 0.9)
    leaf = C.material("M_LeafDark", "grass_dark", 0.85)
    C.cylinder("Trunk", 0.2, 1.2, (0, 0, 0.6), wood, verts=6, smooth=False)
    for i, (r, z) in enumerate(((1.3, 1.6), (1.0, 2.5), (0.7, 3.3))):
        C.cone("Tier_%d" % i, r, 1.4, (0, 0, z), leaf, verts=7)
    return C.save_and_export(name)


def bush():
    name = "ENV_Bush"
    C.use_collection(name)
    leaf = C.material("M_Leaf", "leaf", 0.85)
    leaf2 = C.material("M_LeafLight", "leaf_light", 0.85)
    C.ico("A", 0.6, (0, 0, 0.4), leaf, subdivisions=1)
    C.ico("B", 0.45, (0.55, 0.1, 0.3), leaf2, subdivisions=1)
    C.ico("C", 0.4, (-0.5, -0.1, 0.28), leaf2, subdivisions=1)
    return C.save_and_export(name)


def rocks():
    out = []
    for key, seed, scale in (("A", 11, (1.3, 1.0, 0.8)), ("B", 23, (0.9, 0.9, 1.4))):
        C.reset_scene()
        name = "ENV_Rock_" + key
        C.use_collection(name)
        stone = C.material("M_Stone", "stone", 0.9)
        dark = C.material("M_StoneDark", "stone_dark", 0.95)
        C.rock_blob("Rock", 0.8, (0, 0, 0.45), stone, seed=seed, squash=scale)
        C.rock_blob("Chip", 0.35, (0.7, 0.3, 0.2), dark, seed=seed + 1)
        out.append(C.save_and_export(name))
    return out


def cloud():
    name = "ENV_Cloud"
    C.use_collection(name)
    white = C.material("M_Cloud", "cloud", 1.0, emission="#ffffff", emission_strength=0.25)
    for i, (x, y, z, r) in enumerate(((0, 0, 0, 2.0), (2.2, 0.3, -0.3, 1.5), (-2.1, -0.2, -0.4, 1.4),
                                      (0.9, 0.8, 0.9, 1.3), (-0.8, -0.6, 0.7, 1.2))):
        C.ico("Puff_%d" % i, r, (x, y, z), white, subdivisions=2, smooth=True, scale=(1, 1, 0.75))
    return C.save_and_export(name)


def ruin_pillar():
    name = "ENV_RuinPillar"
    C.use_collection(name)
    sand = C.material("M_Sandstone", "sandstone", 0.9)
    tile = C.material("M_SandTile", "sand", 0.85)
    C.box("Foot", (1.2, 1.2, 0.4), (0, 0, 0.2), sand, bevel=0.06)
    C.cylinder("Shaft", 0.42, 3.2, (0, 0, 2.0), tile, verts=10, bevel=0.03)
    C.box("Capital", (1.1, 1.1, 0.35), (0, 0, 3.75), sand, bevel=0.06)
    C.box("Broken", (0.6, 0.5, 0.3), (0.2, 0.1, 4.05), tile, bevel=0.06, rot=(8, -6, 20))
    return C.save_and_export(name)


def ruin_arch():
    name = "ENV_RuinArch"
    C.use_collection(name)
    sand = C.material("M_Sandstone", "sandstone", 0.9)
    gold = C.material("M_Gold", "gold", 0.35, 0.8)
    for side in (-1, 1):
        C.box("Leg_%d" % side, (0.9, 0.9, 4.0), (side * 2.0, 0, 2.0), sand, bevel=0.08)
    C.box("Top", (5.2, 1.0, 0.8), (0, 0, 4.4), sand, bevel=0.1)
    C.prism("Sun", [(math.cos(i * math.pi / 6) * (0.5 if i % 2 else 0.3), math.sin(i * math.pi / 6) *
                     (0.5 if i % 2 else 0.3)) for i in range(12)], 0.1, (0, -0.52, 4.4), gold, rot=(90, 0, 0))
    return C.save_and_export(name)


def obelisk():
    name = "ENV_Obelisk"
    C.use_collection(name)
    sand = C.material("M_SandstoneDark", "sandstone_dark", 0.95)
    turq = C.material("M_Turquoise", "turquoise", 0.4, emission="turquoise", emission_strength=0.5)
    C.box("Base", (1.6, 1.6, 0.6), (0, 0, 0.3), sand, bevel=0.08)
    C.cylinder("Body", 0.55, 5.0, (0, 0, 3.1), sand, verts=4, radius_top=0.35, rot=(0, 0, 45), smooth=False)
    C.cone("Tip", 0.36, 0.7, (0, 0, 5.95), turq, verts=4, rot=(0, 0, 45))
    return C.save_and_export(name)


def palm():
    name = "ENV_Palm"
    C.use_collection(name)
    wood = C.material("M_PalmWood", "#b88a52", 0.9)
    leaf = C.material("M_Leaf", "leaf", 0.85)
    segs = []
    for i in range(6):
        segs.append(C.cylinder("Seg_%d" % i, 0.22 - i * 0.015, 0.75, (i * 0.08, 0, 0.375 + i * 0.7), wood, verts=7,
                               rot=(0, 6, 0), smooth=False))
    C.join(segs, "Trunk")
    for i in range(6):
        a = i * math.pi / 3
        frond = C.box("Frond_%d" % i, (2.0, 0.5, 0.06), (math.cos(a) * 1.0 + 0.45, math.sin(a) * 1.0, 4.35), leaf,
                      bevel=0.0, rot=(0, 18, math.degrees(a)))
    return C.save_and_export(name)


def crystal():
    name = "ENV_Crystal"
    C.use_collection(name)
    mat = C.material("M_Crystal", "turquoise", 0.25, emission="turquoise", emission_strength=0.6)
    for i, (x, y, h, tilt) in enumerate(((0, 0, 1.6, 0), (0.45, 0.2, 1.0, 20), (-0.4, 0.15, 0.8, -25))):
        C.cylinder("Shard_%d" % i, 0.25, h, (x, y, h * 0.5), mat, verts=6, radius_top=0.05, rot=(tilt, 0, 0),
                   smooth=False)
    return C.save_and_export(name)


def gear_deco():
    name = "ENV_Gear"
    C.use_collection(name)
    metal = C.material("M_Metal", "metal", 0.45, 0.6)
    red = C.material("M_ToyRed", "toy_red", 0.55)
    rotor = C.empty("Rotor", (0, 0, 0))
    pts = []
    teeth = 12
    for i in range(teeth * 2):
        a = i * math.pi / teeth
        r = 2.0 if i % 2 == 0 else 1.6
        pts.append((math.cos(a) * r, math.sin(a) * r))
    g = C.prism("Gear", pts, 0.5, (0, 0, -0.25), metal, bevel=0.03)
    C.parent(g, rotor)
    hub = C.cylinder("Hub", 0.5, 0.7, (0, 0, 0), red, verts=12)
    C.parent(hub, rotor)
    # Gear stands vertically (rotates around the Y axis in Blender => Z in Godot).
    rotor.rotation_euler = (math.radians(90), 0, 0)
    return C.save_and_export(name)


def toy_blocks():
    name = "ENV_ToyBlocks"
    C.use_collection(name)
    cols = ["toy_red", "toy_teal", "impulse", "temp_dark", "cream"]
    for i, (x, y, z, rz) in enumerate(((0, 0, 0.5, 0), (1.05, 0.1, 0.5, 10), (0.5, 0.0, 1.5, 25), (-0.9, 0.4, 0.5, -15))):
        C.box("Block_%d" % i, (1.0, 1.0, 1.0), (x, y, z), C.material("M_Block_" + cols[i], cols[i], 0.55),
              bevel=0.1, rot=(0, 0, rz))
    return C.save_and_export(name)


def lamp_post():
    name = "ENV_LampPost"
    C.use_collection(name)
    dark = C.material("M_MetalDark", "metal_dark", 0.5, 0.6)
    glow = C.material("M_LampGlow", "#fff1c1", 0.4, emission="#ffd98a", emission_strength=1.5)
    C.cylinder("Pole", 0.08, 3.0, (0, 0, 1.5), dark, verts=8)
    C.sphere("Lamp", 0.28, (0, 0, 3.15), glow, segments=12, rings=8)
    C.cylinder("Hat", 0.32, 0.12, (0, 0, 3.42), dark, verts=8, radius_top=0.05)
    return C.save_and_export(name)


BUILDERS = {
    "PLAT_Moving": moving_platform, "PLAT_Crumble": crumble_platform, "PLAT_Timed": timed_platform,
    "PROP_Trampoline": trampoline, "PROP_WindRing": wind_ring, "PROP_BoostPad": boost_pad,
    "PROP_Checkpoint": checkpoint, "PROP_Gem": gem, "PROP_Spark": spark, "PROP_GoalGate": goal_gate,
    "HAZ_Spinner": spinner, "HAZ_Spikes": spikes, "HAZ_PatrolBot": patrol_bot, "HAZ_LaserPost": laser_post,
    "ENV_Tree": tree, "ENV_Pine": pine, "ENV_Bush": bush, "ENV_Rock": rocks, "ENV_Cloud": cloud,
    "ENV_RuinPillar": ruin_pillar, "ENV_RuinArch": ruin_arch, "ENV_Obelisk": obelisk, "ENV_Palm": palm,
    "ENV_Crystal": crystal, "ENV_Gear": gear_deco, "ENV_ToyBlocks": toy_blocks, "ENV_LampPost": lamp_post,
}
for _key in PLATFORM_SIZES:
    BUILDERS["PLAT_Isle_" + _key] = (lambda k=_key: isle_platform(k))
    BUILDERS["PLAT_Toy_" + _key] = (lambda k=_key: toy_platform(k))
    BUILDERS["PLAT_Ruin_" + _key] = (lambda k=_key: ruin_platform(k))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    argv = [a for a in argv if a and a != "ALL"]
    names = argv or list(BUILDERS.keys())
    report = []
    log_path = os.path.join(C.BLEND_DIR, "scripts", "last_build.log")
    for n in names:
        with open(log_path, "a", encoding="utf-8") as log:
            log.write("building %s\n" % n)
        C.reset_scene()
        res = BUILDERS[n]()
        report.extend(res if isinstance(res, list) else [res])
    report_path = os.path.join(C.BLEND_DIR, "scripts", "last_build_report.json")
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1)
    print("ORBIT_BUILD_DONE", len(report))


if __name__ == "__main__":
    main()
