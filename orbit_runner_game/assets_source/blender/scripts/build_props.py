"""Builds Orbit Runner environment, platform, hazard and pickup assets.

Run headless (from any folder):
  blender --background --factory-startup --python build_props.py -- [ASSET ...]
Without names every asset is rebuilt. Each asset is saved as
assets_source/blender/<ASSET>.blend and exported to art/models/<ASSET>.glb.

v2 (2026-10-17) "vivid" pass: hand-painted look through the "Col" vertex
attribute (gradients, strata, per-face value jitter) on white vcol materials,
so most assets draw with one or two surfaces. Platforms get a grass lip with
drips / toy panels / carved trims and a glowing edge line (jumpable cue from
the concept art); pickups and hazards get inverted-hull outlines for contrast.

Platform origin exception: platforms place their origin at the centre of the
walkable TOP surface so level layouts can use the walk height directly.
"""
import json
import math
import os
import random
import sys

import bmesh
from mathutils import Vector

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


def col(name):
    return Vector(C.hex_rgba(name)[:3])


def mix(a, b, t):
    return col(a).lerp(col(b), t)


def to_hex(v):
    def enc(c):
        c = max(0.0, min(1.0, c))
        s = c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        return int(round(s * 255))
    return "#%02x%02x%02x" % (enc(v.x), enc(v.y), enc(v.z))


def ground_mat(name, roughness=0.85):
    return C.material(name, "#ffffff", roughness, vcol=True)


def glow_mat():
    return C.material("M_EdgeGlow", "glow", 0.3, emission="glow", emission_strength=1.8)


def outline_mat(name="M_Outline", color="ink"):
    return C.material(name, color, 1.0)


