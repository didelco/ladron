"""Añade a art/botin.blend las piezas nuevas a robar, las de los trofeos que cuadran
con cada museo (docs/propuesta_trofeos.md): hueso, planta carnívora, caracol,
amatista, ánfora, corona de laurel de neón, columna dórica de plástico, David con
delantal, Venus con gafas de sol, espada en la piedra, ornitóptero de Leonardo,
plátano con cinta y cubo de fregona.

Están hechas con primitivas low-poly, cada parte un objeto con nombre. Si una pieza
ya existe en el fichero se rehace (pisa los retoques hechos a mano en ella).

    Blender -b art/botin.blend -P art/botin/nuevas.py            # todas
    Blender -b art/botin.blend -P art/botin/nuevas.py -- hueso   # solo esa
    Blender -b art/botin.blend -P art/botin/nuevas.py -- --save  # y guarda el .blend

Luego se exporta con  Blender -b -P art/export.py -- botin  (a assets/models/botin/).
Los materiales "color", "color_claro_N" y "color_oscuro_N" toman en el juego el color
de la ficha (LootModels); los demás son fijos. Medidas: unos 0,35 de ancho, el pie en
z = 0 y el frente mirando a -Y.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(ART)
import catalogo  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


# --- Ayudas ---------------------------------------------------------------------

def linear(hex_):
    c = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


class Piece:
    """Una pieza: su colección, sus materiales y sus partes."""

    def __init__(self, name, form):
        old = bpy.data.collections.get(name)
        if old is not None:
            for o in list(old.all_objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(old)
        self.name = name
        self.coll = catalogo.add_piece(name)
        self.coll["sitio"] = "botin"
        self.coll["forma"] = form
        self.mats = {}
        self.n = 0

    def mat(self, key, hex_, rough=0.5, metal=0.0, glow=0.12):
        """Un material; key "color..." sigue el color de la ficha."""
        if key not in self.mats:
            m = bpy.data.materials.new(key)
            b = m.node_tree.nodes["Principled BSDF"]
            rgb = linear(hex_)
            b.inputs["Base Color"].default_value = rgb
            b.inputs["Roughness"].default_value = rough
            b.inputs["Metallic"].default_value = metal
            b.inputs["Emission Color"].default_value = rgb
            b.inputs["Emission Strength"].default_value = glow
            m.diffuse_color = rgb
            self.mats[key] = m
        return self.mats[key]

    def put(self, obj, part, mat, smooth=True):
        self.n += 1
        obj.name = f"{self.name}_{part}"
        obj.data.name = obj.name
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        self.coll.objects.link(obj)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        for p in obj.data.polygons:
            p.use_smooth = smooth
        return obj


def _obj(bm, at, rot, scale):
    me = bpy.data.meshes.new("m")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("o", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = at
    o.rotation_euler = rot
    o.scale = scale
    return o


def sphere(p, part, mat, r, at, scale=(1, 1, 1), rot=(0, 0, 0), segs=20, rings=10, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return p.put(_obj(bm, at, rot, scale), part, mat, smooth)


def rock(p, part, mat, r, at, scale=(1, 1, 1), rot=(0, 0, 0)):
    """Una piedra: pocas caras, planas."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    return p.put(_obj(bm, at, rot, scale), part, mat, False)


def cyl(p, part, mat, r1, r2, h, at, rot=(0, 0, 0), scale=(1, 1, 1), segs=20, smooth=True):
    """Cilindro o tronco de cono (r1 abajo, r2 arriba), centrado en at."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=h)
    return p.put(_obj(bm, at, rot, scale), part, mat, smooth)


def box(p, part, mat, size, at, rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    o = _obj(bm, at, rot, (1, 1, 1))
    p.put(o, part, mat, False)
    if bevel:
        m = o.modifiers.new("biselado", "BEVEL")
        m.width = bevel
        m.segments = 2
    return o


def torus(p, part, mat, major, minor, at, rot=(0, 0, 0), scale=(1, 1, 1), segs=32, ring=8):
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
    return p.put(_obj(bm, at, rot, scale), part, mat)


def lathe(p, part, mat, profile, at=(0, 0, 0), segs=28, smooth=True):
    """Sólido de revolución alrededor de Z: profile es [(radio, z), ...] de abajo arriba."""
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
            bm.faces.new(list(reversed(ring)) if flip else ring)
    return p.put(_obj(bm, at, (0, 0, 0), (1, 1, 1)), part, mat, smooth)


def between(p, part, mat, a, b, r, segs=10, r2=None):
    """Un palo redondo entre dos puntos."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cyl(p, part, mat, r, r if r2 is None else r2, d.length, (a + b) / 2, rot, segs=segs)


# --- Las piezas -------------------------------------------------------------------

