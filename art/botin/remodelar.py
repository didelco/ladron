"""Rehace en art/botin.blend el pato, la corona y el chicle, con más detalle
del que daban las primitivas: cuerpos de metaball fundidos en una sola
malla, la banda de la corona de una pieza con sus puntas, una copa torneada.
Solo es el historial: se ejecutó una vez; volver a hacerlo pisa los retoques.

    Blender -b art/botin.blend -P art/botin/remodelar.py

Cada parte queda como un objeto con su nombre (pato_cuerpo, corona_banda...)
y sus modificadores vivos (subdivisión, grosor, biselado): el exportador los
aplica. Los materiales que siguen el color de la pieza se llaman "color",
"color_claro_N" o "color_oscuro_N" (LootModels los tiñe en el juego).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(ART)
import catalogo  # noqa: E402


# --- Ayudas --------------------------------------------------------------------

def linear(hex_):
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def shade(hex_, light=0.0, dark=0.0):
    """Como Color.lightened / darkened de Godot, en sRGB."""
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x + (1 - x) * light for x in c]
    c = [x * (1 - dark) for x in c]
    return "#" + "".join("%02x" % round(x * 255) for x in c)


def mat(name, hex_, rough=0.5, metal=0.0, glow=0.12, alpha=1.0):
    m = bpy.data.materials.new(name)
    b = m.node_tree.nodes["Principled BSDF"]
    rgb = linear(hex_)
    b.inputs["Base Color"].default_value = rgb
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Alpha"].default_value = alpha
    b.inputs["Emission Color"].default_value = rgb
    b.inputs["Emission Strength"].default_value = glow
    m.diffuse_color = rgb
    if alpha < 1.0:
        m.surface_render_method = "BLENDED"
    return m


class Piece:
    """Las partes de una pieza, en su colección."""

    def __init__(self, name):
        self.name = name
        self.coll = bpy.data.collections[name]
        self.offset = Vector(self.coll.instance_offset)
        for o in list(self.coll.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        self.parts = []

    def put(self, obj, part, material=None):
        obj.name = f"{self.name}_{part}"
        if obj.data is not None and hasattr(obj.data, "name"):
            obj.data.name = obj.name
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        self.coll.objects.link(obj)
        if material is not None:
            obj.data.materials.clear()
            obj.data.materials.append(material)
        self.parts.append(obj)
        return obj

    def finish(self, turn=0.0):
        """Gira la pieza entera sobre su eje y la lleva a su sitio en la fila."""
        bpy.context.view_layer.update()
        m = Matrix.Translation(self.offset) @ Matrix.Rotation(turn, 4, "Z")
        for o in self.parts:
            if o.parent is None:
                o.matrix_world = m @ o.matrix_world


def mesh_obj(bm, name="parte"):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def smooth(o, levels=0):
    for p in o.data.polygons:
        p.use_smooth = True
    if levels:
        mod = o.modifiers.new("subdivision", "SUBSURF")
        mod.levels = levels
        mod.render_levels = levels
    return o


def sphere(r, at, scale=(1, 1, 1), rot=(0, 0, 0), segs=24, rings=12, sub=0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    o = mesh_obj(bm)
    o.location = at
    o.rotation_euler = rot
    o.scale = scale
    return smooth(o, sub)


def ico(r, at, scale=(1, 1, 1), rot=(0, 0, 0)):
    """Una piedra tallada: pocas caras, planas."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    o = mesh_obj(bm)
    o.location = at
    o.rotation_euler = rot
    o.scale = scale
    return o


def cylinder(r1, r2, h, at, rot=(0, 0, 0), segs=24, sub=0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=h)
    o = mesh_obj(bm)
    o.location = at
    o.rotation_euler = rot
    return smooth(o, sub) if sub else o


