"""Mejora de una sola vez las piezas de art/personajes/ninja.blend y guardia.blend:
manos con dedos y pulgar (en vez de una bola con un bultito) y caras repartidas por
igual (las mismas por metro cuadrado en el torso que en las orejas, sin gastar miles
de caras en ojos o pilotos del tamaño de una uña).

    Blender -b -P art/characters/mejorar_partes.py -- ninja|guardia [--salida ruta.blend]

Sin --salida guarda encima de art/personajes/<nombre>.blend. Las piezas conservan su
nombre, su esqueleto y sus pesos; solo cambia su malla.

Ya se ha pasado: no volver a ejecutarlo. Las manos de ahora (un puño abstracto) las
rehace art/characters/manos.py, que sí se puede repetir.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
name = args[0] if args else ""
if name not in ("ninja", "guardia"):
    sys.exit("uso: Blender -b -P art/characters/mejorar_partes.py -- ninja|guardia [--salida ruta.blend]")
path = os.path.join(ART, "personajes", name + ".blend")
out = args[args.index("--salida") + 1] if "--salida" in args else path

## Caras por metro cuadrado de superficie, y mínimo por pieza (más para las que son redondas y se ven de cerca).
DENSITY = 1500
MIN_FACES = 96
MIN_FACES_ROUND = 200
## Tamaño de la mano respecto de lo dibujado abajo (estilo achaparrado).
HAND_SCALE = 1.3

bpy.ops.wm.open_mainfile(filepath=path)


def ellipsoid(bm, centre, radii, tilt=(0, 0, 0), u=18, v=12):
    """Una esfera achatada en `centre` (un Vector) con `radii` (x, y, z) y un giro de Euler."""
    geo = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)["verts"]
    m = Matrix.Translation(centre) @ Matrix.Rotation(tilt[2], 4, "Z") @ Matrix.Rotation(tilt[1], 4, "Y") \
        @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=geo)


def hand_mesh(mesh, centre, side):
    """Una mano cerrada: dorso, cuatro dedos enrollados y el pulgar por delante.
    `centre` es el centro de la bola de antes; side = +1 (izquierda, x > 0) o -1."""
    k = HAND_SCALE
    bm = bmesh.new()
    s = side
    o = Vector(centre)

    def at(x, y, z):
        return o + Vector((s * x * k, y * k, z * k))

    ellipsoid(bm, at(0.012, 0.0, 0.012), (0.05 * k, 0.062 * k, 0.062 * k))
    # Los dedos: de índice (delante) a meñique, enrollados por abajo, del nudillo hacia la palma.
    for i, (y, r, ln) in enumerate(((-0.049, 0.024, 0.050), (-0.016, 0.025, 0.054), (0.017, 0.024, 0.050), (0.048, 0.020, 0.042))):
        ellipsoid(bm, at(-0.004, y, -0.046), (ln * k, r * k, r * k), tilt=(0, 0, 0.0))
    # El pulgar, tumbado sobre los dedos por la cara de la palma (no como un «vale» hacia arriba).
    ellipsoid(bm, at(-0.040, -0.030, -0.058), (0.022 * k, 0.056 * k, 0.021 * k), tilt=(0, 0, 0.25 * s))
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True


def tris(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def area(o):
    return sum(p.area for p in o.data.polygons)


meshes = [o for o in bpy.data.objects if o.type == "MESH"]
# --- Manos ------------------------------------------------------------------------------
skin = "guante" if name == "ninja" else "piel"
for side, tag in ((1, "L"), (-1, "R")):
    body = bpy.data.objects[f"mano.{tag}_{skin}"]
    thumb = bpy.data.objects[f"mano.{tag}_{skin}_2"]
    centre = sum((body.matrix_world @ v.co for v in body.data.vertices), Vector()) / len(body.data.vertices)
    mat = body.data.materials[body.data.polygons[0].material_index]
    body.data.clear_geometry()
    hand_mesh(body.data, centre, side)
    body.data.materials.clear()
    body.data.materials.append(mat)
    # Todo el peso al hueso de la mano.
    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    g = body.vertex_groups.new(name=f"mano.{tag}")
    g.add(list(range(len(body.data.vertices))), 1.0, "REPLACE")
    bpy.data.objects.remove(thumb, do_unlink=True)

# --- Caras por igual --------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
before = after = 0
for o in [x for x in bpy.data.objects if x.type == "MESH"]:
    a = max(area(o), 1e-6)
    before += len(o.data.polygons)
    faces = len(o.data.polygons)
    round_ = "ojo" in o.name or "pupila" in o.name or "oro" in o.name
    target = max(DENSITY * a, MIN_FACES_ROUND if round_ else MIN_FACES)
    if faces > target and o.name not in (f"mano.L_{skin}", f"mano.R_{skin}"):
        d = o.modifiers.new("aligerar", "DECIMATE")
        d.ratio = max(0.02, (2 * target) / max(1, tris(o.data)))
        d.use_collapse_triangulate = False
        # Antes que el esqueleto.
        o.modifiers.move(o.modifiers.find(d.name), 0)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=d.name)
    after += len(o.data.polygons)
print(f"[mejorar] {name}: {before} -> {after} caras")
bpy.ops.wm.save_as_mainfile(filepath=out)