def hueso():
    """El hueso del perro Bruto: gordo, roído, sobre una losa."""
    p = Piece("hueso", "bone")
    hueso_ = p.mat("color", "#e9e2cf", 0.8)
    claro = p.mat("color_claro_12", "#e9e2cf", 0.8)
    roido = p.mat("roido", "#6b5034", 0.9, glow=0.0)
    losa = p.mat("losa", "#8c8577", 0.95, glow=0.04)
    tierra = p.mat("tierra", "#5a4630", 0.95, glow=0.0)
    cyl(p, "losa", losa, 0.19, 0.17, 0.035, (0, 0, 0.0175), segs=12, smooth=False)
    turn = math.radians(-18)
    z = 0.105

    def pt(x, y, zz):
        return (x * math.cos(turn) - y * math.sin(turn), x * math.sin(turn) + y * math.cos(turn), zz)
    between(p, "caña", hueso_, pt(-0.13, 0, z), pt(0.13, 0, z), 0.034)
    for sx in (-1, 1):
        for sy in (-1, 1):
            sphere(p, f"nudo_{sx}{sy}", claro, 0.05, pt(sx * 0.16, sy * 0.036, z), segs=16, rings=8)
    # Los mordiscos de Bruto en una punta y unas migas de tierra.
    for k, (x, y, s) in enumerate([(0.185, -0.03, 0.02), (0.2, 0.0, 0.022), (0.185, 0.03, 0.02)]):
        sphere(p, f"mordisco_{k}", roido, s, pt(x, y, z + 0.005), segs=8, rings=6)
    for k, (x, y) in enumerate([(-0.07, -0.1), (0.09, 0.09), (-0.12, 0.08)]):
        rock(p, f"terron_{k}", tierra, 0.02, pt(x, y, 0.045), scale=(1, 1, 0.6))
    return p


def planta():
    """La planta carnívora Filomena: dos mandíbulas con dientes y cara de hambre."""
    p = Piece("planta", "plant")
    verde = p.mat("color", "#7bc043", 0.6)
    verde_osc = p.mat("color_oscuro_25", "#7bc043", 0.6)
    verde_cla = p.mat("color_claro_20", "#7bc043", 0.6)
    barro = p.mat("maceta", "#c8663a", 0.7, glow=0.08)
    borde = p.mat("maceta_borde", "#d9794a", 0.7, glow=0.08)
    tierra = p.mat("tierra", "#3b2a1c", 0.95, glow=0.0)
    rojo = p.mat("boca", "#e03131", 0.5)
    diente = p.mat("diente", "#f8f4e8", 0.5)
    ojo = p.mat("ojo", "#ffffff", 0.3)
    negro = p.mat("negro", "#111111", 0.4, glow=0.0)
    cyl(p, "maceta", barro, 0.075, 0.115, 0.13, (0, 0, 0.065))
    cyl(p, "maceta_borde", borde, 0.125, 0.125, 0.03, (0, 0, 0.145))
    cyl(p, "tierra", tierra, 0.105, 0.105, 0.01, (0, 0, 0.155))
    between(p, "tallo", verde_osc, (0, 0.02, 0.15), (0, 0.045, 0.25), 0.02)
    # Hojas de abajo, abiertas como brazos.
    for k, s in enumerate((-1, 1)):
        sphere(p, f"hoja_{k}", verde_cla, 0.06, (s * 0.1, 0.0, 0.2), scale=(1.6, 0.35, 0.5), rot=(0, s * 0.5, 0))
    # Las mandíbulas, abiertas hacia el frente (-Y) con la bisagra atrás, arriba del tallo.
    from mathutils import Euler, Matrix
    hinge = Vector((0, 0.05, 0.27))
    for name, ang in (("sup", math.radians(-42)), ("inf", math.radians(42))):
        m = Matrix.Rotation(ang, 4, "X")
        # (x, y, z) del lóbulo -> mundo: la bisagra es el borde de atrás del lóbulo.
        def w(x, y, z, m=m):
            return hinge + (m @ Vector((x, y, z)))
        sphere(p, "mandibula_" + name, verde, 0.085, w(0, -0.085, 0), scale=(0.9, 1.0, 0.26), rot=m.to_euler(), segs=24, rings=10)
        # La boca por dentro, roja, y una tira de dientes en el borde.
        z_in = -0.012 if name == "sup" else 0.012
        sphere(p, "boca_" + name, rojo, 0.075, w(0, -0.085, z_in), scale=(0.82, 0.9, 0.12), rot=m.to_euler(), segs=20, rings=8)
        flip = Matrix.Rotation(math.pi, 4, "X") if name == "sup" else Matrix.Identity(4)
        for i in range(7):
            x = -0.06 + i * 0.02
            y = -0.085 - 0.082 * math.sqrt(max(0.0, 1 - (x / 0.077) ** 2))
            cyl(p, f"diente_{name}_{i}", diente, 0.011, 0.0, 0.045, w(x, y, z_in * 2.0) , (m @ flip).to_euler(), segs=6)
    # Ojos saltones sobre la mandíbula de arriba.
    m = Matrix.Rotation(math.radians(-42), 4, "X")
    for k, s in enumerate((-1, 1)):
        base = hinge + m @ Vector((s * 0.035, -0.06, 0.035))
        sphere(p, f"ojo_{k}", ojo, 0.026, base, segs=14, rings=8)
        sphere(p, f"pupila_{k}", negro, 0.012, base + Vector((0, -0.02, 0.006)), segs=10, rings=6)
    return p