def torus(major, minor, at, rot=(0, 0, 0), scale=(1, 1, 1), segs=48, ring=12):
    bm = bmesh.new()
    verts = []
    for i in range(segs):
        a = i * math.tau / segs
        row = []
        for j in range(ring):
            b = j * math.tau / ring
            rr = major + minor * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), minor * math.sin(b))))
        verts.append(row)
    for i in range(segs):
        for j in range(ring):
            bm.faces.new((verts[i][j], verts[(i + 1) % segs][j], verts[(i + 1) % segs][(j + 1) % ring], verts[i][(j + 1) % ring]))
    o = mesh_obj(bm)
    o.location = at
    o.rotation_euler = rot
    o.scale = scale
    return smooth(o)


def lathe(profile, segs=40):
    """Un sólido de revolución alrededor de Z: profile es [(radio, z), ...] de abajo arriba."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(i * math.tau / segs), r * math.sin(i * math.tau / segs), z)) for i in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        if ring[0].co.xy.length > 1e-4:
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
    return smooth(mesh_obj(bm))


def tube(points, radius, taper_end=1.0):
    """Un cordón que pasa por points (curva con grosor, convertida a malla)."""
    cu = bpy.data.curves.new("cordon", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points):
        p.co = (*co, 1.0)
    for i, p in enumerate(sp.points):
        p.radius = 1.0 + (taper_end - 1.0) * i / max(1, len(points) - 1)
    sp.use_endpoint_u = True
    sp.order_u = 3
    sp.resolution_u = 8
    o = bpy.data.objects.new("cordon", cu)
    bpy.context.scene.collection.objects.link(o)
    return to_mesh(o)


def to_mesh(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.view_layer.objects.active
    return smooth(o)


def blob(name, elements, resolution=0.006, threshold=0.6):
    """Metaballs fundidas en una sola malla lisa. elements: (co, radio, tamaño
    xyz o None, giro como cuaternión o None)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    for co, r, size, rot in elements:
        e = mb.elements.new()
        e.co = co
        e.radius = r
        if size is not None:
            e.type = "ELLIPSOID"
            e.size_x, e.size_y, e.size_z = size
        if rot is not None:
            e.rotation = rot
    o = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.update()
    return to_mesh(o)


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


# --- El pato ------------------------------------------------------------------------

