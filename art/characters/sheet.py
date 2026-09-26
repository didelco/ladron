"""Hoja de personaje: renders de frente, lados, espalda y tres cuartos, para
revisar un modelo sin abrir Blender. Luz de estudio suave, como en las hojas
de referencia (Stumble Guys): llave cálida, relleno frío y un contraluz.

    sheet.render(root, "/ruta/guardia")   # guardia_frente.png, ...
"""
import math

import bpy
from mathutils import Vector

VIEWS = [
    ("tres_cuartos", -35, True),
    ("frente", 0, False),
    ("izquierda", 90, False),
    ("espalda", 180, False),
    ("derecha", -90, False),
]


def _light(name, kind, loc, target, energy, colour, size=1.0):
    d = bpy.data.lights.new(name, kind)
    d.energy = energy
    d.color = colour
    if kind == "AREA":
        d.size = size
    o = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    direction = Vector(target) - Vector(loc)
    o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return o


def stage(height=1.2):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = 700
    sc.render.resolution_y = 800
    w = bpy.data.worlds.new("world")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.65, 0.85, 1)
    bg.inputs["Strength"].default_value = 0.7
    sc.world = w
    mid = (0, 0, height * 0.5)
    _light("key", "AREA", (-2.2, -2.6, 3.0), mid, 300, (1.0, 0.95, 0.88), 2.5)
    _light("fill", "AREA", (2.6, -1.8, 1.4), mid, 110, (0.8, 0.88, 1.0), 3.0)
    _light("rim", "AREA", (0.8, 2.8, 2.6), mid, 350, (0.9, 0.9, 1.0), 2.0)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def render(root, prefix, height=1.2, only=None):
    cam = stage(height)
    sc = bpy.context.scene
    for name, turn, hero in VIEWS:
        if only and name not in only:
            continue
        root.rotation_euler = (0, 0, math.radians(turn))
        if hero:
            cam.data.type = "PERSP"
            cam.data.lens = 85
            cam.location = (0.0, -4.6, 1.6)
            target = Vector((0, 0, height * 0.5))
        else:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = height * 1.25
            cam.location = (0, -6, height * 0.5)
            target = Vector((0, 0, height * 0.5))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"{prefix}_{name}.png"
        bpy.ops.render.render(write_still=True)
    root.rotation_euler = (0, 0, 0)