def caracol():
    """El caracol Anselmo: concha en espiral, cuerpo baboso y ojos en tallos."""
    p = Piece("caracol", "snail")
    concha = p.mat("color", "#e07a5f", 0.5)
    concha_osc = p.mat("color_oscuro_18", "#e07a5f", 0.5)
    concha_cla = p.mat("color_claro_22", "#e07a5f", 0.5)
    cuerpo = p.mat("cuerpo", "#c9b79c", 0.35, glow=0.1)
    cuerpo_osc = p.mat("cuerpo_oscuro", "#a99878", 0.4, glow=0.08)
    ojo = p.mat("ojo", "#ffffff", 0.3)
    negro = p.mat("negro", "#111111", 0.4, glow=0.0)
    # El cuerpo tumbado a lo largo de Y, la cabeza al frente (-Y).
    sphere(p, "cuerpo", cuerpo, 0.06, (0, 0.01, 0.045), scale=(0.75, 2.6, 0.75), segs=24, rings=12)
    sphere(p, "pie", cuerpo_osc, 0.06, (0, 0.01, 0.012), scale=(0.95, 2.7, 0.22), segs=24, rings=8)
    sphere(p, "cabeza", cuerpo, 0.055, (0, -0.15, 0.09), scale=(0.85, 1.0, 1.0))
    sphere(p, "cola", cuerpo, 0.045, (0, 0.17, 0.03), scale=(0.75, 1.4, 0.55))
    for k, s in enumerate((-1, 1)):
        between(p, f"tallo_{k}", cuerpo, (s * 0.02, -0.16, 0.12), (s * 0.04, -0.19, 0.22), 0.009)
        sphere(p, f"ojo_{k}", ojo, 0.017, (s * 0.04, -0.19, 0.23), segs=12, rings=8)
        sphere(p, f"pupila_{k}", negro, 0.008, (s * 0.043, -0.205, 0.232), segs=8, rings=6)
    # La concha: un caracol visto de lado, con su espiral.
    rot = (0, math.pi / 2, 0)
    torus(p, "concha_1", concha, 0.075, 0.048, (0, 0.05, 0.16), rot, segs=28, ring=12)
    torus(p, "concha_2", concha_osc, 0.038, 0.036, (0, 0.05, 0.16), rot, segs=24, ring=10)
    sphere(p, "concha_centro", concha_cla, 0.028, (0, 0.05, 0.16), scale=(1.15, 1, 1), segs=14, rings=8)
    return p


def amatista():
    """La amatista gigante de la abuela Lola: puntas de cristal saliendo de una roca."""
    p = Piece("amatista", "crystal")
    cristal = p.mat("color", "#9b5de5", 0.25, glow=0.25)
    punta = p.mat("color_claro_28", "#9b5de5", 0.2, glow=0.3)
    roca = p.mat("roca", "#6d6a75", 0.9, glow=0.04)
    roca_cla = p.mat("roca_clara", "#8d8a96", 0.9, glow=0.04)
    rock(p, "roca", roca, 0.13, (0, 0, 0.075), scale=(1.25, 1.0, 0.55))
    rock(p, "roca_2", roca_cla, 0.08, (0.11, -0.06, 0.05), scale=(1.0, 0.9, 0.5), rot=(0, 0, 0.7))
    # (x, y, alto, radio, inclinación x, inclinación y)
    for k, (x, y, h, r, tx, ty) in enumerate([
            (0.0, -0.02, 0.24, 0.045, 0.0, 0.0), (-0.07, 0.03, 0.19, 0.038, 0.18, -0.3), (0.075, 0.02, 0.2, 0.04, -0.12, 0.3),
            (-0.03, -0.07, 0.14, 0.032, -0.5, -0.12), (0.05, -0.07, 0.12, 0.03, -0.55, 0.2), (-0.12, -0.02, 0.1, 0.028, 0.0, -0.75),
            (0.13, -0.01, 0.1, 0.026, 0.1, 0.8)]):
        base = Vector((x, y, 0.07))
        rot = (tx, ty, 0.3 * k)
        up = Vector((0, 0, 1))
        from mathutils import Euler
        axis = Euler(rot).to_matrix() @ up
        cyl(p, f"cristal_{k}", cristal, r, r, h, base + axis * (h / 2), rot, segs=6, smooth=False)
        cyl(p, f"punta_{k}", punta, r, 0.004, r * 1.5, base + axis * (h + r * 0.75), rot, segs=6, smooth=False)
    return p


def anfora():
    """El ánfora «Recuerdo de Atenas»: barro, banda negra y un imán de nevera."""
    p = Piece("anfora_souvenir", "amphora")
    barro = p.mat("color", "#d9743c", 0.55)
    barro_osc = p.mat("color_oscuro_20", "#d9743c", 0.55)
    negro = p.mat("pintura", "#2a1a12", 0.6, glow=0.05)
    iman = p.mat("iman_azul", "#2f6fdb", 0.4)
    iman_b = p.mat("iman_blanco", "#f8f4e8", 0.4)
    lathe(p, "cuerpo", barro, [(0.001, 0.0), (0.05, 0.0), (0.055, 0.02), (0.09, 0.07), (0.125, 0.15), (0.13, 0.22), (0.11, 0.29),
                               (0.075, 0.34), (0.055, 0.375), (0.052, 0.42), (0.07, 0.435), (0.07, 0.44), (0.05, 0.435), (0.001, 0.43)])
    lathe(p, "banda_baja", negro, [(0.1, 0.11), (0.1355, 0.11), (0.137, 0.135), (0.1, 0.135)], segs=28)
    lathe(p, "banda_alta", negro, [(0.13, 0.215), (0.1345, 0.215), (0.1345, 0.245), (0.12, 0.245)], segs=28)
    # Dibujo griego de andar por casa: una fila de triángulos y una cara.
    for k in range(12):
        a = k * math.tau / 12 + 0.26
        if abs(math.sin(a) + 1.0) < 0.9:   # el frente (-Y) queda para el imán
            continue
        cyl(p, f"tri_{k}", negro, 0.012, 0.0, 0.03, (0.132 * math.cos(a), 0.132 * math.sin(a), 0.18), (0, math.pi / 2, a), segs=4, smooth=False)
    for k, s in enumerate((-1, 1)):
        torus(p, f"asa_{k}", barro_osc, 0.05, 0.013, (s * 0.09, 0.0, 0.365), (math.pi / 2, 0, 0), scale=(1, 1.2, 1), segs=20, ring=8)
    # El imán de nevera: una banderita azul y blanca, pegada delante.
    box(p, "iman", iman, (0.07, 0.008, 0.045), (0, -0.131, 0.19), bevel=0.003)
    box(p, "iman_franja", iman_b, (0.07, 0.009, 0.012), (0, -0.1315, 0.19))
    return p


