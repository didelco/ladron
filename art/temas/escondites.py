"""Escondites: las piezas en las que se mete el ladrón (logic/hideouts.gd).

Muebles de una casilla, cada uno de su tema, de pie en el suelo con el frente
(la puerta, la tapa, la boca) mirando a -Y:
  moderna      nevera retro, caja de cartón
  antiguo      armadura de legionario
  edad_media   confesionario, baúl
  prehistoria  huevo de dinosaurio
  naturaleza   caparazón de tortuga gigante
Y tres grandes, a lo largo de X sobre su bloque de casillas (MapGen.BIG):
  antiguo      caballo de Troya (2×2)
  prehistoria  mamut (2×3)
  naturaleza   tronco hueco (1×3)

Añade cada pieza a su art/tema_<tema>.blend (crea los que faltan; si la pieza
ya estaba, la sustituye: pisa sus retoques), ordena la fila, guarda y exporta.

    Blender -b -P art/temas/escondites.py                  # todas
    Blender -b -P art/temas/escondites.py -- nevera mamut  # esas

Así se hizo la primera versión; después se retocan a mano en el .blend y salen
con art/export.py.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, ".."))
sys.path += [HERE, os.path.join(ART, "characters"), ART]
import bpy  # noqa: E402

import kit  # noqa: E402
import tema  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TAU = 2 * math.pi


def m(name, colour, **kw):
    return kit.mat(name, colour, **kw)


def paint(o, mat):
    kit.paint(o, mat)
    return o


# --- Moderna -------------------------------------------------------------------------

def nevera():
    """Una nevera retro de los cincuenta: cantos muy redondos, verde menta,
    dos puertas con su junta, tiradores cromados y patas cortas."""
    body_c = m("menta", "#a8dcc8", rough=0.35, coat=0.6)
    chrome = m("cromo", "#e8ecf0", rough=0.15, metal=0.9)
    rubber = m("junta", "#3a3f44", rough=0.8)
    w, d, h, lift = 0.64, 0.6, 1.3, 0.08
    out = []
    body = kit.superellipsoid("cuerpo", (0, 0, lift + h / 2), (w / 2, d / 2, h / 2), e=5.5)
    out.append(paint(body, body_c))
    # The seams: freezer above, the big door below, and the hinge side.
    seam_z = lift + h * 0.72
    out.append(paint(kit.box("junta_alta", (0, -d / 2 + 0.012, seam_z), (w * 0.9, 0.02, 0.012)), rubber))
    out.append(paint(kit.box("junta_lado", (w / 2 - 0.05, -d / 2 + 0.02, lift + h / 2), (0.01, 0.02, h * 0.86)), rubber))
    # Chrome handles: curved bars on the opening side.
    for name, z0, z1 in (("tirador_alto", seam_z + 0.07, seam_z + 0.27), ("tirador_bajo", seam_z - 0.32, seam_z - 0.07)):
        bar = kit.tube(name, [(-w / 2 + 0.07, -d / 2 + 0.005, z0), (-w / 2 + 0.07, -d / 2 - 0.04, (z0 + z1) / 2), (-w / 2 + 0.07, -d / 2 + 0.005, z1)],
                       [(0.016, 0.016)] * 3, segs=12, levels=1)
        out.append(paint(bar, chrome))
    # A chrome badge, no brand on it, and a chrome strip at the foot.
    out.append(paint(kit.superellipsoid("placa", (0, -d / 2 - 0.004, lift + 0.2), (0.09, 0.012, 0.025), e=2.4), chrome))
    out.append(paint(kit.box("zocalo", (0, -d / 2 + 0.03, lift + 0.03), (w * 0.8, 0.02, 0.03), bevel=0.005), chrome))
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = kit.cylinder(f"pata{sx}{sy}", (sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), lift / 2), 0.03, lift, r2=0.022, segs=16)
            out.append(paint(leg, chrome))
    return out


def caja():
    """Una caja de cartón grande, una instalación de arte de las de «¿y
    esto qué es?»: cinta de embalar, asa troquelada y flechas de «arriba»."""
    card = m("carton", "#c89c5c", rough=0.9)
    card_dark = m("carton_oscuro", "#9c7440", rough=0.9)
    tape = m("cinta", "#d8c08a", rough=0.3)
    ink = m("tinta", "#3a2a1a", rough=0.8)
    s = 0.74
    out = [paint(kit.box("caja", (0, 0, s / 2), (s, s * 0.92, s), bevel=0.012, segs=2), card)]
    out.append(paint(kit.box("cinta", (0, 0, s + 0.001), (0.14, s * 0.94, 0.006)), tape))
    out.append(paint(kit.box("cinta_delante", (0, -s * 0.46 - 0.001, s - 0.08), (0.14, 0.006, 0.16)), tape))
    out.append(paint(kit.box("junta_tapa", (0, 0, s - 0.004), (0.004, s * 0.93, 0.004)), card_dark))
    # The handhold slot, on the front.
    out.append(paint(kit.superellipsoid("asa", (0, -s * 0.46, s * 0.62), (0.08, 0.008, 0.022), e=3.0), ink))
    # "This way up": two arrows, printed.
    for k, x in enumerate((-0.2, 0.2)):
        arrow = kit.slab(f"flecha{k}", [(-0.02, 0), (0.02, 0), (0.02, 0.07), (0.045, 0.07), (0, 0.12), (-0.045, 0.07), (-0.02, 0.07)], 0.004,
                         loc=(x, -s * 0.46 - 0.002, 0.18))
        out.append(paint(arrow, ink))
    # A crease where it was folded flat once.
    out.append(paint(kit.box("pliegue", (s / 2 + 0.001, 0, s / 2), (0.004, 0.006, s * 0.9)), card_dark))
    return out


# --- Antiguo -------------------------------------------------------------------------

def legionario():
    """La armadura de un legionario romano en su soporte: casco con penacho,
    coraza de láminas, faldellín rojo con tiras de cuero, y el escudo curvo
    apoyado al lado."""
    steel = m("acero", "#b8bec8", rough=0.35, metal=0.7)
    brass = m("laton", "#d0a040", rough=0.35, metal=0.6)
    red = m("rojo_romano", "#b8262e", rough=0.8)
    leather = m("cuero", "#6b3a1e", rough=0.6)
    wood = m("madera", "#6e4424", rough=0.7)
    gold = m("oro", "#e8b53a", rough=0.3, metal=0.7)
    out = []
    out.append(paint(kit.box("peana", (0, 0.02, 0.04), (0.7, 0.5, 0.08), bevel=0.01), wood))
    out.append(paint(kit.cylinder("palo", (0, 0.04, 0.42), 0.025, 0.7, segs=12), wood))
    # The tunic and its skirt, and the leather strips over it.
    skirt = kit.lathe("faldellin", [(0.0, 0.5), (0.2, 0.5), (0.24, 0.62), (0.21, 0.8), (0.0, 0.8)], loc=(0, 0.04, 0))
    out.append(paint(skirt, red))
    for k in range(9):
        a = math.pi + (k - 4) * 0.22
        x, y = math.sin(a) * 0.235, 0.04 - math.cos(a) * 0.235 * 0.8
        strip = kit.box(f"tira{k}", (x * 0.98, y, 0.62), (0.04, 0.012, 0.2), rot=(0, 0, -a + math.pi), bevel=0.004)
        out.append(paint(strip, leather))
    # The lorica: bands of plate round the chest, shoulder guards.
    for k in range(6):
        z = 0.84 + k * 0.065
        rx = 0.21 + 0.02 * math.sin(k / 5 * math.pi)
        band = kit.superellipsoid(f"lamina{k}", (0, 0.04, z), (rx, rx * 0.72, 0.042), e=2.2)
        out.append(paint(band, steel))
    for sx in (-1, 1):
        guard = kit.superellipsoid(f"hombrera{sx}", (sx * 0.2, 0.04, 1.2), (0.11, 0.13, 0.07), e=2.2, rot=(0, sx * 0.5, 0))
        out.append(paint(guard, steel))
    out.append(paint(kit.superellipsoid("cinturon", (0, 0.04, 0.81), (0.22, 0.165, 0.03), e=2.5), brass))
    # The galea: bowl, neck guard, cheek pieces, crest front to back.
    out.append(paint(kit.cylinder("cuello", (0, 0.04, 1.26), 0.06, 0.08, segs=16), wood))
    out.append(paint(kit.sphere("casco", (0, 0.04, 1.36), (0.13, 0.14, 0.12), segs=32), steel))
    out.append(paint(kit.superellipsoid("guardanuca", (0, 0.17, 1.3), (0.15, 0.06, 0.02), e=2.2, rot=(-0.4, 0, 0)), steel))
    for sx in (-1, 1):
        out.append(paint(kit.box(f"carrillera{sx}", (sx * 0.12, -0.02, 1.26), (0.02, 0.1, 0.12), bevel=0.01), brass))
    out.append(paint(kit.box("visera", (0, -0.1, 1.36), (0.24, 0.03, 0.02), bevel=0.006), brass))
    crest = kit.tube("penacho", [(0, -0.1, 1.48), (0, 0.04, 1.55), (0, 0.2, 1.47)], [(0.035, 0.05)] * 3, segs=12, levels=1)
    out.append(paint(crest, red))
    # The scutum, curved and leaning against the stand.
    shield = []
    for k in range(7):
        a = (k - 3) * 0.13
        x = math.sin(a) * 0.55
        y = -math.cos(a) * 0.55 + 0.55
        shield.append(paint(kit.box(f"escudo{k}", (x, y, 0), (0.08, 0.03, 0.95)), red))
    for k, z in enumerate((-0.45, 0.45)):
        for j in range(7):
            a = (j - 3) * 0.13
            shield.append(paint(kit.box(f"canto{k}{j}", (math.sin(a) * 0.55, -math.cos(a) * 0.55 + 0.535, z), (0.085, 0.03, 0.03)), brass))
    shield.append(paint(kit.sphere("umbo", (0, -0.03, 0), (0.08, 0.05, 0.08), segs=24), brass))
    for sz in (-1, 1):
        shield.append(paint(kit.box(f"rayo{sz}", (0, -0.02, sz * 0.22), (0.04, 0.012, 0.3)), gold))
        for sx in (-1, 1):
            shield.append(paint(kit.box(f"ala{sz}{sx}", (sx * 0.11, -0.025, sz * 0.3), (0.16, 0.012, 0.04), rot=(0, sx * sz * 0.5, 0)), gold))
    pivot = kit.empty("escudo")
    kit.parent_all(pivot, shield)
    # Against its side, face out, leaning back a little.
    pivot.location = (0.36, 0.02, 0.49)
    pivot.rotation_euler = (0, -0.12, -math.pi / 2 - 0.12)
    out += shield + [pivot]
    return out


def caballo_troya():
    """El caballo de Troya: de tablones, alto y compacto sobre una plataforma
    cuadrada con ruedas (2×2 casillas), con la trampilla de la tripa
    entreabierta."""
    wood = m("tablon", "#b07a44", rough=0.8)
    wood_dark = m("tablon_oscuro", "#7c5028", rough=0.8)
    iron = m("hierro", "#4a4d55", rough=0.5)
    rope = m("cuerda", "#c9b07a", rough=0.9)
    shadow = m("hueco", "#1a1210", rough=1.0)
    planks = [(wood_dark, lambda c, n: int(math.floor(c.z / 0.12)) % 2 == 0)]
    deck = 0.52
    out = []
    out.append(paint(kit.box("plataforma", (0, 0, deck - 0.08), (1.86, 1.7, 0.16), bevel=0.02), wood_dark))
    for k, x in enumerate((-0.6, 0.0, 0.6)):
        out.append(paint(kit.box(f"liston{k}", (x, 0, deck + 0.005), (0.06, 1.72, 0.01)), wood))
    for sx in (-1, 1):
        for sy in (-1, 1):
            wheel = kit.cylinder(f"rueda{sx}{sy}", (sx * 0.62, sy * 0.8, 0.3), 0.3, 0.1, rot=(math.pi / 2, 0, 0), segs=24, bevel=0.01)
            out.append(paint(wheel, wood_dark))
            out.append(paint(kit.cylinder(f"buje{sx}{sy}", (sx * 0.62, sy * 0.86, 0.3), 0.07, 0.06, rot=(math.pi / 2, 0, 0), segs=12), iron))
    # Long legs, a short deep body, the neck up high: a horse to look up at.
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = sx * 0.4
            leg = kit.tube(f"pata{sx}{sy}", [(x, sy * 0.22, deck + 0.03), (x, sy * 0.22, deck + 0.5), (x - sx * 0.02, sy * 0.22, 1.35)],
                           [(0.09, 0.09), (0.08, 0.08), (0.1, 0.1)], segs=12, levels=1)
            out.append(kit.paint_regions(leg, planks, wood))
            out.append(paint(kit.cylinder(f"casco{sx}{sy}", (x, sy * 0.22, deck + 0.035), 0.11, 0.07, segs=12), wood_dark))
    body = kit.tube("cuerpo", [(-0.58, 0, 1.52), (-0.2, 0, 1.56), (0.2, 0, 1.56), (0.52, 0, 1.56)],
                    [(0.33, 0.35), (0.38, 0.4), (0.38, 0.4), (0.33, 0.36)], segs=24, levels=1, up=(0, 0, 1))
    out.append(kit.paint_regions(body, planks, wood))
    neck = kit.tube("cuello", [(0.45, 0, 1.72), (0.6, 0, 2.08), (0.66, 0, 2.38)], [(0.22, 0.19), (0.19, 0.16), (0.17, 0.14)], segs=16, levels=1)
    out.append(kit.paint_regions(neck, planks, wood))
    head = kit.tube("cabeza", [(0.6, 0, 2.48), (0.78, 0, 2.42), (0.94, 0, 2.24)], [(0.16, 0.14), (0.13, 0.12), (0.1, 0.095)], segs=16, levels=1)
    out.append(kit.paint_regions(head, planks, wood))
    for sy in (-1, 1):
        out.append(paint(kit.cylinder(f"oreja{sy}", (0.58, sy * 0.08, 2.66), 0.05, 0.14, r2=0.0, segs=8), wood_dark))
        out.append(paint(kit.sphere(f"ojo{sy}", (0.78, sy * 0.12, 2.44), (0.035, 0.02, 0.035), segs=12), shadow))
    for k in range(7):
        t = k / 6
        x, z = 0.4 + t * 0.2, 1.85 + t * 0.62
        out.append(paint(kit.box(f"crin{k}", (x - 0.13, 0, z + 0.06), (0.08, 0.05, 0.16), rot=(0, -0.35, 0)), wood_dark))
    tail = kit.tube("cola", [(-0.66, 0, 1.66), (-0.8, 0, 1.4), (-0.82, 0, 1.05)], [(0.06, 0.06), (0.07, 0.05), (0.04, 0.03)], segs=10, levels=1)
    out.append(paint(tail, rope))
    # The hatch in the belly, on the camera's side, ajar.
    out.append(paint(kit.box("trampilla_hueco", (0.0, -0.34, 1.4), (0.42, 0.08, 0.32)), shadow))
    hatch = kit.box("trampilla", (0.0, -0.46, 1.25), (0.42, 0.04, 0.32), rot=(-1.1, 0, 0), bevel=0.01)
    out.append(paint(hatch, wood_dark))
    for k, z in enumerate((1.36, 1.74)):
        out.append(paint(kit.box(f"fleje{k}", (-0.38, 0, z), (0.05, 0.8, 0.04)), iron))
    return out


# --- Edad Media ----------------------------------------------------------------------

def confesionario():
    """Un confesionario gótico de madera oscura: arco apuntado, celosía,
    cortina morada a medio correr y una crucecita encima."""
    wood = m("nogal", "#4a2c16", rough=0.7)
    wood_light = m("nogal_claro", "#6e4424", rough=0.7)
    purple = m("cortina", "#5a2a6e", rough=0.9)
    gold = m("oro", "#e8b53a", rough=0.3, metal=0.7)
    shadow = m("hueco", "#140c08", rough=1.0)
    w, d, h = 0.78, 0.66, 1.3

    def arch(half, spring, top, n=8):
        pts = [(-half, 0.0), (half, 0.0), (half, spring)]
        for k in range(1, n):
            t = k / n
            a = t * math.pi / 2
            pts.append((half - half * (1 - math.cos(a)) * 1.0, spring + (top - spring) * math.sin(a)))
        pts.append((0.0, top))
        for k in range(n - 1, 0, -1):
            t = k / n
            a = t * math.pi / 2
            pts.append((-half + half * (1 - math.cos(a)), spring + (top - spring) * math.sin(a)))
        pts.append((-half, spring))
        return pts

    out = [paint(kit.slab("caseta", arch(w / 2, h, h + 0.32), d, loc=(0, 0, 0.0), bevel=0.01), wood)]
    out.append(paint(kit.box("zocalo", (0, 0, 0.04), (w + 0.06, d + 0.06, 0.08), bevel=0.01), wood_light))
    out.append(paint(kit.slab("hueco", arch(0.27, 1.05, 1.3), 0.03, loc=(0, -d / 2 - 0.004, 0.1)), shadow))
    out.append(paint(kit.slab("marco", arch(0.3, 1.06, 1.34), 0.02, loc=(0, -d / 2 - 0.001, 0.08)), wood_light))
    # The curtain, half drawn: folds.
    for k in range(6):
        x = -0.24 + k * 0.05
        out.append(paint(kit.cylinder(f"pliegue{k}", (x, -d / 2 - 0.03, 0.66), 0.03, 1.1, segs=10), purple))
    out.append(paint(kit.cylinder("barra", (0, -d / 2 - 0.03, 1.2), 0.012, 0.6, rot=(0, math.pi / 2, 0), segs=8), gold))
    # The grille on the side, where the penitent kneels.
    for k in range(5):
        out.append(paint(kit.box(f"celosia_v{k}", (w / 2 + 0.005, -0.12 + k * 0.06, 0.95), (0.01, 0.012, 0.3)), wood_light))
        out.append(paint(kit.box(f"celosia_h{k}", (w / 2 + 0.005, 0.0, 0.83 + k * 0.06), (0.01, 0.26, 0.012)), wood_light))
    out.append(paint(kit.box("reclinatorio", (w / 2 + 0.1, 0, 0.12), (0.2, 0.5, 0.08), bevel=0.01), wood_light))
    # A little cross on the point.
    out.append(paint(kit.box("cruz_v", (0, 0, h + 0.44), (0.03, 0.03, 0.2)), gold))
    out.append(paint(kit.box("cruz_h", (0, 0, h + 0.48), (0.12, 0.03, 0.03)), gold))
    return out


def baul():
    """Un baúl de viaje con la tapa abombada, flejes de hierro, cerradura
    dorada y asas a los lados."""
    wood = m("roble", "#8a5a2e", rough=0.7)
    wood_dark = m("roble_oscuro", "#5e3a1a", rough=0.7)
    iron = m("hierro", "#4a4d55", rough=0.45, metal=0.5)
    gold = m("oro", "#e8b53a", rough=0.3, metal=0.7)
    w, d, h = 0.86, 0.56, 0.5
    out = [paint(kit.box("caja", (0, 0, h / 2), (w, d, h), bevel=0.012), wood)]
    lid = kit.cylinder("tapa", (0, 0, h), d / 2, w, rot=(0, math.pi / 2, 0), segs=32, bevel=0.01)
    lid.scale = (1, 1, 0.7)
    out.append(paint(lid, wood_dark))
    for k, x in enumerate((-0.3, 0.0, 0.3)):
        out.append(paint(kit.box(f"fleje{k}", (x, 0, h / 2), (0.05, d + 0.012, h + 0.004)), iron))
        ring = kit.cylinder(f"fleje_tapa{k}", (x, 0, h), d / 2 + 0.008, 0.05, rot=(0, math.pi / 2, 0), segs=32)
        ring.scale = (1, 1, 0.72)
        out.append(paint(ring, iron))
    out.append(paint(kit.box("cantonera", (0, 0, 0.03), (w + 0.012, d + 0.012, 0.05)), iron))
    out.append(paint(kit.box("cerradura", (0, -d / 2 - 0.012, h - 0.04), (0.1, 0.02, 0.12), bevel=0.008), gold))
    out.append(paint(kit.cylinder("bocallave", (0, -d / 2 - 0.024, h - 0.05), 0.012, 0.01, rot=(math.pi / 2, 0, 0), segs=8), iron))
    for sx in (-1, 1):
        handle = kit.tube(f"asa{sx}", [(sx * (w / 2 + 0.005), -0.08, 0.32), (sx * (w / 2 + 0.05), 0, 0.3), (sx * (w / 2 + 0.005), 0.08, 0.32)],
                          [(0.012, 0.012)] * 3, segs=8, levels=1)
        out.append(paint(handle, iron))
    return out


# --- Prehistoria ---------------------------------------------------------------------

def huevo():
    """Un huevo de dinosaurio gigante, moteado, en su nido de ramas, con la
    punta rota y apoyada al lado: se entra por arriba."""
    shell = m("cascara", "#e8dcc0", rough=0.6)
    spot = m("mota", "#8a6a48", rough=0.7)
    inside = m("hueco", "#2a2018", rough=1.0)
    nest = m("paja", "#a07838", rough=0.9)
    twig = m("rama", "#6a4a28", rough=0.9)
    sand = m("arena", "#d8c49a", rough=1.0)
    out = [paint(kit.cylinder("arena", (0, 0, 0.03), 0.4, 0.06, segs=32, bevel=0.01), sand)]
    prof = [(0.0, 0.06), (0.2, 0.08), (0.32, 0.2), (0.37, 0.42), (0.35, 0.66), (0.3, 0.86), (0.27, 0.92)]
    out.append(paint(kit.lathe("huevo", prof + [(0.24, 0.92), (0.0, 0.8)], segs=40), shell))
    out.append(paint(kit.cylinder("boca", (0, 0, 0.915), 0.24, 0.01, segs=32), inside))
    # The jagged rim where it broke.
    for k in range(12):
        a = k / 12 * TAU
        tooth = kit.cylinder(f"diente{k}", (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.94), 0.045, 0.07 + 0.04 * (k % 3), r2=0.0, segs=4)
        out.append(paint(tooth, shell))
    # The broken tip, lying against it.
    cap = kit.lathe("punta", [(0.0, 0.0), (0.27, 0.0), (0.22, 0.12), (0.12, 0.2), (0.0, 0.22)], segs=32)
    cap.location = (0.3, -0.3, 0.12)
    cap.rotation_euler = (2.3, 0.3, 0)
    out.append(paint(cap, shell))
    # Speckles.
    for k in range(22):
        a = (k * 2.39996) % TAU
        z = 0.2 + (k * 0.37 % 1.0) * 0.6
        r = 0.36 - abs(z - 0.45) * 0.18
        dot = kit.superellipsoid(f"mota{k}", (math.cos(a) * r, math.sin(a) * r, z), (0.03, 0.03, 0.02), e=2.0,
                                 rot=(0, math.pi / 2, a))
        out.append(paint(dot, spot))
    # The nest round its foot.
    out.append(paint(kit.lathe("nido", [(0.3, 0.02), (0.44, 0.04), (0.42, 0.14), (0.34, 0.12), (0.3, 0.06)], segs=32), nest))
    for k in range(9):
        a = k / 9 * TAU
        out.append(paint(kit.cylinder(f"ramita{k}", (math.cos(a) * 0.39, math.sin(a) * 0.39, 0.11), 0.012, 0.3,
                                      rot=(math.pi / 2, 0, a + 0.4), segs=6), twig))
    return out


def mamut():
    """Un mamut lanudo de tamaño natural (casi), sobre su peana: el ladrón se
    mete entre el pelo, bajo la tripa."""
    fur = m("pelo", "#6b4226", rough=0.95)
    fur_dark = m("pelo_oscuro", "#4a2c18", rough=0.95)
    ivory = m("marfil", "#f0e6cc", rough=0.4)
    eye = m("ojo", "#140c08", rough=0.3)
    stone = m("peana", "#8a8a8e", rough=0.9)
    brass = m("laton", "#c9953a", rough=0.35, metal=0.6)
    # Legs as long as a mammoth's: it stands nearly twice a person's height.
    up = 0.28
    out = [paint(kit.box("peana", (0, 0, 0.06), (2.8, 1.5, 0.12), bevel=0.02), stone)]
    out.append(paint(kit.box("placa", (0, -0.751, 0.06), (0.3, 0.01, 0.06)), brass))
    parts = [
        kit.sphere("tronco", (-0.1, 0, 1.25 + up), (0.95, 0.58, 0.6), segs=32),
        kit.sphere("joroba", (0.35, 0, 1.62 + up), (0.45, 0.4, 0.35), segs=32),
        kit.sphere("cabeza", (0.85, 0, 1.55 + up), (0.36, 0.34, 0.42), segs=32),
    ]
    for sx, x in ((1, 0.5), (-1, -0.65)):
        for sy in (-1, 1):
            parts.append(kit.capsule(f"pata{x}{sy}", (x, sy * 0.3, 0.2), (x, sy * 0.3, 1.1 + up), 0.2, 0.23))
    parts.append(kit.capsule("trompa_a", (1.1, 0, 1.4 + up), (1.3, 0, 0.95 + up * 0.6), 0.13, 0.09))
    parts.append(kit.capsule("trompa_b", (1.3, 0, 0.95 + up * 0.6), (1.22, 0, 0.5), 0.09, 0.06))
    body = kit.blob("mamut", parts, voxel=0.03, smooth=4, factor=0.6)
    # Darker low down and along the spine, like a coat that hangs.
    out.append(kit.paint_regions(body, [(fur_dark, lambda c, n: c.z < 0.8 + up or n.z > 0.85)], fur))
    # The shaggy fringe hanging off its belly, where the thief slips in.
    for k in range(26):
        t = k / 25
        a = t * TAU
        x = math.cos(a) * 0.85 - 0.1
        y = math.sin(a) * 0.52
        strand = kit.cylinder(f"mechon{k}", (x, y, 0.78 + up), 0.07, 0.36, r2=0.015, rot=(math.pi, 0, 0), segs=6)
        out.append(paint(strand, fur_dark if k % 2 else fur))
    for sy in (-1, 1):
        tusk = kit.tube(f"colmillo{sy}", [(1.05, sy * 0.16, 1.2 + up), (1.35, sy * 0.3, 0.85 + up), (1.45, sy * 0.28, 1.05 + up), (1.4, sy * 0.12, 1.3 + up)],
                        [(0.06, 0.06), (0.055, 0.055), (0.045, 0.045), (0.025, 0.025)], segs=12, levels=1)
        out.append(paint(tusk, ivory))
        out.append(paint(kit.sphere(f"ojo{sy}", (1.05, sy * 0.28, 1.68 + up), (0.03, 0.02, 0.03), segs=12), eye))
        ear = kit.superellipsoid(f"oreja{sy}", (0.72, sy * 0.33, 1.72 + up), (0.12, 0.03, 0.14), e=2.2)
        out.append(paint(ear, fur_dark))
    tail = kit.tube("cola", [(-1.02, 0, 1.4 + up), (-1.1, 0, 1.15 + up), (-1.08, 0, 0.95 + up)], [(0.04, 0.04), (0.03, 0.03), (0.05, 0.05)], segs=8, levels=1)
    out.append(paint(tail, fur_dark))
    return out


# --- Naturaleza ----------------------------------------------------------------------

def caparazon():
    """El caparazón vacío de una tortuga gigante de las Galápagos: escudos
    en relieve y la abertura del cuello, por donde se entra."""
    shell = m("caparazon", "#7a5a30", rough=0.6)
    plate = m("escudo_claro", "#a07a44", rough=0.6)
    rim = m("borde", "#5a3e20", rough=0.7)
    inside = m("hueco", "#1a1210", rough=1.0)
    wood = m("madera", "#6e4424", rough=0.7)
    out = [paint(kit.box("tarima", (0, 0, 0.03), (0.86, 0.8, 0.06), bevel=0.01), wood)]
    dome = kit.lathe("concha", [(0.0, 0.06), (0.4, 0.06), (0.41, 0.14), (0.36, 0.34), (0.24, 0.5), (0.0, 0.56)], segs=48)
    dome.scale = (1.0, 0.9, 1.0)

    # The scutes, painted: a cap on top, then two rings of plates, each ring
    # offset half a plate from the last, light and dark by turns.
    def scute(c, n):
        z = c.z
        if z > 0.5:
            return False
        ring = 0 if z > 0.33 else 1
        count = 5 if ring == 0 else 8
        a = (math.atan2(c.y, c.x) / TAU + (0.5 / count if ring else 0.0)) % 1.0
        return (int(a * count) + ring) % 2 == 0
    out.append(kit.paint_regions(dome, [(plate, scute)], shell))
    for k in range(18):
        a = k / 18 * TAU
        o = kit.box(f"marginal{k}", (math.cos(a) * 0.405, math.sin(a) * 0.405 * 0.9, 0.12), (0.06, 0.12, 0.1), rot=(0, 0, a), bevel=0.01)
        out.append(paint(o, rim))
    # The opening for the neck, at the front.
    out.append(paint(kit.superellipsoid("abertura", (0, -0.37, 0.16), (0.16, 0.05, 0.08), e=2.2), inside))
    return out


def tronco():
    """Un tronco caído y hueco del diorama del bosque: corteza, musgo, setas
    y los anillos en las puntas, abiertas por dentro."""
    bark = m("corteza", "#5a3e26", rough=0.95)
    bark_dark = m("corteza_oscura", "#3e2a18", rough=0.95)
    rings = m("anillos", "#c9a06a", rough=0.8)
    inside = m("hueco", "#1a1210", rough=1.0)
    moss = m("musgo", "#4e7a3a", rough=0.95)
    cap = m("seta", "#c8402e", rough=0.6)
    stem = m("pie_seta", "#efe6d0", rough=0.7)
    leaves = m("hojas", "#8a6a2a", rough=0.9)
    r, length = 0.42, 2.7
    out = []
    log = kit.cylinder("tronco", (0, 0, r), r, length, rot=(0, math.pi / 2, 0), segs=20, bevel=0.03)
    out.append(kit.paint_regions(log, [(bark_dark, lambda c, n: int(math.floor((math.atan2(c.y, c.z - r) + 4) / 0.3)) % 2 == 0 and abs(n.x) < 0.5),
                                       (rings, lambda c, n: abs(n.x) > 0.5)], bark))
    for sx in (-1, 1):
        out.append(paint(kit.cylinder(f"hueco{sx}", (sx * (length / 2 + 0.002), 0, r), r * 0.68, 0.01, rot=(0, math.pi / 2, 0), segs=20), inside))
    for k, (x, y, s) in enumerate(((-0.6, 0.05, 0.3), (0.2, -0.1, 0.22), (0.8, 0.12, 0.26))):
        out.append(paint(kit.superellipsoid(f"musgo{k}", (x, y, 2 * r - 0.02), (s, s * 0.6, 0.05), e=2.0), moss))
    for k, (x, y) in enumerate(((0.5, -0.36), (0.62, -0.33), (-0.9, -0.37))):
        out.append(paint(kit.cylinder(f"pie{k}", (x, y - 0.04, 0.28), 0.018, 0.08, rot=(math.pi / 2 - 0.3, 0, 0), segs=8), stem))
        out.append(paint(kit.lathe(f"sombrero{k}", [(0.0, 0.0), (0.06, 0.0), (0.05, 0.03), (0.0, 0.045)], loc=(x, y - 0.08, 0.3),
                                   rot=(math.pi / 2 - 0.3, 0, 0), segs=16), cap))
    out.append(paint(kit.cylinder("rama", (0.3, 0.2, 0.72), 0.06, 0.4, rot=(-0.5, 0.2, 0), segs=10), bark))
    for k in range(10):
        x = -1.3 + (k * 0.61 % 2.6)
        y = -0.4 + (k * 0.37 % 0.8)
        leaf = kit.superellipsoid(f"hoja{k}", (x, y, 0.01), (0.05, 0.03, 0.005), e=2.0, rot=(0, 0, k * 1.3))
        out.append(paint(leaf, leaves))
    return out


# --- Cada pieza a su fichero ----------------------------------------------------------

FILES = {
    "tema_moderna.blend": ("temas/moderna", [("nevera", nevera), ("caja", caja)]),
    "tema_antiguo.blend": ("temas/antiguo", [("legionario", legionario), ("caballo_troya", caballo_troya)]),
    "tema_edad_media.blend": ("temas/edad_media", [("confesionario", confesionario), ("baul", baul)]),
    "tema_prehistoria.blend": ("temas/prehistoria", [("huevo", huevo), ("mamut", mamut)]),
    "tema_naturaleza.blend": ("temas/naturaleza", [("caparazon", caparazon), ("tronco", tronco)]),
}
BIG = {"caballo_troya", "mamut", "tronco"}
## Each piece to its own proportions next to the thief (about 1.2 tall in the
## game, 1 real metre ≈ 0.7): the whole piece scaled from its foot.
SCALE = {"nevera": 0.93, "legionario": 0.85, "confesionario": 0.9, "huevo": 0.92, "caparazon": 1.08}


done = []
for file, (out, pieces) in FILES.items():
    wanted = [(n, f) for n, f in pieces if not ARGS or n in ARGS]
    if wanted:
        done += tema.replace(os.path.join(ART, file), out, wanted, lambda n: "grande" if n in BIG else "escondite", SCALE)
print("[escondites]", len(done), "piezas:", ", ".join(done))