def loft_points(name, rings, mat, cap_top=False, tip=None, smooth=False, close_bottom=False):
    """Like C.loft but each ring is a list of (x, y, z) (rings may be wavy)."""
    bm = bmesh.new()
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(verts[0])
    if cap_top:
        c = Vector((0, 0, 0))
        for p in rings[0]:
            c += Vector(p)
        center = bm.verts.new(c / n)
        for i in range(n):
            bm.faces.new((center, verts[0][i], verts[0][(i + 1) % n]))
    for r in range(len(verts) - 1):
        a, b = verts[r], verts[r + 1]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], b[i], b[j], a[j]))
    if tip is not None:
        t = bm.verts.new(tip)
        for i in range(n):
            bm.faces.new((verts[-1][i], t, verts[-1][(i + 1) % n]))
    elif close_bottom:
        bm.faces.new(list(reversed(verts[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return C._mesh_object(name, bm, mat, smooth)


def paint_faces(obj, fn, seed=0, jitter=0.0):
    """fn(center, normal, face_index) -> Vector colour (linear)."""
    rng = random.Random(seed)
    mesh = obj.data
    attr = C._color_attr(mesh)
    for poly in mesh.polygons:
        c = fn(poly.center, poly.normal, poly.index) * (1.0 + rng.uniform(-jitter, jitter))
        for li in poly.loop_indices:
            attr.data[li].color = (c.x, c.y, c.z, 1.0)
    return obj


def paint_verts(obj, fn):
    """fn(co, normal) -> Vector colour, smooth per vertex."""
    mesh = obj.data
    attr = C._color_attr(mesh)
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            c = fn(v.co, poly.normal)
            attr.data[li].color = (c.x, c.y, c.z, 1.0)
    return obj


def slice_mesh(obj, axis, step):
    """Cuts the base mesh with parallel planes every `step` metres along the
    local axis (0=x, 1=y, 2=z) so per-face painting can draw bands/checkers."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    coords = [v.co[axis] for v in bm.verts]
    lo, hi = min(coords), max(coords)
    normal = Vector((0, 0, 0))
    normal[axis] = 1.0
    k = math.floor(lo / step) + 1
    while k * step < hi - 1e-4:
        co = Vector((0, 0, 0))
        co[axis] = k * step
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=normal)
        k += 1
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def star_points(points, r_out, r_in, phase=math.pi / 2):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = i * math.pi / points + phase
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def grass_tuft(name, loc, mat, rng, height=0.16, color="grass_light"):
    blades = []
    for k in range(3):
        a = k * 2.1 + rng.uniform(-0.4, 0.4)
        blade = C.cone("%s_%d" % (name, k), 0.05, height * rng.uniform(0.8, 1.2),
                       (loc[0] + math.cos(a) * 0.04, loc[1] + math.sin(a) * 0.04, loc[2] + height * 0.45), mat,
                       verts=3, rot=(math.degrees(math.sin(a)) * 0.35, math.degrees(math.cos(a)) * 0.35, 0))
        C.paint(blade, color, bottom="grass_dark")
        blades.append(blade)
    return blades


def flower(name, loc, mat, petal_color, rng):
    parts = []
    stem = C.cylinder(name + "_Stem", 0.012, 0.16, (loc[0], loc[1], loc[2] + 0.08), mat, verts=4, smooth=False)
    C.paint(stem, "grass_dark")
    parts.append(stem)
    for k in range(5):
        a = k * 2 * math.pi / 5 + rng.uniform(0, 0.4)
        petal = C.sphere(name + "_P%d" % k, 0.035, (loc[0] + math.cos(a) * 0.04, loc[1] + math.sin(a) * 0.04,
                                                    loc[2] + 0.17), mat, segments=6, rings=4, scale=(1, 1, 0.45))
        C.paint(petal, petal_color)
        parts.append(petal)
    core = C.sphere(name + "_Core", 0.025, (loc[0], loc[1], loc[2] + 0.18), mat, segments=6, rings=4)
    C.paint(core, "impulse")
    parts.append(core)
    return parts


def edge_points(hx, hy, rng, inset=0.35, count=10):
    """Random points in a band along the inside of the platform edge."""
    pts = []
    for _ in range(count):
        side = rng.randrange(4)
        t = rng.uniform(-0.9, 0.9)
        d = rng.uniform(0.12, inset)
        if side == 0:
            pts.append((t * hx, hy - d))
        elif side == 1:
            pts.append((t * hx, -hy + d))
        elif side == 2:
            pts.append((hx - d, t * hy))
        else:
            pts.append((-hx + d, t * hy))
    return pts


# ---------------------------------------------------------------- platforms

def isle_platform(size_key):
    sx, sy = PLATFORM_SIZES[size_key]
    hx, hy = sx * 0.5, sy * 0.5
    name = "PLAT_Isle_" + size_key
    C.use_collection(name)
    rng = random.Random(len(name) * 31 + int(sx * 7 + sy))
    ground = ground_mat("M_IsleGround")
    glow = glow_mat()
    n = int(28 + (sx + sy) * 2.2)
    base = C.superellipse(hx, hy, n, power=0.22)
    phase = rng.uniform(0, 6.28)

    def ring(scale, z, jitter=0.0, drop=None):
        pts = []
        for i, (x, y) in enumerate(base):
            j = 1.0 + (rng.uniform(-jitter, jitter) if jitter else 0.0)
            zz = z - (drop(i) if drop else 0.0)
            pts.append((x * scale * j, y * scale * j, zz))
        return pts

    def drip(i):
        w = math.sin(i * 1.7 + phase) * 0.5 + 0.5
        w2 = math.sin(i * 0.63 + phase * 1.3) * 0.5 + 0.5
        return 0.05 + 0.22 * (w ** 2.5) * (0.6 + 0.4 * w2)

    drops = [drip(i) for i in range(n)]
    grass = loft_points("Grass", [
        ring(1.0, 0.0), ring(1.012, -0.05), ring(1.022, -0.16),
        ring(1.024, -0.24, drop=lambda i: drops[i]), ring(0.99, -0.22, drop=lambda i: drops[i] * 0.85),
    ], ground, cap_top=True, smooth=True)
    C.smooth_by_angle(grass, 50)

    def grass_color(co, normal):
        if normal.z > 0.6:
            # Lighter, sunlit centre; edges slightly deeper green.
            d = max(abs(co.x) / hx, abs(co.y) / hy)
            return mix("grass_light", "grass", min(1.0, 0.25 + d * 0.9))
        return mix("grass", "grass_dark", min(1.0, -co.z / 0.35))
    paint_verts(grass, grass_color)

    depth = min(2.2 + max(sx, sy) * 0.2, 4.6)
    cliff_rings = [ring(0.99, -0.18)]
    levels = [(-0.55, 0.975, 0.02), (-0.95, 0.94, 0.04), (-1.35, 0.86, 0.06), (-depth * 0.62, 0.66, 0.08),
              (-depth * 0.85, 0.4, 0.1)]
    for z, s, j in levels:
        cliff_rings.append(ring(s, z, jitter=j))
    cliff = loft_points("Cliff", cliff_rings, ground, tip=(rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), -depth * 1.1))
    strata = [col("cliff"), mix("cliff", "cliff_dark", 0.35), col("cliff"), mix("cliff", "cliff_dark", 0.6),
              col("cliff_dark"), col("rock")]

    def cliff_color(center, normal, idx):
        band = int(min(len(strata) - 1, max(0, (-center.z - 0.1) / (depth * 0.2))))
        c = strata[band]
        if normal.z < -0.3:
            c = c * 0.8
        return c
    paint_faces(cliff, cliff_color, seed=n, jitter=0.07)

    band = loft_points("EdgeGlow", [ring(1.0, -0.25), ring(1.0, -0.33)], glow, smooth=True)
    C.paint(band, "#ffffff")

    deco = []
    k = 0
    tuft_count = int(6 + (sx + sy) * 1.2)
    for (x, y) in edge_points(hx, hy, rng, 0.5, tuft_count):
        deco += grass_tuft("Tuft_%d" % k, (x, y, 0.0), ground, rng)
        k += 1
    petals = ["#ffffff", "#ff7ab8", "#ffd93b", "#b98cff"]
    for i, (x, y) in enumerate(edge_points(hx, hy, rng, 0.45, int(2 + (sx + sy) * 0.4))):
        deco += flower("Flower_%d" % i, (x, y, 0.0), ground, rng.choice(petals), rng)
    for i, (x, y) in enumerate(edge_points(hx, hy, rng, 0.3, 2 if sx >= 4 else 1)):
        pebble = C.rock_blob("Pebble_%d" % i, 0.16 + 0.05 * i, (x, y, 0.02), ground, seed=i + 3, squash=(1.2, 1.0, 0.5))
        C.paint(pebble, "stone", bottom="stone_dark", jitter=0.08, seed=i)
        deco.append(pebble)
    # Hanging rocks under the island break the cone silhouette.
    for i in range(2 if sx >= 4 else 1):
        a = rng.uniform(0, 6.28)
        rock = C.rock_blob("Hang_%d" % i, rng.uniform(0.35, 0.6), (math.cos(a) * hx * 0.5, math.sin(a) * hy * 0.5,
                                                                    -depth * 0.55), ground, seed=40 + i,
                           squash=(1.0, 1.0, 1.3))
        C.paint(rock, "cliff_dark", bottom="rock", jitter=0.08, seed=i)
        deco.append(rock)
    C.join([grass, cliff] + deco, "Ground")
    return C.save_and_export(name)


def toy_platform(size_key):
    sx, sy = PLATFORM_SIZES[size_key]
    hx, hy = sx * 0.5, sy * 0.5
    name = "PLAT_Toy_" + size_key
    C.use_collection(name)
    body = ground_mat("M_ToyBody", 0.45)
    glow = glow_mat()
    parts = []
    # Checkered toy mat on top (two tones), slightly gapped tiles.
    nx, ny = max(2, round(sx / 1.0)), max(2, round(sy / 1.0))
    tx, ty = sx / nx, sy / ny
    tiles = []
    for ix in range(nx):
        for iy in range(ny):
            cx = -hx + tx * (ix + 0.5)
            cy = -hy + ty * (iy + 0.5)
            t = C.box("Tile", (tx - 0.04, ty - 0.04, 0.2), (cx, cy, -0.1), body, bevel=0.035, segments=1)
            C.paint(t, "cream" if (ix + iy) % 2 == 0 else "#ffd36b", bottom="#e8b45a")
            tiles.append(t)
    parts += tiles
    top_rim = C.box("TopBase", (sx, sy, 0.18), (0, 0, -0.17), body, bevel=0.06)
    C.paint(top_rim, "#f2c25c")
    parts.append(top_rim)
    panel = C.box("Panel", (sx - 0.08, sy - 0.08, 0.42), (0, 0, -0.5), body, bevel=0.07)
    C.paint(panel, "toy_red", bottom="#d42f3c")
    parts.append(panel)
    lower = C.box("Lower", (sx - 0.3, sy - 0.3, 0.32), (0, 0, -0.85), body, bevel=0.08)
    C.paint(lower, "toy_blue", bottom="#1f4fc2")
    parts.append(lower)
    # Yellow bolts along the red panel.
    for side in (-1, 1):
        for i in range(max(2, int(sx / 1.2))):
            x = -hx + (i + 0.5) * sx / max(2, int(sx / 1.2))
            b = C.sphere("BoltX", 0.07, (x, side * (hy - 0.02), -0.5), body, segments=8, rings=5, scale=(1, 0.5, 1))
            C.paint(b, "toy_yellow")
            parts.append(b)
        for i in range(max(2, int(sy / 1.2))):
            y = -hy + (i + 0.5) * sy / max(2, int(sy / 1.2))
            b = C.sphere("BoltY", 0.07, (side * (hx - 0.02), y, -0.5), body, segments=8, rings=5, scale=(0.5, 1, 1))
            C.paint(b, "toy_yellow")
            parts.append(b)
    for ix in (-1, 1):
        for iy in (-1, 1):
            stud = C.cylinder("Stud", 0.2, 0.12, (ix * (hx - 0.38), iy * (hy - 0.38), 0.06), body, verts=16,
                              bevel=0.03)
            C.paint(stud, "toy_red", bottom="#c92a3a")
            parts.append(stud)
    strut = C.cylinder("Strut", 0.32, 3.0, (0, 0, -2.5), body, verts=14, bevel=0.03)
    C.paint(strut, "toy_purple", bottom="#5a2fb8")
    parts.append(strut)
    for i, z in enumerate((-1.3, -2.2, -3.1)):
        ring = C.torus("StrutRing_%d" % i, 0.36, 0.07, (0, 0, z), body, major_segments=16, minor_segments=6)
        C.paint(ring, "toy_yellow")
        parts.append(ring)
    cap = C.cylinder("StrutCap", 0.65, 0.22, (0, 0, -1.1), body, verts=16, bevel=0.05)
    C.paint(cap, "toy_teal")
    parts.append(cap)
    C.join(parts, "Body")
    band = C.box("EdgeGlow", (sx + 0.02, sy + 0.02, 0.06), (0, 0, -0.27), glow, bevel=0.02)
    C.paint(band, "#ffffff")
    return C.save_and_export(name)


def ruin_platform(size_key):
    sx, sy = PLATFORM_SIZES[size_key]
    hx, hy = sx * 0.5, sy * 0.5
    name = "PLAT_Ruin_" + size_key
    C.use_collection(name)
    rng = random.Random(len(name) * 17 + int(sx * 5 + sy))
    stone = ground_mat("M_RuinStone")
    glow = glow_mat()
    parts = []
    nx, ny = max(1, round(sx / 1.5)), max(1, round(sy / 1.5))
    tx, ty = sx / nx, sy / ny
    for ix in range(nx):
        for iy in range(ny):
            cx = -hx + tx * (ix + 0.5)
            cy = -hy + ty * (iy + 0.5)
            t = C.box("Tile", (tx - 0.07, ty - 0.07, 0.22), (cx, cy, -0.11), stone, bevel=0.05)
            shade = rng.uniform(0.9, 1.04)
            C.paint(t, to_hex(col("sand") * shade), bottom="#d9bf98")
            parts.append(t)
    grout = C.box("Grout", (sx - 0.04, sy - 0.04, 0.16), (0, 0, -0.16), stone, bevel=0.03)
    C.paint(grout, "#a5714c")
    parts.append(grout)
    slab = C.box("Slab", (sx, sy, 0.55), (0, 0, -0.55), stone, bevel=0.08)
    C.paint(slab, "sandstone", bottom="#c76740")
    parts.append(slab)
    trim = C.box("Trim", (sx + 0.1, sy + 0.1, 0.1), (0, 0, -0.62), stone, bevel=0.03)
    C.paint(trim, "gold", bottom="#e3961d")
    parts.append(trim)
    # Carved blocks along the slab (relief rhythm).
    for side in (-1, 1):
        for i in range(max(1, int(sx / 1.0))):
            x = -hx + (i + 0.5) * sx / max(1, int(sx / 1.0))
            b = C.box("Carve", (0.5, 0.06, 0.2), (x, side * (hy + 0.01), -0.42), stone, bevel=0.02)
            C.paint(b, "#f4a26f")
            parts.append(b)
        for i in range(max(1, int(sy / 1.0))):
            y = -hy + (i + 0.5) * sy / max(1, int(sy / 1.0))
            b = C.box("Carve", (0.06, 0.5, 0.2), (side * (hx + 0.01), y, -0.42), stone, bevel=0.02)
            C.paint(b, "#f4a26f")
            parts.append(b)
    depth = 2.6
    under = C.island_underside("Underside", (sx - 0.3, sy - 0.3), depth, (0, 0, -0.82), stone, seed=len(name) + 7)
    paint_faces(under, lambda c, nrm, i: mix("sandstone_dark", "rock", min(1.0, -c.z / depth)), seed=3, jitter=0.08)
    parts.append(under)
    # Broken column stubs at two corners (decoration, below knee height).
    for k, (ix, iy) in enumerate(((-1, 1), (1, -1))):
        if sx < 4 and k == 1:
            continue
        stub = C.cylinder("Stub_%d" % k, 0.22, 0.35, (ix * (hx - 0.32), iy * (hy - 0.32), 0.17), stone, verts=10,
                          bevel=0.03)
        C.paint(stub, "sand", bottom="#d9bf98")
        parts.append(stub)
    C.join(parts, "Stone")
    band = C.box("EdgeGlow", (sx + 0.03, sy + 0.03, 0.05), (0, 0, -0.27), glow, bevel=0.02)
    C.paint(band, "#ffffff")
    return C.save_and_export(name)


# ---------------------------------------------------------------- dynamic platforms

def caution_stripes(parts, mat, sx, sy, z, height):
    """Yellow/black caution band around a box (moving platforms)."""
    for side in (-1, 1):
        for axis in ("x", "y"):
            length = sx if axis == "x" else sy
            count = int(length / 0.3)
            for i in range(count):
                t = -length * 0.5 + (i + 0.5) * length / count
                if axis == "x":
                    b = C.box("Stripe", (length / count * 0.98, 0.04, height), (t, side * (sy * 0.5 + 0.005), z), mat,
                              bevel=0.0)
                else:
                    b = C.box("Stripe", (0.04, length / count * 0.98, height), (side * (sx * 0.5 + 0.005), t, z), mat,
                              bevel=0.0)
                b.rotation_euler = (0, 0, 0)
                C.paint(b, "impulse" if i % 2 == 0 else "dark")
                parts.append(b)


def moving_platform():
    name = "PLAT_Moving"
    C.use_collection(name)
    body = ground_mat("M_TempBody", 0.45)
    glow = C.material("M_TempGlow", "temp", 0.35, emission="temp", emission_strength=1.2)
    parts = []
    top = C.box("Body", (3.0, 3.0, 0.3), (0, 0, -0.15), body, bevel=0.08)
    C.paint(top, "temp_dark", bottom="#2448c8")
    parts.append(top)
    under = C.box("Under", (2.8, 2.8, 0.25), (0, 0, -0.42), body, bevel=0.07)
    C.paint(under, "#22357a")
    parts.append(under)
    caution_stripes(parts, body, 2.9, 2.9, -0.42, 0.18)
    C.join(parts, "Body")
    glows = []
    for i, y in enumerate((-0.8, 0.0, 0.8)):
        glows.append(C.prism("Chevron_%d" % i, [(-0.9, -0.2), (0, 0.25), (0.9, -0.2), (0.9, 0.1), (0, 0.55),
                                                 (-0.9, 0.1)], 0.03, (0, y - 0.15, 0.0), glow))
    glows.append(C.cylinder("Thruster", 0.45, 0.3, (0, 0, -0.68), glow, verts=16, radius_top=0.65))
    C.join(glows, "Glow")
    return C.save_and_export(name)


def crumble_platform():
    name = "PLAT_Crumble"
    C.use_collection(name)
    body = ground_mat("M_CrumbleTile", 0.6)
    # Four separate tiles ("Tile_*") so Godot can shake and drop them individually.
    for ix in (-1, 1):
        for iy in (-1, 1):
            tile = C.box("TileBody", (1.42, 1.42, 0.4), (ix * 0.74, iy * 0.74, -0.2), body, bevel=0.07)
            C.paint(tile, "temp", bottom="#1b8fd0", jitter=0.03, seed=ix * 3 + iy)
            pieces = [tile]
            for k in range(2):
                crack = C.box("Crack", (0.8 - k * 0.3, 0.06, 0.02), (ix * 0.74 + k * 0.15 * ix, iy * 0.74 - k * 0.2,
                                                                       0.005), body, bevel=0.0,
                              rot=(0, 0, 35 * ix * iy + k * 70))
                C.paint(crack, "#123a8a")
                pieces.append(crack)
            under = C.box("TileUnder", (1.3, 1.3, 0.2), (ix * 0.74, iy * 0.74, -0.48), body, bevel=0.05)
            C.paint(under, "#1b5fb0")
            pieces.append(under)
            C.join(pieces, "Tile_%s%s" % ("L" if ix < 0 else "R", "B" if iy < 0 else "F"))
    return C.save_and_export(name)


def timed_platform():
    name = "PLAT_Timed"
    C.use_collection(name)
    body = ground_mat("M_TimedBody", 0.4)
    glow = C.material("M_TimedGlow", "temp", 0.35, emission="temp", emission_strength=1.0)
    top = C.cylinder("Top", 1.6, 0.3, (0, 0, -0.15), body, verts=6, bevel=0.06)
    C.paint(top, "#7fe6ff", bottom="temp")
    base = C.cylinder("Base", 1.45, 0.35, (0, 0, -0.45), body, verts=6, bevel=0.05)
    C.paint(base, "temp_dark", bottom="#1f3fa8")
    C.join([top, base], "Body")
    ring = C.torus("Band", 1.05, 0.06, (0, 0, 0.0), glow, major_segments=6, minor_segments=4)
    C.paint(ring, "#ffffff")
    return C.save_and_export(name)


# ---------------------------------------------------------------- impulse props

def trampoline():
    name = "PROP_Trampoline"
    C.use_collection(name)
    body = ground_mat("M_TrampBody", 0.5)
    yellow = C.material("M_ImpulseYellow", "impulse", 0.4, emission="impulse", emission_strength=0.35)
    white = C.material("M_White", "white", 0.5)
    parts = []
    base = C.cylinder("Base", 1.15, 0.3, (0, 0, 0.15), body, verts=28, bevel=0.06)
    C.paint(base, "dark", bottom="#151829")
    parts.append(base)
    for i in range(8):
        a = i * math.pi / 4
        c = C.cylinder("Coil_%d" % i, 0.09, 0.22, (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.38), body, verts=8)
        C.paint(c, "metal")
        parts.append(c)
        for k in range(3):
            t = C.torus("CoilRing_%d_%d" % (i, k), 0.1, 0.025, (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.31 + k * 0.07),
                        body, major_segments=10, minor_segments=4)
            C.paint(t, "metal_dark")
            parts.append(t)
    ring = C.torus("Ring", 1.05, 0.13, (0, 0, 0.52), body, major_segments=32, minor_segments=8)
    C.paint(ring, "impulse_dark", bottom="#d65a10")
    parts.append(ring)
    C.join(parts, "Frame")
    pad = C.cylinder("Pad", 0.92, 0.12, (0, 0, 0.53), yellow, verts=28, bevel=0.04)
    arrow = C.prism("Arrow", [(-0.18, -0.45), (0.18, -0.45), (0.18, 0.0), (0.42, 0.0), (0.0, 0.48),
                               (-0.42, 0.0), (-0.18, 0.0)], 0.03, (0, 0, 0.59), white)
    C.parent(arrow, pad)
    ink = outline_mat()
    C.parent(C.outline_shell(arrow, 0.018, ink, "ArrowOutline"), pad)
    return C.save_and_export(name)


def wind_ring():
    name = "PROP_WindRing"
    C.use_collection(name)
    body = ground_mat("M_WindBody", 0.45)
    cyan = C.material("M_WindCyan", "temp", 0.35, emission="temp", emission_strength=1.4)
    parts = []
    ring = C.torus("Ring", 1.5, 0.17, (0, 0, 0.35), body, major_segments=36, minor_segments=10)
    C.paint(ring, "white", bottom="#b9d6f0")
    parts.append(ring)
    for i in range(3):
        a = i * 2 * math.pi / 3
        leg = C.box("Leg_%d" % i, (0.3, 0.3, 0.38), (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.19), body, bevel=0.06)
        C.paint(leg, "metal_dark")
        parts.append(leg)
    C.join(parts, "Frame")
    C.torus("Glow", 1.3, 0.07, (0, 0, 0.44), cyan, major_segments=36, minor_segments=6)
    rotor = C.empty("Rotor", (0, 0, 0.3))
    hub = C.cylinder("Hub", 0.25, 0.2, (0, 0, 0.3), body, verts=14, bevel=0.03)
    C.paint(hub, "temp_dark")
    C.parent(hub, rotor)
    for i in range(4):
        blade = C.box("Blade_%d" % i, (1.0, 0.24, 0.04), (0.6, 0, 0.3), body, bevel=0.015, rot=(20, 0, 0))
        C.paint(blade, "white")
        blade.rotation_euler.z = i * math.pi / 2
        blade.location = (math.cos(i * math.pi / 2) * 0.6, math.sin(i * math.pi / 2) * 0.6, 0.3)
        C.parent(blade, rotor)
    return C.save_and_export(name)


def boost_pad():
    name = "PROP_BoostPad"
    C.use_collection(name)
    body = ground_mat("M_BoostBody", 0.5)
    yellow = C.material("M_ImpulseYellow", "impulse", 0.4, emission="impulse", emission_strength=1.0)
    parts = []
    plate = C.box("Plate", (2.2, 3.2, 0.12), (0, 0, 0.06), body, bevel=0.04)
    C.paint(plate, "impulse_dark", bottom="#c9500c")
    parts.append(plate)
    for side in (-1, 1):
        rail = C.box("Rail", (0.14, 3.2, 0.16), (side * 1.1, 0, 0.08), body, bevel=0.05)
        C.paint(rail, "dark")
        parts.append(rail)
    C.join(parts, "Plate")
    chevrons = []
    for i, y in enumerate((-0.9, 0.0, 0.9)):
        chevrons.append(C.prism("Chevron_%d" % i, [(-0.8, -0.25), (0, 0.25), (0.8, -0.25), (0.8, 0.05), (0, 0.55),
                                                   (-0.8, 0.05)], 0.04, (0, y - 0.15, 0.12), yellow))
    C.join(chevrons, "Chevrons")
    return C.save_and_export(name)


# ---------------------------------------------------------------- progress props

def checkpoint():
    name = "PROP_Checkpoint"
    C.use_collection(name)
    body = ground_mat("M_CheckBody", 0.55)
    flag_mat = C.material("M_Flag", "temp", 0.6)
    lamp = C.material("M_CheckLamp", "#fff4c9", 0.3, emission="#ffd34d", emission_strength=1.4)
    parts = []
    base = C.cylinder("Base", 0.55, 0.25, (0, 0, 0.125), body, verts=12, bevel=0.05)
    C.paint(base, "stone", bottom="stone_dark")
    parts.append(base)
    pole = C.cylinder("Pole", 0.065, 2.4, (0, 0, 1.45), body, verts=10)
    C.paint(pole, "white")
    parts.append(pole)
    for i in range(4):
        band = C.cylinder("PoleBand_%d" % i, 0.075, 0.12, (0, 0, 0.55 + i * 0.5), body, verts=10)
        C.paint(band, "temp_dark")
        parts.append(band)
    C.join(parts, "Post")
    C.sphere("Knob", 0.15, (0, 0, 2.7), lamp, segments=14, rings=8)
    flag = C.empty("Flag", (0.07, 0, 2.45))
    pts = []
    for i in range(9):
        t = i / 8
        pts.append((t * 0.95, math.sin(t * math.pi * 1.5) * 0.06))
    pts += [(0.8, 0.0)]
    cloth = C.prism("Cloth", [(0, -0.02), (0.95, -0.02), (0.78, 0.0), (0.95, 0.02), (0, 0.02)], 0.62,
                    (0.07, 0, 1.83), flag_mat, bevel=0.01)
    C.parent(cloth, flag)
    star = C.prism("FlagStar", star_points(5, 0.16, 0.07), 0.05, (0.42, 0.0, 2.14), C.material("M_White", "white", 0.5),
                   rot=(90, 0, 0))
    star.location = (0.42, 0.03, 2.14)
    C.parent(star, flag)
    return C.save_and_export(name)


def gem():
    name = "PROP_Gem"
    C.use_collection(name)
    gem_mat = C.material("M_Gem", "#ffffff", 0.15, 0.0, emission="#2fd8ff", emission_strength=0.7, vcol=True)
    bm = bmesh.new()
    sides = 8
    table = [bm.verts.new((math.cos(i * math.pi / 4 + math.pi / 8) * 0.2, math.sin(i * math.pi / 4 + math.pi / 8) * 0.2,
                           0.42)) for i in range(sides)]
    girdle = [bm.verts.new((math.cos(i * math.pi / 4) * 0.42, math.sin(i * math.pi / 4) * 0.42, 0.18))
              for i in range(sides)]
    bottom = bm.verts.new((0, 0, -0.5))
    bm.faces.new(table)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((girdle[i], girdle[j], table[i]))
        bm.faces.new((table[i], girdle[j], table[j]))
        bm.faces.new((girdle[j], girdle[i], bottom))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    gem_obj = C._mesh_object("Gem", bm, gem_mat, smooth=False)

    def facet(center, normal, idx):
        if normal.z > 0.9:
            return col("#e8fdff")
        if normal.z > 0.2:
            return col("#7ff0ff") if idx % 2 else col("#3fd7ff")
        return col("#1a9ce8") if idx % 2 else col("#2a6dff")
    paint_faces(gem_obj, facet)
    C.outline_shell(gem_obj, 0.035, outline_mat("M_OutlineGem", "#0d1d4a"), "GemOutline")
    return C.save_and_export(name)


def spark():
    name = "PROP_Spark"
    C.use_collection(name)
    mat = C.material("M_Spark", "#ffffff", 0.3, emission="#ffb21a", emission_strength=0.9, vcol=True)
    star = C.prism("Spark", star_points(4, 0.34, 0.12), 0.12, (0, 0.06, 0), mat, rot=(90, 0, 0), bevel=0.035)
    C.paint(star, "#ffe14a", bottom="#ffb000", z_range=(-0.34, 0.34))
    core = C.prism("SparkCore", star_points(4, 0.16, 0.06), 0.15, (0, 0.075, 0), mat, rot=(90, 0, 0), bevel=0.01)
    C.paint(core, "#fffbe6")
    C.join([star, core], "Spark")
    C.outline_shell(star, 0.03, outline_mat("M_OutlineSpark", "#8a3a06"), "SparkOutline")
    return C.save_and_export(name)


def goal_gate():
    name = "PROP_GoalGate"
    C.use_collection(name)
    body = ground_mat("M_GoalBody", 0.5)
    cyan = C.material("M_GoalGlow", "yoyo", 0.35, emission="yoyo", emission_strength=1.6)
    gold = C.material("M_GoalGold", "gold", 0.3, 0.8, emission="gold", emission_strength=0.25)
    parts = []
    for side in (-1, 1):
        pillar = C.box("Pillar_%d" % side, (0.7, 0.7, 4.0), (side * 2.6, 0, 2.0), body, bevel=0.12)
        slice_mesh(pillar, 2, 0.5)
        slice_mesh(pillar, 0, 0.35)
        slice_mesh(pillar, 1, 0.35)
        # Checkered finish-line pillars.
        paint_faces(pillar, lambda c, n, i: col("white") if (int((c.z + 10) / 0.5) + int((c.x + 10) / 0.35)
                                                             + int((c.y + 10) / 0.35)) % 2 else col("dark"))
        parts.append(pillar)
        band = C.box("PillarBand_%d" % side, (0.8, 0.8, 0.3), (side * 2.6, 0, 3.4), body, bevel=0.06)
        C.paint(band, "impulse_dark")
        parts.append(band)
        foot = C.box("PillarFoot_%d" % side, (1.05, 1.05, 0.4), (side * 2.6, 0, 0.2), body, bevel=0.08)
        C.paint(foot, "gold", bottom="#d98a12")
        parts.append(foot)
        cap = C.sphere("PillarCap_%d" % side, 0.42, (side * 2.6, 0, 4.15), body, segments=14, rings=8)
        C.paint(cap, "impulse")
        parts.append(cap)
    lintel = C.box("Lintel", (5.9, 0.6, 0.45), (0, 0, 4.2), body, bevel=0.1)
    C.paint(lintel, "white")
    parts.append(lintel)
    # Pennant garland under the lintel.
    colors = ["toy_red", "impulse", "temp", "grass", "toy_purple"]
    for i in range(9):
        x = -2.0 + i * 0.5
        flag = C.prism("Pennant_%d" % i, [(-0.18, 0), (0.18, 0), (0, -0.4)], 0.03, (x, 0.32, 3.95), body,
                       rot=(90, 0, 0))
        C.paint(flag, colors[i % len(colors)])
        parts.append(flag)
    C.join(parts, "Gate")
    halo = C.torus("Halo", 2.1, 0.2, (0, 0, 4.4), gold, rot=(90, 0, 0), major_segments=40, minor_segments=8)
    glow = C.torus("HaloGlow", 1.78, 0.09, (0, 0, 4.4), cyan, rot=(90, 0, 0), minor_segments=6, major_segments=40)
    C.parent(glow, halo)
    for i in range(8):
        a = i * math.pi / 4
        s = C.prism("HaloStar_%d" % i, star_points(5, 0.26, 0.11), 0.08, (math.cos(a) * 2.1, -0.06, 4.4 +
                                                                          math.sin(a) * 2.1), gold, rot=(90, 0, 0))
        C.parent(s, halo)
    return C.save_and_export(name)


# ---------------------------------------------------------------- hazards

def spinner():
    name = "HAZ_Spinner"
    C.use_collection(name)
    body = ground_mat("M_HazardBody", 0.45)
    magenta = C.material("M_Hazard", "hazard", 0.4, emission="hazard", emission_strength=0.8)
    ink = outline_mat()
    hub = C.cylinder("Hub", 0.6, 1.2, (0, 0, 0.6), body, verts=18, bevel=0.06)
    C.paint(hub, "dark", bottom="#121424")
    arm = C.empty("Arm", (0, 0, 0.7))
    arm_parts = []
    bar = C.box("Bar", (6.0, 0.4, 0.4), (0, 0, 0.7), body, bevel=0.1)
    slice_mesh(bar, 0, 0.6)
    paint_faces(bar, lambda c, n, i: col("hazard_dark") if int((c.x + 10) / 0.6) % 2 else col("hazard"))
    arm_parts.append(bar)
    for side in (-1, 1):
        ball = C.ico("Ball_%d" % side, 0.4, (side * 3.0, 0, 0.7), body, subdivisions=2, smooth=True)
        C.paint(ball, "hazard_dark")
        arm_parts.append(ball)
        for k in range(6):
            dirs = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)][k]
            spike = C.cone("Spike_%d_%d" % (side, k), 0.13, 0.4,
                           (side * 3.0 + dirs[0] * 0.48, dirs[1] * 0.48, 0.7 + dirs[2] * 0.48), body, verts=6)
            spike.rotation_mode = "QUATERNION"
            spike.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(dirs))
            C.paint(spike, "#ff6fc0", bottom="hazard")
            arm_parts.append(spike)
    bar_obj = C.join(arm_parts, "ArmBody")
    C.parent(bar_obj, arm)
    C.parent(C.outline_shell(bar_obj, 0.04, ink, "ArmOutline"), arm)
    for i, x in enumerate((-1.5, 1.5)):
        light = C.sphere("Light_%d" % i, 0.12, (x, 0, 0.93), magenta, segments=10, rings=6)
        C.parent(light, arm)
    return C.save_and_export(name)


def spikes():
    name = "HAZ_Spikes"
    C.use_collection(name)
    body = ground_mat("M_HazardBody", 0.45)
    base = C.box("Base", (2.0, 2.0, 0.15), (0, 0, 0.075), body, bevel=0.04)
    slice_mesh(base, 0, 0.125)
    slice_mesh(base, 1, 0.125)
    paint_faces(base, lambda c, n, i: col("impulse") if n.z < 0.5 and int((c.x + c.y + 10) / 0.25) % 2 else col("dark"))
    spikes_list = []
    for ix in range(4):
        for iy in range(4):
            x = -0.75 + ix * 0.5
            y = -0.75 + iy * 0.5
            s = C.cone("Spike", 0.2, 0.6, (x, y, 0.45), body, verts=4, rot=(0, 0, 45))
            C.paint(s, "#ff7cc8" if (ix + iy) % 2 else "#d07bff", bottom="hazard_dark")
            spikes_list.append(s)
    sp = C.join(spikes_list, "Spikes")
    C.outline_shell(sp, 0.025, outline_mat(), "SpikesOutline")
    return C.save_and_export(name)


def patrol_bot():
    name = "HAZ_PatrolBot"
    C.use_collection(name)
    body = ground_mat("M_HazardBody", 0.4)
    eye = C.material("M_BotEye", "#ffffff", 0.3, emission="#ffd6f0", emission_strength=0.4)
    magenta = C.material("M_Hazard", "hazard", 0.4, emission="hazard", emission_strength=0.9)
    shell = C.ico("Body", 0.6, (0, 0, 0), body, subdivisions=3, smooth=True)
    C.paint(shell, "hazard_dark", bottom="#4a0f8a")
    parts = [shell]
    band = C.torus("Band", 0.6, 0.07, (0, 0, -0.05), body, minor_segments=6, major_segments=24)
    C.paint(band, "dark")
    parts.append(band)
    brow = C.box("Brow", (0.5, 0.1, 0.08), (0, 0.5, 0.38), body, bevel=0.03, rot=(-20, 0, 0))
    C.paint(brow, "dark")
    parts.append(brow)
    for k in range(14):
        y = 1 - (k / 13.0) * 2
        r = math.sqrt(max(0.0, 1 - y * y))
        theta = k * 2.399963
        d = Vector((math.cos(theta) * r, y, math.sin(theta) * r))
        if d.y > 0.6:
            continue
        spike = C.cone("Spike", 0.13, 0.42, tuple(d * 0.68), body, verts=5)
        spike.rotation_mode = "QUATERNION"
        spike.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        C.paint(spike, "#ff7cc8", bottom="hazard")
        parts.append(spike)
    bot = C.join(parts, "BotBody")
    C.outline_shell(bot, 0.035, outline_mat(), "BotOutline")
    C.sphere("Eye", 0.22, (0, 0.5, 0.12), eye, segments=14, rings=8, scale=(1, 0.5, 1))
    C.sphere("Pupil", 0.1, (0, 0.6, 0.1), magenta, segments=10, rings=6, scale=(1, 0.5, 1))
    return C.save_and_export(name)


def laser_post():
    name = "HAZ_LaserPost"
    C.use_collection(name)
    body = ground_mat("M_HazardBody", 0.45)
    magenta = C.material("M_Hazard", "hazard", 0.4, emission="hazard", emission_strength=1.2)
    post = C.box("Post", (0.4, 0.4, 2.2), (0, 0, 1.1), body, bevel=0.07)
    slice_mesh(post, 2, 0.09)
    paint_faces(post, lambda c, n, i: (col("impulse") if int((c.z + c.x * 0.5 + 10) / 0.18) % 2 else col("dark"))
                if c.z < 0.9 else col("dark"))
    cap = C.box("Cap", (0.5, 0.5, 0.14), (0, 0, 2.25), body, bevel=0.04)
    C.paint(cap, "hazard_dark")
    C.join([post, cap], "PostBody")
    C.cylinder("Emitter", 0.16, 0.22, (0, 0, 1.05), magenta, verts=14, rot=(90, 0, 90))
    C.sphere("Lamp", 0.14, (0, 0, 2.4), magenta, segments=12, rings=8)
    return C.save_and_export(name)


# ---------------------------------------------------------------- decoration

def puff_cluster(name, mat, puffs, top, bottom, jitter=0.0, seed=0):
    objs = []
    for i, (x, y, z, r) in enumerate(puffs):
        o = C.ico("%s_%d" % (name, i), r, (x, y, z), mat, subdivisions=2, smooth=True)
        objs.append(o)
    joined = C.join(objs, name)
    zs = [v.co.z for v in joined.data.vertices]
    C.paint(joined, top, bottom=bottom, z_range=(min(zs), max(zs)), jitter=jitter, seed=seed)
    return joined


def tree():
    name = "ENV_Tree"
    C.use_collection(name)
    mat = ground_mat("M_DecoTree", 0.85)
    segs = []
    for i in range(4):
        segs.append(C.cylinder("Trunk_%d" % i, 0.3 - i * 0.04, 0.75, (math.sin(i * 0.6) * 0.12, 0, 0.37 + i * 0.68),
                               mat, verts=10, radius_top=0.28 - i * 0.04, rot=(0, 8 * math.cos(i), 0)))
    trunk = C.join(segs, "Trunk")
    C.paint(trunk, "wood", bottom="#6e3a1a")
    crown = puff_cluster("Crown", mat, [(0, 0, 3.2, 1.25), (0.95, 0.25, 2.8, 0.85), (-0.9, -0.3, 2.85, 0.85),
                                         (0.2, -0.85, 3.0, 0.8), (-0.2, 0.8, 3.05, 0.8), (0.1, 0.1, 4.0, 0.75)],
                         "leaf_light", "leaf_dark")
    C.join([trunk, crown], "Tree")
    return C.save_and_export(name)


def pine():
    name = "ENV_Pine"
    C.use_collection(name)
    mat = ground_mat("M_DecoPine", 0.85)
    trunk = C.cylinder("Trunk", 0.2, 1.2, (0, 0, 0.6), mat, verts=8)
    C.paint(trunk, "wood", bottom="#6e3a1a")
    tiers = [trunk]
    for i, (r, z) in enumerate(((1.25, 1.5), (0.98, 2.35), (0.7, 3.1))):
        t = C.cylinder("Tier_%d" % i, r, 1.25, (0, 0, z), mat, verts=12, radius_top=0.08, bevel=0.06)
        C.paint(t, "leaf", bottom="leaf_dark")
        tiers.append(t)
    tip = C.sphere("Tip", 0.12, (0, 0, 3.8), mat, segments=8, rings=5)
    C.paint(tip, "leaf_light")
    tiers.append(tip)
    C.join(tiers, "Pine")
    return C.save_and_export(name)


def bush():
    name = "ENV_Bush"
    C.use_collection(name)
    mat = ground_mat("M_DecoBush", 0.85)
    b = puff_cluster("Bush", mat, [(0, 0, 0.42, 0.6), (0.55, 0.1, 0.32, 0.45), (-0.5, -0.1, 0.3, 0.42),
                                    (0.1, 0.45, 0.3, 0.38)], "leaf_light", "leaf_dark")
    berries = []
    rng = random.Random(5)
    for i in range(5):
        a = rng.uniform(0, 6.28)
        s = C.sphere("Berry_%d" % i, 0.06, (math.cos(a) * 0.55, math.sin(a) * 0.4, 0.5 + rng.uniform(-0.1, 0.25)), mat,
                     segments=8, rings=5)
        C.paint(s, "#ff5470")
        berries.append(s)
    C.join([b] + berries, "Bush")
    return C.save_and_export(name)


def rocks():
    out = []
    for key, seed, scale in (("A", 11, (1.3, 1.0, 0.8)), ("B", 23, (0.9, 0.9, 1.4))):
        C.reset_scene()
        name = "ENV_Rock_" + key
        C.use_collection(name)
        mat = ground_mat("M_DecoRock", 0.9)
        r = C.rock_blob("Rock", 0.8, (0, 0, 0.45), mat, seed=seed, squash=scale)
        C.add_bevel(r, 0.05, 1)
        C.paint(r, "stone", bottom="stone_dark", jitter=0.08, seed=seed)
        chip = C.rock_blob("Chip", 0.35, (0.7, 0.3, 0.2), mat, seed=seed + 1)
        C.paint(chip, "stone_dark", jitter=0.08, seed=seed + 1)
        moss = C.rock_blob("Moss", 0.45, (0, 0, 0.45 + 0.8 * scale[2] * 0.75), mat, seed=seed + 2,
                           squash=(1.3, 1.1, 0.25))
        C.paint(moss, "grass", jitter=0.06)
        C.join([r, chip, moss], "Rock")
        out.append(C.save_and_export(name))
    return out


def cloud():
    name = "ENV_Cloud"
    C.use_collection(name)
    mat = C.material("M_Cloud", "#ffffff", 1.0, emission="#ffffff", emission_strength=0.15, vcol=True)
    puff_cluster("Cloud", mat, [(0, 0, 0, 2.0), (2.2, 0.3, -0.3, 1.5), (-2.1, -0.2, -0.4, 1.4),
                                (0.9, 0.8, 0.9, 1.3), (-0.8, -0.6, 0.7, 1.2), (3.6, 0.0, -0.6, 0.9)],
                 "#ffffff", "#c9d6f5")
    return C.save_and_export(name)


def ruin_pillar():
    name = "ENV_RuinPillar"
    C.use_collection(name)
    mat = ground_mat("M_DecoRuin", 0.85)
    parts = []
    foot = C.box("Foot", (1.2, 1.2, 0.4), (0, 0, 0.2), mat, bevel=0.06)
    C.paint(foot, "sandstone", bottom="sandstone_dark")
    parts.append(foot)
    shaft = C.cylinder("Shaft", 0.42, 3.2, (0, 0, 2.0), mat, verts=12, bevel=0.03)
    slice_mesh(shaft, 2, 0.4)
    paint_faces(shaft, lambda c, n, i: col("sand") if int((c.z + 10) / 0.8) % 2 else mix("sand", "sandstone", 0.25))
    parts.append(shaft)
    band = C.cylinder("Band", 0.46, 0.18, (0, 0, 2.6), mat, verts=12)
    C.paint(band, "turquoise")
    parts.append(band)
    capital = C.box("Capital", (1.1, 1.1, 0.35), (0, 0, 3.75), mat, bevel=0.06)
    C.paint(capital, "sandstone")
    parts.append(capital)
    broken = C.box("Broken", (0.6, 0.5, 0.3), (0.2, 0.1, 4.05), mat, bevel=0.06, rot=(8, -6, 20))
    C.paint(broken, "sand")
    parts.append(broken)
    C.join(parts, "Pillar")
    return C.save_and_export(name)


def ruin_arch():
    name = "ENV_RuinArch"
    C.use_collection(name)
    mat = ground_mat("M_DecoRuin", 0.85)
    gold = C.material("M_RuinGold", "gold", 0.3, 0.8, emission="gold", emission_strength=0.3)
    parts = []
    for side in (-1, 1):
        leg = C.box("Leg_%d" % side, (0.9, 0.9, 4.0), (side * 2.0, 0, 2.0), mat, bevel=0.08)
        slice_mesh(leg, 2, 0.35)
        paint_faces(leg, lambda c, n, i: col("sand") if int((c.z + 10) / 0.7) % 2 else col("#ecd2ad"))
        parts.append(leg)
    top = C.box("Top", (5.2, 1.0, 0.8), (0, 0, 4.4), mat, bevel=0.1)
    C.paint(top, "sandstone", bottom="sandstone_dark")
    parts.append(top)
    glyph = C.box("Glyph", (1.6, 0.06, 0.3), (0, -0.52, 4.4), mat, bevel=0.02)
    C.paint(glyph, "turquoise")
    parts.append(glyph)
    C.join(parts, "Arch")
    C.prism("Sun", star_points(12, 0.55, 0.36), 0.1, (0, -0.55, 4.4), gold, rot=(90, 0, 0))
    return C.save_and_export(name)


def obelisk():
    name = "ENV_Obelisk"
    C.use_collection(name)
    mat = ground_mat("M_DecoRuin", 0.85)
    turq = C.material("M_Turquoise", "turquoise", 0.35, emission="turquoise", emission_strength=0.9)
    base = C.box("Base", (1.6, 1.6, 0.6), (0, 0, 0.3), mat, bevel=0.08)
    C.paint(base, "sandstone", bottom="sandstone_dark")
    body = C.cylinder("Body", 0.55, 5.0, (0, 0, 3.1), mat, verts=4, radius_top=0.35, rot=(0, 0, 45), smooth=False)
    C.paint(body, "#f0c99a", bottom="sandstone")
    C.join([base, body], "Obelisk")
    C.cone("Tip", 0.36, 0.7, (0, 0, 5.95), turq, verts=4, rot=(0, 0, 45))
    for i in range(3):
        C.box("Glyph_%d" % i, (0.22, 0.04, 0.22), (0, -0.47 + i * 0.03, 1.6 + i * 1.1), turq, bevel=0.02,
              rot=(-3, 0, 0))
    return C.save_and_export(name)


def palm():
    name = "ENV_Palm"
    C.use_collection(name)
    mat = ground_mat("M_DecoPalm", 0.85)
    parts = []
    # Curved, ringed trunk.
    top = Vector((0, 0, 0))
    for i in range(8):
        t = i / 7
        center = Vector((0.9 * t * t, 0, 0.3 + i * 0.58))
        seg = C.cylinder("Seg_%d" % i, 0.24 - i * 0.012, 0.6, tuple(center), mat, verts=9, radius_top=0.2 - i * 0.012,
                         rot=(0, 8 + t * 14, 0), bevel=0.02)
        C.paint(seg, "#c99257" if i % 2 else "#a8723e")
        parts.append(seg)
        top = center
    crown = top + Vector((0.12, 0, 0.35))
    # Drooping fronds: bent strips with a midrib colour gradient.
    for f in range(7):
        a = f * 2 * math.pi / 7 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        rings = []
        steps = 7
        for k in range(steps + 1):
            t = k / steps
            p = crown + d * (2.1 * t) + Vector((0, 0, 0.55 * math.sin(t * math.pi * 0.8) - 1.1 * t * t))
            w = 0.42 * math.sin(math.pi * min(1.0, t * 1.05 + 0.05))
            rings.append([tuple(p - side * w + Vector((0, 0, -0.08 * w))), tuple(p + Vector((0, 0, 0.04))),
                          tuple(p + side * w + Vector((0, 0, -0.08 * w)))])
        bm = bmesh.new()
        vs = [[bm.verts.new(q) for q in r] for r in rings]
        for k in range(steps):
            for j in range(2):
                bm.faces.new((vs[k][j], vs[k][j + 1], vs[k + 1][j + 1], vs[k + 1][j]))
        frond = C._mesh_object("Frond_%d" % f, bm, mat, smooth=True)
        sol = frond.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = 0.04
        paint_verts(frond, lambda co, n: mix("leaf_light", "leaf_dark", min(1.0, (crown - co).length / 2.3)))
        parts.append(frond)
    for i in range(3):
        a = i * 2.1
        nut = C.sphere("Coconut_%d" % i, 0.14, tuple(crown + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, -0.22))), mat,
                       segments=10, rings=6)
        C.paint(nut, "#7a4a24")
        parts.append(nut)
    C.join(parts, "Palm")
    return C.save_and_export(name)


def crystal():
    name = "ENV_Crystal"
    C.use_collection(name)
    mat = C.material("M_Crystal", "#ffffff", 0.2, emission="turquoise", emission_strength=0.6, vcol=True)
    shards = []
    rng = random.Random(9)
    for i, (x, y, h, tilt, yaw) in enumerate(((0, 0, 1.7, 0, 0), (0.45, 0.2, 1.1, 22, 30), (-0.42, 0.15, 0.95, -25, -20),
                                              (0.1, -0.4, 0.8, 18, 100), (-0.15, 0.45, 0.6, -15, 200))):
        r = 0.24 if i == 0 else 0.17
        bm = bmesh.new()
        ring_lo = [bm.verts.new((math.cos(k * math.pi / 3) * r, math.sin(k * math.pi / 3) * r, 0.0)) for k in range(6)]
        ring_hi = [bm.verts.new((math.cos(k * math.pi / 3) * r * 0.9, math.sin(k * math.pi / 3) * r * 0.9, h * 0.72))
                   for k in range(6)]
        tip = bm.verts.new((0, 0, h))
        bm.faces.new(list(reversed(ring_lo)))
        for k in range(6):
            j = (k + 1) % 6
            bm.faces.new((ring_lo[k], ring_lo[j], ring_hi[j], ring_hi[k]))
            bm.faces.new((ring_hi[k], ring_hi[j], tip))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        s = C._mesh_object("Shard_%d" % i, bm, mat, smooth=False)
        C._place(s, (x, y, -0.05), (tilt, 0, yaw), (1, 1, 1))
        paint_faces(s, lambda c, n, idx: (col("#c8fff6") if n.z > 0.3 else
                                          (col("#4ff0de") if idx % 2 else col("#16b8c8"))))
        shards.append(s)
    base = C.rock_blob("Base", 0.55, (0, 0, 0.0), mat, seed=4, squash=(1.3, 1.2, 0.4))
    C.paint(base, "#6b5b8f", jitter=0.08)
    shards.append(base)
    C.join(shards, "Crystal")
    return C.save_and_export(name)


def gear_deco():
    name = "ENV_Gear"
    C.use_collection(name)
    mat = ground_mat("M_DecoGear", 0.45)
    rotor = C.empty("Rotor", (0, 0, 0))
    teeth = 12
    pts = []
    for i in range(teeth * 4):
        a = i * math.pi / (teeth * 2)
        r = 2.0 if (i % 4) in (1, 2) else 1.62
        pts.append((math.cos(a) * r, math.sin(a) * r))
    g = C.prism("Gear", pts, 0.5, (0, 0, -0.25), mat, bevel=0.04)
    C.paint(g, "toy_yellow", bottom="#e09a10")
    hub = C.cylinder("Hub", 0.55, 0.7, (0, 0, 0), mat, verts=16, bevel=0.05)
    C.paint(hub, "toy_red")
    holes = []
    for i in range(5):
        a = i * 2 * math.pi / 5
        h = C.cylinder("Hole_%d" % i, 0.25, 0.52, (math.cos(a) * 1.1, math.sin(a) * 1.1, 0), mat, verts=12)
        C.paint(h, "#b06a0c")
        holes.append(h)
    gear = C.join([g, hub] + holes, "GearBody")
    C.parent(gear, rotor)
    # Gear stands vertically (rotates around the Y axis in Blender => Z in Godot).
    rotor.rotation_euler = (math.radians(90), 0, 0)
    return C.save_and_export(name)


def toy_blocks():
    name = "ENV_ToyBlocks"
    C.use_collection(name)
    mat = ground_mat("M_DecoToy", 0.45)
    cols = ["toy_red", "toy_blue", "toy_yellow", "toy_teal", "toy_purple"]
    parts = []
    for i, (x, y, z, rz) in enumerate(((0, 0, 0.5, 0), (1.05, 0.1, 0.5, 10), (0.5, 0.0, 1.5, 25), (-0.9, 0.4, 0.5, -15))):
        b = C.box("Block_%d" % i, (1.0, 1.0, 1.0), (x, y, z), mat, bevel=0.12, segments=3, rot=(0, 0, rz))
        C.paint(b, cols[i], bottom=to_hex(col(cols[i]) * 0.75))
        parts.append(b)
        for sx in (-0.25, 0.25):
            for sy in (-0.25, 0.25):
                a = math.radians(rz)
                px = x + sx * math.cos(a) - sy * math.sin(a)
                py = y + sx * math.sin(a) + sy * math.cos(a)
                stud = C.cylinder("Stud", 0.13, 0.12, (px, py, z + 0.55), mat, verts=12, bevel=0.02)
                C.paint(stud, cols[i])
                parts.append(stud)
    C.join(parts, "Blocks")
    return C.save_and_export(name)


def lamp_post():
    name = "ENV_LampPost"
    C.use_collection(name)
    mat = ground_mat("M_DecoLamp", 0.45)
    glow = C.material("M_LampGlow", "#fff1c1", 0.4, emission="#ffd98a", emission_strength=1.8)
    pole = C.cylinder("Pole", 0.08, 3.0, (0, 0, 1.5), mat, verts=10)
    slice_mesh(pole, 2, 0.1)
    paint_faces(pole, lambda c, n, i: col("toy_red") if int((c.z + c.x * 3 + 10) / 0.3) % 2 else col("white"))
    base = C.cylinder("Base", 0.25, 0.2, (0, 0, 0.1), mat, verts=12, bevel=0.03)
    C.paint(base, "toy_blue")
    hat = C.cylinder("Hat", 0.34, 0.14, (0, 0, 3.44), mat, verts=12, radius_top=0.05, bevel=0.02)
    C.paint(hat, "toy_blue")
    C.join([pole, base, hat], "Lamp")
    C.sphere("Bulb", 0.28, (0, 0, 3.15), glow, segments=14, rings=8)
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
    with open(log_path, "w", encoding="utf-8") as log:
        log.write("build_props %s\n" % names)
    for n in names:
        with open(log_path, "a", encoding="utf-8") as log:
            log.write("building %s\n" % n)
        try:
            C.reset_scene()
            res = BUILDERS[n]()
            report.extend(res if isinstance(res, list) else [res])
        except Exception:  # keep building the rest; the log names the failure
            import traceback
            with open(log_path, "a", encoding="utf-8") as log:
                log.write("FAILED %s\n%s\n" % (n, traceback.format_exc()))
    report_path = os.path.join(C.BLEND_DIR, "scripts", "last_build_report.json")
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1)
    print("ORBIT_BUILD_DONE", len(report))


if __name__ == "__main__":
    main()