def laurel():
    """La corona de laurel de neón de César: hojas brillantes en un aro, sobre su enchufe."""
    p = Piece("laurel", "laurel")
    neon = p.mat("color", "#2ec4b6", 0.3, glow=1.4)
    neon_osc = p.mat("color_oscuro_25", "#2ec4b6", 0.3, glow=1.2)
    tubo = p.mat("soporte", "#3a3d45", 0.5, glow=0.05)
    cable = p.mat("cable", "#111111", 0.6, glow=0.0)
    cy = 0.25
    R = 0.135
    torus(p, "aro", tubo, R, 0.007, (0, 0, cy), (math.pi / 2, 0, 0), segs=40, ring=6)
    n = 11
    for i in range(n):
        th = math.radians(-58 + 296 * i / (n - 1))
        c = Vector((R * math.cos(th), 0, cy + R * math.sin(th)))
        phi0 = -(th + math.pi / 2)
        for side, turn in ((0, -0.62), (1, 0.62)):
            phi = phi0 + turn
            d = Vector((math.cos(phi), 0, -math.sin(phi)))
            sphere(p, f"hoja_{i}_{side}", neon if side == 0 else neon_osc, 0.034,
                   c + d * 0.032 + Vector((0, (-0.006 if side == 0 else 0.006), 0)), scale=(1.15, 0.3, 0.5), rot=(0, phi, 0), segs=12, rings=6)
    # El lacito de arriba... que es un nudo de cinta.
    sphere(p, "nudo", tubo, 0.018, (0, 0, cy - R + 0.0), segs=10, rings=6)
    # Peana negra con su enchufe.
    cyl(p, "base", tubo, 0.09, 0.1, 0.03, (0, 0, 0.015), segs=16)
    cyl(p, "pie", tubo, 0.018, 0.018, 0.09, (0, 0, 0.075), segs=10)
    box(p, "caja", cable, (0.06, 0.04, 0.03), (0, 0.0, 0.035), bevel=0.004)
    return p


def columna():
    """La columna dórica de plástico de los Pérez: hinchable, con costuras y válvula."""
    p = Piece("columna", "column")
    plastico = p.mat("color", "#f4f1e6", 0.35, glow=0.14)
    costura = p.mat("color_oscuro_12", "#f4f1e6", 0.35, glow=0.1)
    valvula = p.mat("valvula", "#f06595", 0.4)
    cinta = p.mat("etiqueta", "#4dabf7", 0.4)
    cyl(p, "plinto", plastico, 0.105, 0.11, 0.03, (0, 0, 0.015), segs=4, smooth=False).rotation_euler = (0, 0, math.pi / 4)
    cyl(p, "base", plastico, 0.075, 0.062, 0.03, (0, 0, 0.045))
    cyl(p, "fuste", plastico, 0.062, 0.05, 0.25, (0, 0, 0.185), segs=24)
    # Las costuras del hinchable, y las estrías como cordones.
    for k, z in enumerate((0.09, 0.15, 0.22, 0.29)):
        torus(p, f"costura_{k}", costura, 0.057 - (z - 0.09) * 0.03, 0.007, (0, 0, z), segs=24, ring=6)
    for k in range(10):
        a = k * math.tau / 10
        between(p, f"estria_{k}", costura, (0.058 * math.cos(a), 0.058 * math.sin(a), 0.07), (0.048 * math.cos(a), 0.048 * math.sin(a), 0.3), 0.006, segs=6)
    cyl(p, "equino", plastico, 0.05, 0.078, 0.035, (0, 0, 0.3225))
    cyl(p, "abaco", plastico, 0.1, 0.1, 0.028, (0, 0, 0.354), segs=4, smooth=False).rotation_euler = (0, 0, math.pi / 4)
    # La válvula de aire, rosa, y una pegatina.
    cyl(p, "valvula", valvula, 0.014, 0.014, 0.035, (0.06, -0.05, 0.12), (math.radians(-60), math.radians(-40), 0), segs=10)
    cyl(p, "valvula_tapon", valvula, 0.02, 0.02, 0.012, (0.085, -0.075, 0.12), (math.radians(-60), math.radians(-40), 0), segs=10)
    box(p, "etiqueta", cinta, (0.05, 0.004, 0.03), (-0.0, -0.0585, 0.16))
    return p


