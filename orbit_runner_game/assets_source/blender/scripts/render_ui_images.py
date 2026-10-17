"""Renders UI images from CHR_Adventurer.blend: the app icon and the HUD portrait.

  blender --background --factory-startup --python render_ui_images.py
Outputs art/ui/icon.png (512, sky background), art/ui/portrait.png (256, transparent)
and art/ui/icon_foreground.png (432, transparent, inside the adaptive-icon safe zone).
"""
import math
import os

import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BLEND = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "CHR_Adventurer.blend"))
OUT_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "..", "..", "art", "ui"))
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene
arm = bpy.data.objects["SK_Adventurer"]
action = bpy.data.actions.get("Victory")
arm.animation_data.action = action
if action.slots:
    arm.animation_data.action_slot = action.slots[0]
scene.frame_set(9)

try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"

world = bpy.data.worlds.new("UIWorld")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.35, 0.62, 0.95, 1.0)
bg.inputs["Strength"].default_value = 0.9

sun_data = bpy.data.lights.new("Key", "SUN")
sun_data.energy = 3.5
sun = bpy.data.objects.new("Key", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
rim_data = bpy.data.lights.new("Rim", "SUN")
rim_data.energy = 2.0
rim_data.color = (0.6, 0.9, 1.0)
rim = bpy.data.objects.new("Rim", rim_data)
scene.collection.objects.link(rim)
rim.rotation_euler = (math.radians(60), 0, math.radians(200))

cam_data = bpy.data.cameras.new("UICam")
cam = bpy.data.objects.new("UICam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.view_settings.view_transform = "Standard"


def shoot(path, size, loc, target, lens, transparent):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = transparent
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


shoot(os.path.join(OUT_DIR, "icon.png"), 512, (0.7, 2.0, 1.55), (0.0, 0.0, 1.18), 50, False)
shoot(os.path.join(OUT_DIR, "portrait.png"), 256, (0.35, 1.5, 1.4), (0.0, 0.0, 1.36), 55, True)
shoot(os.path.join(OUT_DIR, "icon_foreground.png"), 432, (0.95, 2.75, 1.55), (0.0, 0.0, 1.12), 50, True)