def duck():
    """Un pato de goma a media aria: cuerpo de una pieza que sube a la cola,
    tupé, pico abierto, párpados a media altura, pajarita y dos notas."""
    p = Piece("pato")
    yellow = "#ffd43b"
    m_body = mat("color", yellow, rough=0.3)
    m_wing = mat("color_oscuro_7", shade(yellow, dark=0.07), rough=0.3)
    m_lid = mat("color_oscuro_5", shade(yellow, dark=0.05), rough=0.3)
    m_beak = mat("pico", "#ff8c1a", rough=0.35)
    m_beak_low = mat("pico_bajo", "#eb8118", rough=0.35)
    m_mouth = mat("boca", "#8a1c2b", rough=0.6)
    m_white = mat("ojo", "#ffffff", rough=0.2)
    m_ink = mat("tinta", "#1c1c24", rough=0.6, glow=0.05)
    m_shine = mat("brillo", "#ffffff", rough=0.1, glow=1.0)
    m_note = mat("nota", "#ffe8a3", rough=0.3, glow=0.9)

    # El cuerpo, de una pieza: secciones de proa a popa, redondo en el
    # pecho, estrechándose y subiendo hasta la punta de la cola; la base, plana.
    rings, around = 44, 36
    bm = bmesh.new()
    grid = []
    for i in range(rings + 1):
        x = 0.165 - 0.38 * i / rings
        if x >= -0.02:
            f = math.sqrt(max(0.0, 1 - ((x + 0.02) / 0.185) ** 2))
            w, h, cz = 0.132 * f, 0.09 * f ** 0.8, 0.1
        else:
            u = (-0.02 - x) / 0.195
            w, h, cz = 0.132 * (1 - u ** 1.7), 0.09 * (1 - u ** 1.25), 0.1 + 0.1 * u ** 2
        col = []
        for j in range(around):
            a = j * math.tau / around
            z = cz + math.sin(a) * h
            col.append(bm.verts.new((x, math.cos(a) * w, max(z, 0.006))))
        grid.append(col)
    for i in range(rings):
        for j in range(around):
            n = (j + 1) % around
            bm.faces.new((grid[i][j], grid[i][n], grid[i + 1][n], grid[i + 1][j]))
    bmesh.ops.pointmerge(bm, verts=grid[0], merge_co=grid[0][0].co.copy())
    bmesh.ops.pointmerge(bm, verts=grid[-1], merge_co=grid[-1][0].co.copy())
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    p.put(smooth(mesh_obj(bm), 1), "cuerpo", m_body)
    p.put(sphere(0.072, (0.06, 0, 0.195), segs=32, rings=16), "cuello", m_body)
    p.put(sphere(0.086, (0.07, 0, 0.275), segs=32, rings=16), "cabeza", m_body)

    # Las alas: plumas pegadas a los costados, la punta hacia la cola.
    for side in (-1, 1):
        wing = sphere(0.07, (-0.035, side * 0.118, 0.125), (1.45, 0.3, 0.62), (side * -0.1, -0.22, side * 0.12), segs=32, rings=16, sub=1)
        p.put(wing, "ala_" + ("izq" if side > 0 else "dcha"), m_wing)

    head = Vector((0.07, 0, 0.275))
    # El tupé: dos plumas que se curvan hacia atrás.
    for i, (dx, lean, r) in enumerate(((-0.005, 0.35, 0.026), (-0.03, 0.8, 0.02))):
        tuft = tube([head + Vector((dx, 0, 0.07)), head + Vector((dx - 0.004, 0, 0.1)),
                     head + Vector((dx - 0.03 * lean, 0, 0.118)), head + Vector((dx - 0.045 * lean, 0, 0.108))], r * 0.45, taper_end=0.2)
        p.put(tuft, f"tupe_{i + 1}", m_body)

    # El pico, abierto en el agudo, y la boca dentro.
    p.put(sphere(0.032, head + Vector((0.065, 0, -0.03))), "boca", m_mouth)
    p.put(sphere(0.045, head + Vector((0.085, 0, -0.005)), (1.55, 1.05, 0.42), (0, -0.28, 0), sub=1), "pico", m_beak)
    p.put(sphere(0.04, head + Vector((0.078, 0, -0.052)), (1.35, 0.95, 0.38), (0, 0.38, 0), sub=1), "pico_bajo", m_beak_low)

    # Los ojos, con los párpados a media altura: canta con sentimiento.
    for side in (-1, 1):
        s = "izq" if side > 0 else "dcha"
        d = Vector((0.55, side * 0.72, 0.38)).normalized()
        p.put(sphere(0.024, head + d * 0.07), "ojo_" + s, m_white)
        p.put(sphere(0.012, head + d * 0.089), "pupila_" + s, m_ink)
        p.put(sphere(0.0045, head + d * 0.098 + Vector((0, 0, 0.005)), segs=12, rings=6), "brillo_" + s, m_shine)
        lid = sphere(0.027, head + d * 0.071 + Vector((0, 0, 0.004)), rings=16)
        # Solo la mitad de arriba: un párpado que cae hasta media pupila.
        bm = bmesh.new()
        bm.from_mesh(lid.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.004], context="VERTS")
        bm.to_mesh(lid.data)
        bm.free()
        lid.rotation_euler = (side * 0.25, -0.35, 0)
        p.put(lid, "parpado_" + s, m_lid)

    # La pajarita: dos alas mullidas que se juntan en el nudo.
    for side in (-1, 1):
        bm = bmesh.new()
        tip = bm.verts.new((0, 0, 0))
        back = [bm.verts.new((-0.012, side * 0.058, z)) for z in (-0.036, 0.036)]
        front = [bm.verts.new((0.012, side * 0.058, z)) for z in (-0.036, 0.036)]
        for f in ((tip, front[0], front[1]), (tip, back[1], back[0]), (tip, front[1], back[1]), (tip, back[0], front[0]),
                  (front[0], back[0], back[1], front[1])):
            bm.faces.new(f)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        wing = smooth(mesh_obj(bm), 2)
        wing.location = (0.152, 0, 0.183)
        wing.rotation_euler = (0, -0.25, 0)
        p.put(wing, "pajarita_" + ("izq" if side > 0 else "dcha"), m_ink)
    p.put(sphere(0.015, (0.158, 0, 0.183), (0.8, 1.1, 1.0)), "pajarita_nudo", m_ink)

    # Dos notas que salen volando del pico.
    for i, (at, k) in enumerate(((Vector((0.23, -0.03, 0.34)), 1.0), (Vector((0.28, 0.02, 0.41)), 0.75))):
        note = [sphere(0.017 * k, at, (1.3, 0.6, 0.95), (0, -0.4, 0))]
        note.append(cylinder(0.0028 * k, 0.0028 * k, 0.066 * k, at + Vector((0.018, 0, 0.034)) * 1.0, segs=8))
        note.append(tube([at + Vector((0.018 * k, 0, 0.066 * k)), at + Vector((0.034 * k, 0, 0.05 * k)),
                          at + Vector((0.036 * k, 0, 0.03 * k))], 0.004 * k, taper_end=0.4))
        p.put(join(note), f"nota_{i + 1}", m_note)
    p.finish(turn=-0.55)