def david():
    """El David con delantal del carnicero: mármol, rizos, tirachinas al hombro."""
    p = Piece("david", "david")
    marmol = p.mat("color", "#f4f1e6", 0.4, glow=0.14)
    marmol_osc = p.mat("color_oscuro_14", "#f4f1e6", 0.4, glow=0.12)
    pelo = p.mat("color_oscuro_28", "#f4f1e6", 0.4, glow=0.1)
    delantal = p.mat("delantal", "#d6453d", 0.7)
    blanco = p.mat("delantal_cuadro", "#f8f4e8", 0.7)
    cuerda = p.mat("cuerda", "#8a6a3d", 0.8, glow=0.05)
    salchicha = p.mat("salchicha", "#e58a7b", 0.5)
    cyl(p, "peana", marmol_osc, 0.1, 0.11, 0.035, (0, 0, 0.0175), segs=4, smooth=False).rotation_euler = (0, 0, math.pi / 4)
    z0 = 0.035
    # Las piernas (una adelantada) y el torso.
    between(p, "pierna_dcha", marmol, (-0.03, 0.0, z0), (-0.035, 0.0, z0 + 0.18), 0.026, r2=0.022)
    between(p, "pierna_izq", marmol, (0.04, -0.01, z0 + 0.0), (0.03, 0.0, z0 + 0.18), 0.024, r2=0.022)
    cyl(p, "caderas", marmol, 0.055, 0.05, 0.05, (0, 0, z0 + 0.195), scale=(1.0, 0.7, 1.0))
    cyl(p, "torso", marmol, 0.05, 0.062, 0.14, (0, 0, z0 + 0.29), scale=(1.0, 0.7, 1.0))
    sphere(p, "hombros", marmol, 0.062, (0, 0, z0 + 0.345), scale=(1.15, 0.7, 0.6))
    cyl(p, "cuello", marmol, 0.02, 0.02, 0.03, (0, 0, z0 + 0.375), segs=12)
    sphere(p, "cabeza", marmol, 0.04, (0, -0.002, z0 + 0.415), scale=(0.9, 1.0, 1.05))
    for k, (x, y, z) in enumerate([(-0.028, 0, 0.44), (0.0, 0.006, 0.452), (0.028, 0, 0.44), (-0.035, 0.012, 0.42), (0.035, 0.012, 0.42),
                                    (-0.015, -0.012, 0.455), (0.015, -0.012, 0.455)]):
        sphere(p, f"rizo_{k}", pelo, 0.018, (x, y, z0 + (z - 0.035)), segs=8, rings=6)
    # Los brazos: uno baja con una ristra de salchichas, otro sube al hombro con el tirachinas.
    between(p, "brazo_dcho", marmol, (-0.066, 0.0, z0 + 0.34), (-0.085, -0.02, z0 + 0.22), 0.018, r2=0.015)
    between(p, "brazo_izq_1", marmol, (0.066, 0.0, z0 + 0.34), (0.095, -0.03, z0 + 0.29), 0.018, r2=0.015)
    between(p, "brazo_izq_2", marmol, (0.095, -0.03, z0 + 0.29), (0.05, -0.05, z0 + 0.36), 0.015, r2=0.014)
    between(p, "tirachinas", cuerda, (0.05, -0.05, z0 + 0.36), (0.03, 0.02, z0 + 0.385), 0.005, segs=6)
    for k in range(3):
        sphere(p, f"salchicha_{k}", salchicha, 0.016, (-0.087, -0.03, z0 + 0.2 - k * 0.028), scale=(0.9, 0.9, 1.5), segs=10, rings=6)
    between(p, "ristra", cuerda, (-0.085, -0.02, z0 + 0.22), (-0.087, -0.03, z0 + 0.13), 0.003, segs=6)
    # El delantal a cuadros, con su correa al cuello y un bolsillo.
    box(p, "delantal", delantal, (0.1, 0.012, 0.19), (0, -0.038, z0 + 0.25), bevel=0.003)
    box(p, "delantal_pecho", delantal, (0.06, 0.012, 0.06), (0, -0.036, z0 + 0.35), bevel=0.003)
    for k in range(3):
        box(p, f"cuadro_{k}", blanco, (0.1, 0.0125, 0.016), (0, -0.0385, z0 + 0.19 + k * 0.05))
    box(p, "bolsillo", blanco, (0.05, 0.014, 0.035), (0, -0.04, z0 + 0.23))
    between(p, "correa_1", delantal, (-0.028, -0.034, z0 + 0.375), (-0.02, -0.02, z0 + 0.4), 0.005, segs=6)
    between(p, "correa_2", delantal, (0.028, -0.034, z0 + 0.375), (0.02, -0.02, z0 + 0.4), 0.005, segs=6)
    return p


