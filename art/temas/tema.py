"""Lo común a los temas de la colección: cada tema (art/temas/<tema>.py) define
sus piezas como funciones que devuelven objetos; aquí se exporta cada una a
assets/models/temas/<tema>/<pieza>.glb y se saca una hoja con todas.

Medidas (1 unidad = una casilla, el pie en z = 0, el frente mirando a -Y):
  vitrina ("case"):  cabe en 0,6 × 0,6 y 0,34 de alto (se posa en su base)
  peana ("plinth"):  hasta 0,5 × 0,5 y 0,5 de alto (se posa encima)
  suelo ("floor"):   hasta 0,8 × 0,8 y 1,1 de alto (sobre la losa del hueco)
Los materiales guardan su color base; el juego les pone el sombreado toon.

    Blender -b -P art/temas/egipto.py -- --blend art/tema_antiguo.blend   # el .blend
    Blender -b -P art/temas/egipto.py                   # exporta todas
    Blender -b -P art/temas/egipto.py -- --sheet /ruta   # hoja de revisión

Así se hizo la primera versión. Ahora las piezas se retocan a mano en
art/tema_<tema>.blend y salen con art/export.py: volver a ejecutar esto pisa
esos retoques (el .blend con --blend, los .glb sin nada).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "characters"))
import bpy  # noqa: E402

import kit  # noqa: E402

MODELS = os.path.join(HERE, "..", "..", "assets", "models", "temas")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

## Tamaño máximo de cada sitio: [ancho, fondo, alto].
FITS = {"case": (0.6, 0.6, 0.34), "plinth": (0.5, 0.5, 0.5), "floor": (0.8, 0.8, 1.1)}


def run(theme, pieces):
    """pieces: [(nombre, sitio, función que construye y devuelve objetos)].
    El tema ya ha vaciado la escena (kit.reset) antes de crear sus materiales."""
    built = []
    for name, where, make in pieces:
        root = kit.empty(name)
        objs = make()
        kit.parent_all(root, objs)
        _check(name, where, objs)
        built.append((name, where, root, objs))
    if "--sheet" in ARGS:
        _sheet(built, ARGS[ARGS.index("--sheet") + 1])
        return
    if "--blend" in ARGS:
        _blend(theme, built, ARGS[ARGS.index("--blend") + 1])
        return
    out = os.path.join(MODELS, theme)
    os.makedirs(out, exist_ok=True)
    for name, where, root, objs in built:
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True)
        print("[export]", theme, name)


def _blend(theme, built, path):
    """Cada pieza en su colección, en fila (art/catalogo.py), y el fichero
    guardado en path."""
    sys.path.append(os.path.join(HERE, ".."))
    import catalogo
    scene = bpy.context.scene.collection
    for name, where, root, objs in built:
        coll = catalogo.add_piece(name)
        coll["sitio"] = where
        for o in objs:
            world = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = world
            for c in list(o.users_collection):
                c.objects.unlink(o)
            coll.objects.link(o)
        bpy.data.objects.remove(root, do_unlink=True)
    left = [o.name for o in scene.objects]
    if left:
        print("[blend] objetos sueltos, fuera de las piezas:", ", ".join(left))
    catalogo.mark("piezas", "temas/" + theme)
    catalogo.arrange()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path))
    print("[blend]", path, len(built), "piezas")


def _check(name, where, objs):
    """Avisa si una pieza no cabe en su sitio."""
    from mathutils import Vector
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    size = hi - lo
    fx, fy, fz = FITS[where]
    if size.x > fx + 0.02 or size.y > fy + 0.02 or size.z > fz + 0.02 or lo.z < -0.01:
        print(f"[fit] {name} ({where}) mide {size.x:.2f} × {size.y:.2f} × {size.z:.2f}, suelo {lo.z:.2f}")


def _sheet(built, path):
    """Cada pieza en su recuadro, en tres cuartos, sobre su sitio de
    referencia en gris (la vitrina abierta, la peana o la losa) para ver la
    escala; luego todas juntas en una hoja: path."""
    import sheet
    from mathutils import Vector
    cam = sheet.stage()
    sc = bpy.context.scene
    sc.render.resolution_x = 420
    sc.render.resolution_y = 420
    ghost = kit.mat("referencia", "#9aa0b4", rough=0.8)
    refs = {
        "case": (kit.box("ref_case", (0, 0, 0.21), (0.8, 0.8, 0.42), bevel=0.02), 0.42, 0.9),
        "plinth": (kit.box("ref_plinth", (0, 0, 0.25), (0.6, 0.6, 0.5), bevel=0.01), 0.5, 1.2),
        "floor": (kit.box("ref_floor", (0, 0, 0.08), (0.9, 0.9, 0.16), bevel=0.01), 0.16, 1.7),
    }
    for g, _, _ in refs.values():
        kit.paint(g, ghost)
    frames = []
    for i, (name, where, root, objs) in enumerate(built):
        for n2, w2, r2, _ in built:
            r2.location = (0, 0, -50)
        for k, (g, _, _) in refs.items():
            g.location.z = 0 if k == where else -50
            g.hide_render = k != where
        base, zoom = refs[where][1], refs[where][2]
        root.location = (0, 0, base)
        root.rotation_euler = (0, 0, math.radians(-30))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = zoom
        mid = Vector((0, 0, base + zoom * 0.3))
        cam.location = mid + Vector((0, -5, 2.6))
        cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
        out = f"{path}_{i:02d}.png"
        sc.render.filepath = out
        bpy.ops.render.render(write_still=True)
        frames.append((name, where, out))
    import json
    with open(path + ".json", "w") as f:
        json.dump(frames, f)


# --- Añadir o rehacer piezas en un .blend del catálogo ------------------------------

def replace(path, out, pieces, sitio, scale=None):
    """Abre art/<fichero>.blend (o lo crea, con su carpeta de salida out) y
    pone cada pieza en su colección: pieces = [(nombre, función)]; si ya
    estaba, la sustituye (pisa sus retoques). sitio(nombre) da su propiedad
    "sitio"; scale, la escala de cada una desde su pie. Ordena la fila,
    guarda y exporta esas piezas; devuelve sus nombres."""
    sys.path.append(os.path.join(HERE, ".."))
    import catalogo
    scale = scale or {}
    if os.path.exists(path):
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        kit.reset()
        catalogo.mark("piezas", out)
    kit._mats.clear()
    for name, make in pieces:
        old = bpy.data.collections.get(name)
        if old:
            for o in list(old.all_objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(old)
            bpy.context.view_layer.update()
        coll = catalogo.add_piece(name)
        coll["sitio"] = sitio(name)
        objs = make()
        k = scale.get(name, 1.0)
        for o in objs:
            if o.parent is None and k != 1.0:
                o.location *= k
                o.scale *= k
        for o in objs:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            coll.objects.link(o)
        print("[pieza]", name)
    catalogo.arrange()
    bpy.ops.wm.save_as_mainfile(filepath=path)
    return catalogo.export_file(path, [n for n, _ in pieces])


# --- Piezas de apoyo que se repiten entre temas -----------------------------------

def cushion(name, w, d, colour, h=0.04):
    """Un cojín o paño de terciopelo donde se posa una pieza pequeña."""
    c = kit.superellipsoid(name, (0, 0, h / 2), (w / 2, d / 2, h / 2), e=3.5)
    kit.paint(c, colour)
    return c


def stand_block(name, w, d, h, colour, bevel=0.01):
    b = kit.box(name, (0, 0, h / 2), (w, d, h), bevel=bevel)
    kit.paint(b, colour)
    kit.smooth_shade(b)
    return b
