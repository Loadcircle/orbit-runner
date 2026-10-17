"""Renders quick Eevee previews of Orbit Runner .blend assets (dev tool, not shipped).

  blender --background --factory-startup --python render_preview.py -- <out_dir> <asset> [asset ...]

Each asset is opened from assets_source/blender/<asset>.blend, framed from a
3/4 front view (asset front = +Y) and saved as <out_dir>/<asset>.png.
Character assets also get a close-up of the head (<asset>_face.png).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
BLEND_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "orbit_runner_game", "assets_source", "blender"))


def bounds():
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        for corner in ev.bound_box:
            w = ev.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def setup(resolution):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.25, 0.5, 0.9, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    sun_data = bpy.data.lights.new("PreviewSun", "SUN")
    sun_data.energy = 3.5
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame(cam, center, radius, direction):
    d = Vector(direction).normalized()
    dist = radius / math.tan(cam.data.angle * 0.5) * 1.1
    cam.location = center + d * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = dist * 4 + 100


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out_dir, assets = argv[0], argv[1:]
    os.makedirs(out_dir, exist_ok=True)
    for asset in assets:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(BLEND_DIR, asset + ".blend"))
        for obj in bpy.context.scene.objects:
            if obj.type == "ARMATURE":
                if obj.animation_data:
                    obj.animation_data.action = None
                for pb in obj.pose.bones:
                    pb.rotation_mode = "XYZ"
                    pb.rotation_euler = (0, 0, 0)
                    pb.location = (0, 0, 0)
                    pb.scale = (1, 1, 1)
        cam = setup(640)
        lo, hi = bounds()
        center = (lo + hi) * 0.5
        radius = (hi - lo).length * 0.5
        frame(cam, center, radius, (0.55, 1.0, 0.5))
        bpy.context.scene.render.filepath = os.path.join(out_dir, asset + ".png")
        bpy.ops.render.render(write_still=True)
        if asset.startswith("CHR_"):
            head = Vector((0, 0, hi.z - 0.3))
            frame(cam, head, 0.32, (0.25, 1.0, 0.1))
            bpy.context.scene.render.filepath = os.path.join(out_dir, asset + "_face.png")
            bpy.ops.render.render(write_still=True)
            frame(cam, center, radius, (-0.6, -1.0, 0.35))
            bpy.context.scene.render.filepath = os.path.join(out_dir, asset + "_back.png")
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