def venus():
    """La Venus con gafas de sol de la peluquería: sin brazos, con mucho estilo."""
    p = Piece("venus", "venus")
    marmol = p.mat("color", "#f4f1e6", 0.4, glow=0.14)
    tela = p.mat("color_oscuro_10", "#f4f1e6", 0.4, glow=0.12)
    pelo = p.mat("color_oscuro_25", "#f4f1e6", 0.45, glow=0.1)
    lente = p.mat("gafas", "#0b0b10", 0.15, metal=0.4, glow=0.05)
    montura = p.mat("montura", "#f06595", 0.35, glow=0.3)
    labio = p.mat("labios", "#e0546c", 0.5)
    flor = p.mat("flor", "#ffd43b", 0.5, glow=0.25)
    cyl(p, "peana", tela, 0.1, 0.11, 0.035, (0, 0, 0.0175), segs=4, smooth=False).rotation_euler = (0, 0, math.pi / 4)
    z0 = 0.035
    # La falda: el paño cayendo, con sus pliegues.
    lathe(p, "falda", tela, [(0.001, z0), (0.085, z0), (0.078, z0 + 0.06), (0.066, z0 + 0.14), (0.058, z0 + 0.2), (0.001, z0 + 0.2)])
    for k in range(7):
        a = math.radians(-160 + 320 * k / 6)
        between(p, f"pliegue_{k}", marmol, (0.084 * math.sin(a), -0.084 * math.cos(a), z0 + 0.01),
                (0.06 * math.sin(a), -0.06 * math.cos(a), z0 + 0.19), 0.008, segs=6)
    torus(p, "cinturon", marmol, 0.06, 0.012, (0, 0, z0 + 0.2), segs=24, ring=8, scale=(1, 0.85, 1))
    cyl(p, "torso", marmol, 0.058, 0.066, 0.13, (0, 0, z0 + 0.27), scale=(1.0, 0.75, 1.0))
    sphere(p, "pecho_izq", marmol, 0.035, (0.026, -0.03, z0 + 0.3), scale=(1.0, 0.8, 1.0), segs=14, rings=8)
    sphere(p, "pecho_dcho", marmol, 0.035, (-0.026, -0.03, z0 + 0.3), scale=(1.0, 0.8, 1.0), segs=14, rings=8)
    sphere(p, "hombros", marmol, 0.068, (0, 0, z0 + 0.335), scale=(1.15, 0.7, 0.55))
    # Los brazos, rotos como en la de verdad: dos muñones.
    cyl(p, "munon_izq", marmol, 0.02, 0.023, 0.05, (0.078, 0.0, z0 + 0.31), (0, math.radians(-14), 0), segs=12)
    cyl(p, "munon_dcho", marmol, 0.02, 0.023, 0.05, (-0.078, 0.0, z0 + 0.31), (0, math.radians(14), 0), segs=12)
    cyl(p, "cuello", marmol, 0.02, 0.022, 0.04, (0, 0, z0 + 0.365), segs=12)
    sphere(p, "cabeza", marmol, 0.04, (0, 0, z0 + 0.41), scale=(0.9, 0.95, 1.1))
    sphere(p, "pelo", pelo, 0.043, (0, 0.012, z0 + 0.418), scale=(0.98, 0.9, 1.0))
    sphere(p, "mono", pelo, 0.022, (0, 0.03, z0 + 0.455), segs=12, rings=8)
    sphere(p, "flor", flor, 0.011, (0.035, 0.0, z0 + 0.44), segs=8, rings=6)
    # Las gafas: dos lentes grandes, puente y patillas.
    for k, s in enumerate((-1, 1)):
        sphere(p, f"lente_{k}", lente, 0.019, (s * 0.02, -0.036, z0 + 0.415), scale=(1.15, 0.35, 0.95), segs=14, rings=8)
        torus(p, f"montura_{k}", montura, 0.019, 0.0035, (s * 0.02, -0.0385, z0 + 0.415), (math.pi / 2, 0, 0), scale=(1.15, 1.0, 0.95), segs=16, ring=6)
        between(p, f"patilla_{k}", montura, (s * 0.039, -0.034, z0 + 0.415), (s * 0.042, 0.0, z0 + 0.418), 0.0032, segs=6)
    box(p, "puente", montura, (0.012, 0.006, 0.006), (0, -0.039, z0 + 0.418))
    sphere(p, "labios", labio, 0.008, (0, -0.037, z0 + 0.383), scale=(1.6, 0.6, 0.7), segs=8, rings=6)
    return p


def espada():
    """La espada en la piedra: la piedra del parque y una hoja que nadie saca."""
    p = Piece("espada", "sword")
    piedra = p.mat("color", "#adb5bd", 0.9, glow=0.06)
    piedra_osc = p.mat("color_oscuro_18", "#adb5bd", 0.9, glow=0.05)
    acero = p.mat("acero", "#d5dde3", 0.25, metal=0.8, glow=0.1)
    oro = p.mat("oro", "#e8b54a", 0.3, metal=0.7, glow=0.15)
    cuero = p.mat("cuero", "#5b3a22", 0.8, glow=0.05)
    musgo = p.mat("musgo", "#5f9f3d", 0.9, glow=0.05)
    rubi = p.mat("rubi", "#e03131", 0.2, glow=0.4)
    rock(p, "piedra", piedra, 0.14, (0, 0, 0.1), scale=(1.15, 0.95, 0.72))
    rock(p, "piedra_2", piedra_osc, 0.09, (0.09, -0.05, 0.06), scale=(1.0, 0.9, 0.8), rot=(0, 0, 0.6))
    rock(p, "piedra_3", piedra_osc, 0.075, (-0.1, 0.03, 0.055), scale=(1.0, 1.0, 0.75), rot=(0, 0, 1.2))
    sphere(p, "musgo_1", musgo, 0.04, (-0.07, -0.07, 0.11), scale=(1.4, 1.0, 0.35), segs=10, rings=6)
    sphere(p, "musgo_2", musgo, 0.03, (0.1, 0.02, 0.135), scale=(1.2, 1.0, 0.3), segs=10, rings=6)
    top = 0.18
    box(p, "hoja", acero, (0.042, 0.009, 0.14), (0, 0, top + 0.06), bevel=0.002)
    box(p, "guarda", oro, (0.125, 0.02, 0.02), (0, 0, top + 0.13), bevel=0.004)
    sphere(p, "guarda_izq", oro, 0.012, (-0.058, 0, top + 0.13), segs=10, rings=6)
    sphere(p, "guarda_dcha", oro, 0.012, (0.058, 0, top + 0.13), segs=10, rings=6)
    cyl(p, "empunadura", cuero, 0.011, 0.011, 0.075, (0, 0, top + 0.1775), segs=10)
    for k in range(3):
        torus(p, f"cinta_{k}", oro, 0.0115, 0.0025, (0, 0, top + 0.155 + k * 0.022), segs=12, ring=5)
    sphere(p, "pomo", oro, 0.02, (0, 0, top + 0.225), segs=14, rings=8)
    sphere(p, "rubi", rubi, 0.01, (0, -0.017, top + 0.225), segs=8, rings=6)
    return p