# --- La corona -----------------------------------------------------------------------

def pickle(p, name, at, lean, size, m_green, m_warts, m_stalk):
    """Un pepinillo de pie: verde, un poco doblado, con verrugas y su rabito."""
    def dressed(o, m):
        o.data.materials.append(m)
        return o

    body = sphere(0.021 * size, (0, 0, 0), (1, 0.95, 1.9), sub=1)
    bpy.context.view_layer.update()
    bm = bmesh.new()
    bm.from_mesh(body.data)
    for v in bm.verts:
        v.co.x += (v.co.z * 1.9 / 0.04) ** 2 * 0.002
    bm.to_mesh(body.data)
    bm.free()
    parts = [dressed(body, m_green)]
    for k in range(9):
        a = k * 2.39996
        z = (-0.028 + 0.056 * k / 8) * size
        rr = 0.02 * size * math.sqrt(max(0.1, 1 - (z / (0.04 * size)) ** 2))
        parts.append(dressed(sphere(0.0042 * size, (math.cos(a) * rr, math.sin(a) * rr, z), segs=8, rings=5), m_warts))
    parts.append(dressed(cylinder(0.005 * size, 0.004 * size, 0.012 * size, (0.004 * size, 0, 0.041 * size), segs=8), m_stalk))
    o = join(parts)
    o.location = at
    o.rotation_euler = lean
    return p.put(o, name)


