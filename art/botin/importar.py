"""Monta art/botin.blend con las piezas a robar tal como estaban en código
(art/botin/primitivas.gd): una colección por pieza, un objeto por pieza.
Solo es el historial: se ejecutó una vez; volver a hacerlo pisa los retoques.

    Blender -b -P art/botin/importar.py -- <carpeta con los .glb y .json>

Los .glb y .json salen de primitivas.gd (un script de Godot que construye
cada pieza en magenta puro para saber qué partes siguen el color de la
pieza: esos materiales se llaman "color", "color_claro_N", "color_oscuro_N").
"""
import json
import os
import sys

import bpy

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(ART)
import catalogo  # noqa: E402

## La forma del juego (LootModels) y el nombre de su pieza en el catálogo
## (las de entonces: el ketchup se modeló luego, a mano, en el .blend).
NAMES = {"teeth": "dentadura", "duck": "pato", "sock": "calcetin", "toast": "tostada", "crown": "corona",
         "rock": "queso_lunar", "gum": "chicle", "mask": "mascara", "clock": "despertador", "egg": "huevo",
         "gem": "diamante", "idol": "idolo"}


def linear(hex_):
    c = [int(hex_[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def material(info):
    m = bpy.data.materials.new(info["name"])
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    rgb = linear(info["colour"]) + [1.0]
    b.inputs["Base Color"].default_value = rgb
    b.inputs["Roughness"].default_value = info["rough"]
    b.inputs["Metallic"].default_value = info["metal"]
    b.inputs["Alpha"].default_value = info["alpha"]
    b.inputs["Emission Color"].default_value = rgb
    b.inputs["Emission Strength"].default_value = info["glow"]
    m.diffuse_color = rgb
    if info["alpha"] < 1.0:
        m.surface_render_method = "BLENDED"
    return m


src = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_homefile(use_empty=True)
catalogo.mark("piezas", "botin")
for shape, name in NAMES.items():
    coll = catalogo.add_piece(name)
    coll["sitio"] = "botin"
    coll["forma"] = shape
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, shape + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    infos = {i["name"]: i for i in json.load(open(os.path.join(src, shape + ".json")))}
    mats = {}
    meshes = []
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        if o.type != "MESH":
            continue
        meshes.append(o)
        for s in o.material_slots:
            key = s.material.name.split(".")[0] if s.material else None
            if key in infos:
                if key not in mats:
                    mats[key] = material(infos[key])
                s.material = mats[key]
    # Todo en un objeto con el nombre de la pieza, sin padres ni vacíos.
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
for m in list(bpy.data.materials):
    if m.users == 0:
        bpy.data.materials.remove(m)
catalogo.arrange()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "botin.blend"))
print("[botin] guardado art/botin.blend")