def ornitoptero():
    """El ornitóptero de Leonardo: alas de tela con costillas, pedales y un piloto."""
    p = Piece("ornitoptero", "ornithopter")
    tela = p.mat("color", "#e9d8a6", 0.8, glow=0.12)
    tela_osc = p.mat("color_oscuro_16", "#e9d8a6", 0.8, glow=0.1)
    madera = p.mat("madera", "#9a6b3c", 0.75, glow=0.06)
    madera_osc = p.mat("madera_oscura", "#6e4a28", 0.8, glow=0.05)
    cuerda = p.mat("cuerda", "#cdbd94", 0.9, glow=0.05)
    piel = p.mat("piel", "#f0c6a0", 0.6)
    gorro = p.mat("gorro", "#c92a2a", 0.7)
    latón = p.mat("laton", "#d9a441", 0.35, metal=0.6, glow=0.1)
    # El casco: una barca larga sobre patines (proa al frente, -Y).
    sphere(p, "casco", madera, 0.07, (0, 0, 0.115), scale=(0.8, 2.1, 0.7), segs=24, rings=10)
    sphere(p, "asiento", madera_osc, 0.03, (0, 0.02, 0.15), scale=(1.1, 1.0, 0.4), segs=12, rings=6)
    between(p, "patin_izq", madera_osc, (0.05, -0.17, 0.02), (0.05, 0.16, 0.02), 0.012, segs=8)
    between(p, "patin_dcho", madera_osc, (-0.05, -0.17, 0.02), (-0.05, 0.16, 0.02), 0.012, segs=8)
    for s in (-1, 1):
        for y in (-0.09, 0.1):
            between(p, f"pata_{s}_{y}", madera_osc, (s * 0.05, y, 0.02), (s * 0.03, y, 0.1), 0.008, segs=6)
    # El piloto, con su gorro, y los pedales con su engranaje de latón.
    cyl(p, "piloto", piel, 0.022, 0.025, 0.06, (0, 0.02, 0.19), segs=12)
    sphere(p, "cabeza", piel, 0.026, (0, 0.015, 0.245), segs=14, rings=8)
    cyl(p, "gorro", gorro, 0.03, 0.016, 0.026, (0, 0.015, 0.275), segs=12)
    torus(p, "engranaje", latón, 0.03, 0.007, (0, -0.06, 0.13), (0, math.pi / 2, 0), segs=16, ring=6)
    sphere(p, "engranaje_eje", latón, 0.012, (0, -0.06, 0.13), segs=8, rings=6)
    # Las alas, levantadas en V: larguero, costillas y tela.
    for s in (-1, 1):
        root = Vector((s * 0.05, 0.0, 0.15))
        tip = Vector((s * 0.245, -0.03, 0.29))
        between(p, f"larguero_{s}", madera, root, tip, 0.009, segs=8)
        between(p, f"larguero_atras_{s}", madera, root + Vector((0, 0.12, 0)), tip + Vector((0, 0.16, 0)), 0.006, segs=8)
        for k in range(5):
            t = (k + 0.5) / 5
            a = root.lerp(tip, t)
            between(p, f"costilla_{s}_{k}", madera_osc, a, a + Vector((0, 0.13 + 0.03 * t, 0)), 0.004, segs=6)
        # La tela: una lámina inclinada entre los dos largueros.
        mid = (root + tip) / 2 + Vector((0, 0.07, 0))
        d = tip - root
        ang = math.atan2(d.z, abs(d.x))
        sheet = box(p, f"tela_{s}", tela, (d.xy.length, 0.15, 0.006), mid, (0, -s * ang, 0))
        sheet.rotation_euler = (0, -s * ang, 0)
        between(p, f"cuerda_{s}", cuerda, root + Vector((0, 0.03, 0.02)), Vector((s * 0.02, 0.0, 0.2)), 0.002, segs=4)
    return p


def platano():
    """El plátano pegado con cinta: un panel blanco de galería y un plátano con su cinta gris."""
    p = Piece("platano", "banana")
    amarillo = p.mat("color", "#ffd43b", 0.55, glow=0.15)
    amarillo_osc = p.mat("color_oscuro_14", "#ffd43b", 0.55, glow=0.12)
    mancha = p.mat("mancha", "#6b4a1e", 0.8, glow=0.0)
    verde = p.mat("rabito", "#6b8a3a", 0.7, glow=0.05)
    cinta = p.mat("cinta", "#b8bec4", 0.25, metal=0.7, glow=0.12)
    panel = p.mat("panel", "#f3f1ec", 0.8, glow=0.16)
    marco = p.mat("marco", "#2b2b30", 0.6, glow=0.04)
    box(p, "panel", panel, (0.36, 0.022, 0.3), (0, 0.08, 0.2), bevel=0.003)
    box(p, "panel_marco", marco, (0.372, 0.018, 0.312), (0, 0.089, 0.2))
    box(p, "pie_panel", marco, (0.2, 0.09, 0.02), (0, 0.06, 0.01))
    # El plátano: una media luna de esferas alargadas, de punta a rabito, pegado al panel.
    n = 11
    R = 0.2
    y0 = 0.037

    def curve(a):
        return R * math.sin(a), 0.28 - R * (1 - math.cos(a)) * 0.9 - 0.02
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-58 + 116 * t)
        x, z = curve(a)
        # Radio: más gordo en el medio.
        r = 0.032 * (0.55 + 0.45 * math.sin(math.pi * t) ** 0.5)
        mat = amarillo if i % 2 == 0 else amarillo_osc
        sphere(p, f"gajo_{i}", mat, r, (x, y0, z), scale=(1.6, 1.0, 1.0), rot=(0, -a * 0.9, 0), segs=14, rings=8)
    # El rabito verde y la punta oscura.
    x, z = curve(math.radians(-58))
    between(p, "rabito", verde, (x - 0.012, y0, z + 0.002), (x - 0.055, y0, z + 0.04), 0.011, segs=8)
    x, z = curve(math.radians(58))
    sphere(p, "punta", mancha, 0.011, (x + 0.03, y0, z + 0.014), segs=8, rings=6)
    for k, ang in enumerate((-30, 10, 42)):
        x, z = curve(math.radians(ang))
        sphere(p, f"pinta_{k}", mancha, 0.007, (x + 0.01, y0 - 0.03, z + 0.005), scale=(1, 0.4, 1), segs=6, rings=4)
    # La cinta: una tira gris plateada por delante del plátano y pegada al panel por los lados.
    x, z = curve(0.0)
    box(p, "cinta", cinta, (0.055, 0.007, 0.13), (x, y0 - 0.03, z + 0.01), (0, 0, math.radians(14)), bevel=0.002)
    for k, s in enumerate((-1, 1)):
        box(p, f"cinta_lado_{k}", cinta, (0.006, 0.05, 0.12), (x + s * 0.028, y0 + 0.005, z + 0.01), (0, 0, math.radians(14)))
    return p