def crown():
    """La corona de la Reina de los Pepinillos: armiño, banda de oro de una
    pieza con cinco puntas grandes y cinco chicas, rubíes y zafiros, perlas,
    terciopelo bajo dos arcos, y un pepinillo en cada punta y en lo alto."""
    p = Piece("corona")
    green = "#7bc043"
    m_gold = mat("oro", "#e8b54a", rough=0.28, metal=0.45, glow=0.1)
    m_gold_dark = mat("oro_viejo", shade("#e8b54a", dark=0.14), rough=0.35, metal=0.45, glow=0.1)
    m_ermine = mat("armino", "#f6f1e7", rough=0.95, glow=0.15)
    m_tip = mat("armino_punta", "#1c1c24", rough=0.8, glow=0.05)
    m_velvet = mat("terciopelo", "#8e1b3a", rough=1.0, glow=0.12)
    m_pearl = mat("perla", "#fbf6ea", rough=0.15, glow=0.3)
    m_ruby = mat("rubi", "#c2185b", rough=0.08, metal=0.2, glow=0.5)
    m_sapphire = mat("zafiro", "#2f6fd6", rough=0.08, metal=0.2, glow=0.5)
    m_green = mat("color", green, rough=0.55, glow=0.2)
    m_warts = mat("color_claro_15", shade(green, light=0.15), rough=0.6, glow=0.2)
    m_stalk = mat("color_oscuro_35", shade(green, dark=0.35), rough=0.7, glow=0.1)

    # El armiño: un rollo de piel blanca, con las colitas negras.
    p.put(torus(0.148, 0.03, (0, 0, 0.032), scale=(1, 1, 1.05), segs=64, ring=16), "armino", m_ermine)
    for k in range(12):
        a = k * math.tau / 12 + 0.2
        tip = sphere(0.0075, (math.cos(a) * 0.176, math.sin(a) * 0.176, 0.036), (0.8, 0.8, 1.7), (0, 0, a), segs=10, rings=6)
        p.put(tip, f"armino_punta_{k + 1}", m_tip)

    # La banda con sus puntas, de una sola pieza: un zigzag de cinco puntas
    # grandes y cinco chicas, un poco abierta hacia arriba, con grosor y
    # los cantos redondeados.
    segs, rows = 160, 10
    bm = bmesh.new()
    grid = []
    for i in range(segs):
        a = i * math.tau / segs
        deg = math.degrees(a) % 72
        big = max(0.0, 1 - min(deg, 72 - deg) / 18) * 0.078
        small = max(0.0, 1 - abs(deg - 36) / 18) * 0.04
        top = 0.132 + max(big, small)
        col = []
        for j in range(rows + 1):
            z = 0.05 + (top - 0.05) * j / rows
            r = 0.138 + (z - 0.05) * 0.12
            col.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        grid.append(col)
    for i in range(segs):
        for j in range(rows):
            n = (i + 1) % segs
            bm.faces.new((grid[i][j], grid[n][j], grid[n][j + 1], grid[i][j + 1]))
    band = mesh_obj(bm)
    thick = band.modifiers.new("grosor", "SOLIDIFY")
    thick.thickness = 0.01
    thick.offset = 1.0
    bevel = band.modifiers.new("canto", "BEVEL")
    bevel.width = 0.003
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    p.put(smooth(band), "banda", m_gold)

    # Los cordones de los bordes.
    p.put(torus(0.1375, 0.0055, (0, 0, 0.053), segs=64, ring=10), "cordon_bajo", m_gold_dark)
    p.put(torus(0.1475, 0.005, (0, 0, 0.132), segs=64, ring=10), "cordon_alto", m_gold_dark)

    # Las piedras, en su engaste, entre cordón y cordón; perlas en las puntas.
    for k in range(10):
        a = k * math.tau / 10
        out = Vector((math.cos(a), math.sin(a), 0))
        face = (math.pi / 2, 0, a + math.pi / 2)
        z = 0.093
        r = 0.138 + (z - 0.05) * 0.12
        big = k % 2 == 0
        p.put(cylinder(0.024 if big else 0.018, 0.024 if big else 0.018, 0.008, out * (r + 0.004) + Vector((0, 0, z)), face, segs=20),
              f"engaste_{k + 1}", m_gold_dark)
        stone = ico(0.018 if big else 0.013, out * (r + 0.011) + Vector((0, 0, z)), (1, 1, 0.55), face)
        p.put(stone, f"{'rubi' if big else 'zafiro'}_{k // 2 + 1}", m_ruby if big else m_sapphire)
        tip_z = 0.132 + (0.078 if big else 0.04)
        tip_r = 0.138 + (tip_z - 0.05) * 0.12 + 0.005
        p.put(sphere(0.013 if big else 0.009, out * tip_r + Vector((0, 0, tip_z + 0.006)), segs=16, rings=8), f"perla_{k + 1}", m_pearl)
        if big:
            lean = (-math.sin(a) * 0.2, math.cos(a) * 0.2, a)
            pickle(p, f"pepinillo_{k // 2 + 1}", out * (tip_r + 0.006) + Vector((0, 0, tip_z + 0.052)), lean, 1.0, m_green, m_warts, m_stalk)

    # El terciopelo, abombado, y dos arcos de oro con perlas encima.
    velvet = sphere(0.14, (0, 0, 0.12), (1, 1, 0.78), segs=32, rings=16, sub=1)
    p.put(velvet, "terciopelo", m_velvet)
    for i, turn in enumerate((0.0, math.pi / 2)):
        pts = [(math.cos(t) * 0.142, 0.0, 0.132 + math.sin(t) * 0.125) for t in [k * math.pi / 12 for k in range(13)]]
        arch = tube(pts, 0.008)
        arch.rotation_euler = (0, 0, turn)
        p.put(arch, f"arco_{i + 1}", m_gold)
        for k in range(1, 12, 2):
            t = k * math.pi / 12
            at = Matrix.Rotation(turn, 3, "Z") @ Vector((math.cos(t) * 0.142, 0, 0.132 + math.sin(t) * 0.125 + 0.009))
            p.put(sphere(0.0065, at, segs=10, rings=6), f"arco_{i + 1}_perla_{k // 2 + 1}", m_pearl)

    # En lo alto: el orbe con su cinturón, y el pepinillo más grande.
    p.put(sphere(0.027, (0, 0, 0.283), segs=24, rings=12), "orbe", m_gold)
    p.put(torus(0.027, 0.004, (0, 0, 0.283), segs=32, ring=8), "orbe_cinturon", m_gold_dark)
    pickle(p, "pepinillo_rey", (0, 0, 0.352), (0, 0.12, 0), 1.2, m_green, m_warts, m_stalk)
    p.finish()


