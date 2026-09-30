"""Quita las solapas del ninja (no las necesita) y rehace el cordón de la cintura, sobre su .blend por piezas.

    Blender -b -P art/characters/cordon.py [-- --salida ruta.blend]

Sin --salida guarda encima de art/personajes/ninja.blend. Se ejecuta una vez: reemplaza
las piezas pecho_solapa, columna_solapa y cadera_cinta_2/3/4 por otras nuevas.

Ya pasado y superado: el ninja de ahora lo rehace art/characters/ninja_v2.py (cinturón, nudo y
colas incluidos) y estas piezas ya no existen. No volver a ejecutarlo.

- Solapas: fuera. El torso queda liso, como los ninjas de la imagen de referencia (cuerpos de
  goma sencillos, sin ropa dibujada).
- Cordón: un nudo con dos lazos y un ceñidor, y dos colas cónicas que caen algo abiertas, una
  más larga que otra, en vez del bloque y las dos barras de antes.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
path = os.path.join(ART, "personajes", "ninja.blend")
out = args[args.index("--salida") + 1] if "--salida" in args else path
bpy.ops.wm.open_mainfile(filepath=path)

arm = bpy.data.objects["ninja_esqueleto"]
torso = bpy.data.objects["pecho_traje"]
solapa_mat = bpy.data.objects["pecho_solapa"].data.materials[0]
cinta_mat = bpy.data.objects["cadera_cinta"].data.materials[
    bpy.data.objects["cadera_cinta"].data.polygons[0].material_index]
for n in ("pecho_solapa", "columna_solapa", "cadera_cinta_2", "cadera_cinta_3", "cadera_cinta_4"):
    bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)

# El torso en reposo, para apoyar las solapas.
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
torso_eval = torso.evaluated_get(deps)
tree = KDTree(len(torso.data.vertices))
for v in torso.data.vertices:
    tree.insert(v.co, v.index)
tree.balance()


def surface(x, z):
    """El punto y la normal del frente del torso en (x, z)."""
    ok, loc, nor, _ = torso_eval.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
    if not ok:
        return Vector((x, -0.18, z)), Vector((0, -1, 0))
    return loc, nor.normalized()


def smooth(t):
    return t * t * (3 - 2 * t)


def bezier(pts, n):
    """Puntos de una curva cuadrática o cúbica por los puntos de control (de Casteljau)."""
    out = []
    for i in range(n + 1):
        t = i / n
        p = [Vector(q) for q in pts]
        while len(p) > 1:
            p = [p[j].lerp(p[j + 1], t) for j in range(len(p) - 1)]
        out.append(p[0])
    return out


def ribbon(name, path, width, thick, mat, weights, end_round=(0.35, 0.35), rows=10, follow=None):
    """Una cinta plana y redondeada a lo largo de `path` (lista de Vector 3D con su normal en
    `follow(p) -> (punto, normal)` si se apoya en el torso). `width` y `thick` son medias
    dimensiones: números o funciones de t (0..1). Termina en punta redondeada."""
    bm = bmesh.new()
    n = len(path)
    ring = []
    for i, p in enumerate(path):
        t = i / (n - 1)
        pt, no = follow(p) if follow else (p, Vector((0, -1, 0)))
        tang = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        side = tang.cross(no).normalized()
        no = side.cross(tang).normalized()
        w = width(t) if callable(width) else width
        th = thick(t) if callable(thick) else thick
        # Punta redondeada al principio y al final.
        for e, k in ((t, end_round[0]), (1 - t, end_round[1])):
            if e < 0.06:
                s = math.sqrt(max(0.0, 1 - (1 - e / 0.06) ** 2))
                w *= max(0.12, s)
                th *= max(0.3, s)
        verts = []
        for j in range(rows):
            a = 2 * math.pi * j / rows
            verts.append(bm.verts.new(pt + side * (w * math.cos(a)) + no * (th * math.sin(a))))
        ring.append(verts)
    for i in range(n - 1):
        for j in range(rows):
            bm.faces.new((ring[i][j], ring[i][(j + 1) % rows], ring[i + 1][(j + 1) % rows], ring[i + 1][j]))
    for r in (ring[0], ring[-1]):
        bm.faces.new(r if r is ring[0] else r[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, mat, weights)


def finish(name, bm, mat, weights):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    for c in bpy.data.objects["pecho_traje"].users_collection:
        c.objects.link(o)
    o.parent = arm
    o.matrix_parent_inverse = bpy.data.objects["pecho_traje"].matrix_parent_inverse.copy()
    o.modifiers.new("Armature", "ARMATURE").object = arm
    if weights == "torso":
        groups = {}
        for v in me.vertices:
            _, idx, _ = tree.find(v.co)
            for g in torso.data.vertices[idx].groups:
                nm = torso.vertex_groups[g.group].name
                if nm not in groups:
                    groups[nm] = o.vertex_groups.new(name=nm)
                groups[nm].add([v.index], g.weight, "REPLACE")
    else:
        g = o.vertex_groups.new(name=weights)
        g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    return o


def ellipsoid(bm, centre, radii, rot=(0, 0, 0), u=16, v=10):
    geo = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)["verts"]
    from mathutils import Matrix
    m = Matrix.Translation(centre) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") \
        @ Matrix.Rotation(rot[0], 4, "X") @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=geo)


# --- Cordón ---------------------------------------------------------------------------------
bm = bmesh.new()
z0 = 0.360
ellipsoid(bm, Vector((-0.030, -0.208, z0 + 0.004)), (0.030, 0.020, 0.030), rot=(0, 0.35, 0.10))
ellipsoid(bm, Vector((0.030, -0.208, z0 + 0.004)), (0.030, 0.020, 0.030), rot=(0, -0.35, -0.10))
ellipsoid(bm, Vector((0.0, -0.213, z0)), (0.020, 0.022, 0.034))
finish("cadera_cinta_4", bm, cinta_mat, "cadera")


def tail(name, x0, x1, z_end, side):
    pts = [Vector((x0, -0.205, z0 - 0.012)), Vector((x0 + 0.4 * (x1 - x0), -0.212, z0 - 0.06)),
           Vector((x1, -0.205, (z0 + z_end) / 2 - 0.02)), Vector((x1 + side * 0.01, -0.198, z_end))]
    path = bezier(pts, 14)
    ribbon(name, path, lambda t: 0.017 + 0.011 * smooth(t), lambda t: 0.008, cinta_mat, "cadera", end_round=(0.5, 0.5))


tail("cadera_cinta_2", -0.014, -0.056, 0.222, -1)
tail("cadera_cinta_3", 0.014, 0.046, 0.262, 1)

arm.data.pose_position = "POSE"
bpy.ops.wm.save_as_mainfile(filepath=out)
print("[cordon] guardado", out)