def cubo():
    """El cubo de fregona «Limpieza y vacío»: cubo, agua turbia, fregona y cartelito."""
    p = Piece("cubo", "bucket")
    cubo_ = p.mat("color", "#4dabf7", 0.4, glow=0.14)
    cubo_osc = p.mat("color_oscuro_22", "#4dabf7", 0.4, glow=0.1)
    agua = p.mat("agua", "#8c8a63", 0.15, glow=0.06)
    metal_ = p.mat("escurridor", "#adb5bd", 0.3, metal=0.7, glow=0.08)
    palo = p.mat("palo", "#b9814a", 0.7, glow=0.06)
    hilos = p.mat("hilos", "#f1ece0", 0.9, glow=0.16)
    hilos_osc = p.mat("hilos_sucios", "#d3c9b0", 0.9, glow=0.12)
    placa = p.mat("placa", "#f8f4e8", 0.5, glow=0.18)
    letras = p.mat("letras", "#22252b", 0.6, glow=0.0)
    lathe(p, "cubo", cubo_, [(0.001, 0.0), (0.085, 0.0), (0.09, 0.012), (0.115, 0.2), (0.001, 0.2)], segs=24)
    torus(p, "borde", cubo_osc, 0.117, 0.008, (0, 0, 0.202), segs=28, ring=6)
    cyl(p, "agua", agua, 0.108, 0.108, 0.006, (0, 0, 0.17), segs=24)
    # El escurridor de rodillos, en un lado.
    box(p, "escurridor_1", metal_, (0.02, 0.15, 0.03), (0.1, 0.0, 0.225), bevel=0.003)
    box(p, "escurridor_2", metal_, (0.02, 0.15, 0.03), (0.14, 0.0, 0.225), bevel=0.003)
    # La fregona apoyada, el palo inclinado y la cabeza de hilos dentro.
    base = Vector((-0.03, 0.02, 0.15))
    top = Vector((-0.12, 0.05, 0.45))
    between(p, "palo", palo, base, top, 0.011, segs=10)
    sphere(p, "cabeza_fregona", hilos, 0.045, base + Vector((0.0, -0.005, -0.01)), scale=(1.0, 1.0, 0.75))
    for k in range(9):
        a = k * math.tau / 9
        between(p, f"hilo_{k}", hilos if k % 2 else hilos_osc, base + Vector((0.02 * math.cos(a), 0.02 * math.sin(a), 0.0)),
                base + Vector((0.055 * math.cos(a), 0.055 * math.sin(a), -0.075)), 0.007, segs=6, r2=0.004)
    sphere(p, "mango", palo, 0.014, top, segs=10, rings=6)
    # El cartelito de museo, pegado delante: «Escultura» (dos rayitas de tinta).
    box(p, "cartel", placa, (0.1, 0.006, 0.06), (0, -0.1, 0.1), (math.radians(-6), 0, 0), bevel=0.002)
    box(p, "cartel_1", letras, (0.075, 0.002, 0.008), (0, -0.104, 0.115), (math.radians(-6), 0, 0))
    box(p, "cartel_2", letras, (0.055, 0.002, 0.008), (0, -0.1045, 0.095), (math.radians(-6), 0, 0))
    return p


MAKERS = {"hueso": hueso, "planta": planta, "caracol": caracol, "amatista": amatista, "anfora_souvenir": anfora, "laurel": laurel,
          "columna": columna, "david": david, "venus": venus, "espada": espada, "ornitoptero": ornitoptero,
          "platano": platano, "cubo": cubo}


wanted = [a for a in ARGS if not a.startswith("--")]
for name, make in MAKERS.items():
    if wanted and name not in wanted:
        continue
    piece = make()
    print("[nuevas]", name, len(piece.coll.objects), "partes")
for m in list(bpy.data.materials):
    if m.users == 0:
        bpy.data.materials.remove(m)
# Las piezas de más atrás de la fila (y la etiqueta de cada una) se vuelven a poner en fila.
catalogo.arrange()
for c in catalogo.pieces():
    catalogo.check_fit(c)
if "--save" in ARGS:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "botin.blend"))
    print("[nuevas] guardado art/botin.blend")