# --- La bola de chicle ----------------------------------------------------------

def gum():
    """La bola de chicle del récord: cada vecino pegó uno en su cumpleaños.
    Pegotes aplastados fundidos unos con otros (casi todos de fresa, alguno
    de menta o de azul), hilos colgando con su gota, una pompa a medio
    hacer, en una copa de trofeo torneada sobre una peana con placa."""
    p = Piece("chicle")
    pink = "#f783ac"
    m_pink = mat("color", pink, rough=0.8)
    m_dark = mat("color_oscuro_15", shade(pink, dark=0.15), rough=0.8)
    m_light = mat("color_claro_20", shade(pink, light=0.2), rough=0.8)
    m_mint = mat("menta", "#8ce0bd", rough=0.8)
    m_blue = mat("azul", "#a5d8ff", rough=0.8)
    m_bubble = mat("color_claro_25_55", shade(pink, light=0.25), rough=0.1, glow=0.4, alpha=0.55)
    m_shine = mat("brillo", "#ffffff", rough=0.1, glow=1.2)
    m_gold = mat("oro", "#e8b54a", rough=0.28, metal=0.45, glow=0.1)
    m_wood = mat("madera", "#5a3a22", rough=0.6, glow=0.08)
    m_plate = mat("placa", "#f1d489", rough=0.3, metal=0.4, glow=0.3)

    # La peana, la copa torneada y sus dos asas.
    base = cylinder(0.1, 0.088, 0.03, (0, 0, 0.015), segs=40)
    bev = base.modifiers.new("canto", "BEVEL")
    bev.width = 0.004
    bev.segments = 2
    p.put(base, "peana", m_wood)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    plate = mesh_obj(bm)
    plate.location = (0, -0.094, 0.015)
    plate.rotation_euler = (-0.4, 0, 0)
    plate.scale = (0.07, 0.003, 0.018)
    p.put(plate, "placa", m_plate)
    cup = lathe([(0.048, 0.03), (0.048, 0.034), (0.03, 0.04), (0.018, 0.05), (0.016, 0.058), (0.024, 0.064), (0.022, 0.068),
                 (0.03, 0.072), (0.055, 0.08), (0.075, 0.093), (0.086, 0.108), (0.088, 0.114), (0.082, 0.116)], segs=48)
    p.put(cup, "copa", m_gold)
    for side in (-1, 1):
        handle = tube([(side * 0.078, 0, 0.108), (side * 0.108, 0, 0.11), (side * 0.112, 0, 0.085),
                       (side * 0.09, 0, 0.068), (side * 0.06, 0, 0.074)], 0.006)
        p.put(handle, "asa_" + ("dcha" if side > 0 else "izq"), m_gold)

    # La bola: unos 70 pegotes repartidos por la esfera, aplastados contra
    # ella, cada uno en la familia de metaballs de su color.
    c = Vector((0, 0, 0.215))
    rng = random.Random(7)
    families = {"rosa": [(c, 0.16, None, None)], "oscuro": [], "claro": [], "menta": [], "azul": []}
    n = 72
    for k in range(n):
        y = 1 - 2 * (k + 0.5) / n
        a = k * 2.39996
        d = Vector((math.cos(a) * math.sqrt(1 - y * y), math.sin(a) * math.sqrt(1 - y * y), y))
        if d.z < -0.8:
            continue
        rot = d.to_track_quat("Z", "Y") @ Euler((0, 0, rng.random() * math.tau)).to_quaternion()
        size = (rng.uniform(1.0, 1.5), rng.uniform(0.75, 1.0), 0.45)
        fam = rng.choices(["rosa", "oscuro", "claro", "menta", "azul"], [6, 3, 3, 1, 1])[0]
        dist = 0.108 if fam == "rosa" else 0.117
        families[fam].append((c + d * dist, rng.uniform(0.042, 0.056), size, rot))
    for fam, m in (("rosa", m_pink), ("oscuro", m_dark), ("claro", m_light), ("menta", m_mint), ("azul", m_blue)):
        p.put(blob("chicle_" + fam, families[fam], resolution=0.005), "bola_" + fam, m)

    # Hilos de chicle colgando, con su gota.
    for i, (d, h) in enumerate(((Vector((0.8, -0.45, -0.2)), 0.07), (Vector((-0.85, -0.3, -0.1)), 0.05), (Vector((0.15, -0.95, -0.35)), 0.06))):
        top = c + d.normalized() * 0.125
        strand = tube([top, top + Vector((0.004, -0.004, -h * 0.5)), top + Vector((0.0, -0.002, -h))], 0.004, taper_end=0.55)
        p.put(strand, f"hilo_{i + 1}", m_light)
        p.put(sphere(0.0075, top + Vector((0, -0.002, -h - 0.004)), (1, 1, 1.3), segs=12, rings=8), f"gota_{i + 1}", m_light)

    # La pompa, a medio hacer, con su brillo.
    out = Vector((0.75, -0.55, 0.35)).normalized()
    p.put(sphere(0.024, c + out * 0.13, segs=16, rings=8), "pompa_boca", m_dark)
    p.put(sphere(0.066, c + out * 0.195, segs=32, rings=16), "pompa", m_bubble)
    p.put(sphere(0.011, c + out * 0.195 + Vector((-0.022, -0.035, 0.035)), (1, 1, 0.6), segs=12, rings=6), "pompa_brillo", m_shine)
    p.finish()


duck()
crown()
gum()
for m in list(bpy.data.materials):
    if m.users == 0:
        bpy.data.materials.remove(m)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)
catalogo.arrange()
bpy.ops.wm.save_mainfile()
print("[botin] remodelados: pato, corona, chicle")
