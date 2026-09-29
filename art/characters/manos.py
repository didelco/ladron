"""Rehace las manos de art/personajes/ninja.blend y guardia.blend: un puño abstracto
de volúmenes simples, sin dedos contados, que se lee como mano a distancia de juego.

    Blender -b -P art/characters/manos.py -- ninja|guardia [--salida ruta.blend]

Solo cambia la malla de mano.L_<piel> y mano.R_<piel> (guante en el ninja, piel en el
guardia): conservan nombre, material, padre, modificador de esqueleto y todo el peso en
el hueso de la mano (vertex group mano.L / mano.R). Se puede repetir: siempre sale lo
mismo. Sin --salida guarda encima de art/personajes/<nombre>.blend.

La mano (la izquierda; la derecha es su espejo exacto en x) son tres masas:
- el puño: una caja muy redondeada (superelipsoide) con el dorso hacia fuera,
- los dedos: un solo rodillo a lo largo de los nudillos, enrollado hacia la palma,
- el pulgar: una cápsula que cruza por delante, sobre el rodillo.
El agujero del puño cae en el eje de la linterna del guardia (a lo largo de y), así que
la linterna le sale por delante del pulgar como si la apretara.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

## Eje del agarre de la mano izquierda: el de la linterna del guardia (el esqueleto es
## el mismo en los dos personajes, así que vale para el ninja).
GRIP = Vector((0.326, -0.073, 0.266))


def rounded_box(bm, centre, half, cuts, exps=(3.0, 3.0), rot=Matrix.Identity(3)):
    """Una caja redondeada (superelipsoide) con caras cuadradas repartidas por igual.
    `half` son los semiejes (x, y, z) antes de girarla con `rot`; `cuts` las divisiones
    de la rejilla en cada eje; `exps` = (e, f): e redondea la sección xy y f el perfil en
    z (2 es elipsoide, más es más cuadrado)."""
    nx, ny, nz = cuts
    verts = {}

    def vert(i, j, k):
        key = (i, j, k)
        if key not in verts:
            # De la rejilla del cubo a la dirección (con tan para que las caras salgan parejas).
            u = [math.tan(math.pi / 4 * (2 * c / n - 1)) for c, n in ((i, nx), (j, ny), (k, nz))]
            d = Vector(u).normalized()
            e, f = exps
            ax, ay, az = abs(d.x), abs(d.y), abs(d.z)
            g = (ax ** e + ay ** e) ** (f / e) + az ** f
            p = d * g ** (-1.0 / f)
            p = Vector((p.x * half[0], p.y * half[1], p.z * half[2]))
            verts[key] = bm.verts.new(Vector(centre) + rot @ p)
        return verts[key]

    faces = []
    # Seis caras del cubo: (eje fijo, valor, ejes que recorren).
    for axis, n_a in ((0, nx), (1, ny), (2, nz)):
        a1, a2 = [a for a in range(3) if a != axis]
        n1, n2 = cuts[a1], cuts[a2]
        for side in (0, n_a):
            for p in range(n1):
                for q in range(n2):
                    quad = []
                    for dp, dq in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        idx = [0, 0, 0]
                        idx[axis], idx[a1], idx[a2] = side, p + dp, q + dq
                        quad.append(vert(*idx))
                    faces.append(bm.faces.new(quad))
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def rot_to(direction):
    """Giro que lleva el eje z a `direction`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_matrix()


def left_hand(bm):
    """La mano izquierda (x > 0 es fuera, -y es delante, z arriba)."""
    g = GRIP
    # El puño: dorso por fuera del agarre, un poco más alto que él (la muñeca).
    rounded_box(bm, g + Vector((0.020, -0.004, 0.018)), (0.058, 0.076, 0.070), (6, 7, 7), exps=(3.2, 2.6))
    # Los dedos: un rodillo a lo largo de los nudillos, por debajo y hacia la palma.
    rounded_box(bm, g + Vector((-0.004, -0.004, -0.040)), (0.050, 0.074, 0.040), (4, 5, 4), exps=(2.4, 2.0),
                rot=Matrix.Rotation(math.radians(-18), 3, "Y"))
    # El pulgar: de la muñeca por dentro y delante, cruzando hacia abajo sobre los dedos.
    tip = g + Vector((-0.048, -0.076, -0.012))
    base = g + Vector((-0.034, -0.052, 0.050))
    axis = tip - base
    rounded_box(bm, (tip + base) / 2, (0.029, 0.029, axis.length / 2 + 0.024), (4, 4, 4), exps=(2.0, 2.0),
                rot=rot_to(axis))


def build(mesh, side):
    bm = bmesh.new()
    left_hand(bm)
    if side < 0:
        bmesh.ops.transform(bm, matrix=Matrix.Diagonal((-1, 1, 1, 1)), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.update()


def rebuild(skin):
    for side, tag in ((1, "L"), (-1, "R")):
        o = bpy.data.objects[f"mano.{tag}_{skin}"]
        mats = list(o.data.materials)
        o.data.clear_geometry()
        build(o.data, side)
        # clear_geometry deja los materiales; por si acaso, solo el de la mano.
        if not o.data.materials:
            for m in mats[:1]:
                o.data.materials.append(m)
        for vg in list(o.vertex_groups):
            if vg.name != f"mano.{tag}":
                o.vertex_groups.remove(vg)
        g = o.vertex_groups.get(f"mano.{tag}") or o.vertex_groups.new(name=f"mano.{tag}")
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        area = sum(p.area for p in o.data.polygons)
        print(f"[manos] {o.name}: {len(o.data.polygons)} caras, {area:.3f} m², {len(o.data.polygons) / area:.0f} caras/m²")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    name = args[0] if args else ""
    if name not in ("ninja", "guardia"):
        sys.exit("uso: Blender -b -P art/characters/manos.py -- ninja|guardia [--salida ruta.blend]")
    path = os.path.join(ART, "personajes", name + ".blend")
    out = args[args.index("--salida") + 1] if "--salida" in args else path
    bpy.ops.wm.open_mainfile(filepath=path)
    rebuild("guante" if name == "ninja" else "piel")
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("[manos]", out)
