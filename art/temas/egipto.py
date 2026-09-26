"""Mundo antiguo, la parte de Egipto: escarabajo, vasos canopos, amuletos y papiro en vitrina; busto del
faraón, gata Bastet y obelisco sobre peana; Anubis y la barca solar de pie.
El sarcófago (art/sarcofago.blend) es su pieza grande.

    Blender -b -P art/temas/egipto.py [-- --sheet /ruta.png]
"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import tema  # noqa: E402  (antes que kit: prepara la ruta)
import kit  # noqa: E402
from kit import Vector  # noqa: E402

kit.reset()
GOLD = kit.mat("oro", "#e8b53a", rough=0.3, metal=0.7)
GOLD_DARK = kit.mat("oro_oscuro", "#a8801e", rough=0.4, metal=0.6)
LAPIS = kit.mat("lapislazuli", "#2a4fb0", rough=0.3)
TURQUOISE = kit.mat("turquesa", "#2fb8a8", rough=0.3)
SAND = kit.mat("arenisca", "#d9b77a", rough=0.8)
SAND_DARK = kit.mat("arenisca_oscura", "#a8844e", rough=0.8)
ALABASTER = kit.mat("alabastro", "#efe4cc", rough=0.5)
BLACK = kit.mat("basalto", "#1c1b22", rough=0.4)
PAPYRUS = kit.mat("papiro", "#e6d29a", rough=0.9)
INK = kit.mat("tinta", "#2a1e14", rough=0.8)
RED = kit.mat("ocre_rojo", "#b0402a", rough=0.7)
VELVET = kit.mat("terciopelo", "#6a1f2e", rough=0.9)
SKIN = kit.mat("piel_estatua", "#b0703c", rough=0.6)
WOOD = kit.mat("madera", "#7a4a26", rough=0.7)
WHITE = kit.mat("blanco", "#f4f0e6", rough=0.6)


# --- En vitrina ---------------------------------------------------------------------

def escarabajo():
    """Un escarabajo sagrado de lapislázuli, con cabeza y patas de oro, sobre
    su peana de oro."""
    base = kit.superellipsoid("peana", (0, 0, 0.02), (0.13, 0.11, 0.02), e=3.0)
    kit.paint(base, GOLD)
    body = kit.superellipsoid("elitros", (0, 0.01, 0.075), (0.085, 0.1, 0.05), e=2.3)
    kit.paint(body, LAPIS)
    seam = kit.box("sutura", (0, 0.03, 0.117), (0.006, 0.12, 0.006), bevel=0.002)
    kit.paint(seam, GOLD)
    head = kit.superellipsoid("cabeza", (0, -0.1, 0.06), (0.05, 0.035, 0.03), e=2.3)
    kit.paint(head, GOLD)
    horn = kit.superellipsoid("clipeo", (0, -0.13, 0.065), (0.055, 0.015, 0.02), e=2.6)
    kit.paint(horn, GOLD)
    legs = []
    for s in (-1, 1):
        for k, y in enumerate((-0.05, 0.0, 0.05)):
            leg = kit.tube(f"pata{s}{k}", [(s * 0.07, y, 0.06), (s * 0.12, y - 0.01, 0.04), (s * 0.13, y - 0.02, 0.03)],
                           [(0.009, 0.009)] * 3, levels=1)
            kit.paint(leg, GOLD)
            legs.append(leg)
    return [base, body, seam, head, horn] + legs


def canopos():
    """Tres vasos canopos de alabastro en su bandeja: tapas con cabeza de
    halcón, de chacal y humana."""
    tray = tema.stand_block("bandeja", 0.52, 0.2, 0.03, WOOD)
    out = [tray]
    for i, (x, lid) in enumerate(((-0.17, "halcon"), (0.0, "chacal"), (0.17, "humana"))):
        jar = kit.lathe(f"vaso{i}", [(0.0, 0.0), (0.045, 0.0), (0.06, 0.04), (0.065, 0.12), (0.055, 0.19), (0.04, 0.21), (0.0, 0.21)],
                        loc=(x, 0, 0.03))
        kit.paint(jar, ALABASTER)
        kit.smooth_shade(jar)
        band = kit.band(f"franja{i}", 0.13, 0.008, 0.066, 0.066, 2.0, grow=0.002, segs=32)
        band.location.x = x
        kit.paint(band, LAPIS)
        head = kit.superellipsoid(f"tapa{i}", (x, 0, 0.27), (0.045, 0.045, 0.045), e=2.1)
        kit.paint(head, BLACK if lid == "chacal" else (GOLD_DARK if lid == "halcon" else SKIN))
        out += [jar, band, head]
        if lid == "chacal":
            for s in (-1, 1):
                ear = kit.cylinder(f"oreja{i}{s}", (x + s * 0.02, 0.005, 0.325), 0.0, 0.04, r2=0.014, segs=8)
                kit.paint(ear, BLACK)
                out.append(ear)
            snout = kit.superellipsoid(f"hocico{i}", (x, -0.045, 0.262), (0.018, 0.035, 0.018), e=2.2)
            kit.paint(snout, BLACK)
            out.append(snout)
        elif lid == "halcon":
            beak = kit.cylinder(f"pico{i}", (x, -0.05, 0.265), 0.0, 0.03, r2=0.014, rot=(math.pi / 2, 0, 0), segs=8)
            kit.paint(beak, GOLD)
            out.append(beak)
        else:
            wig = kit.superellipsoid(f"peluca{i}", (x, 0.008, 0.28), (0.05, 0.045, 0.045), e=2.4)
            kit.paint(wig, LAPIS)
            face = kit.superellipsoid(f"cara{i}", (x, -0.025, 0.265), (0.03, 0.025, 0.035), e=2.2)
            kit.paint(face, SKIN)
            out += [wig, face]
    return out


def amuletos():
    """El ankh de oro y el ojo de Horus de turquesa, sobre un cojín."""
    pad = tema.cushion("cojin", 0.46, 0.3, VELVET)
    # El ankh, tumbado sobre el cojín: el lazo arriba, los brazos y el pie.
    loop = kit.lathe("ankh_lazo", [(0.02, -0.008), (0.03, 0.0), (0.02, 0.008)], loc=(-0.11, -0.06, 0.05), size=(1.0, 1.35, 1.0), segs=24)
    stem = kit.box("ankh_pie", (-0.11, 0.05, 0.05), (0.028, 0.13, 0.016), bevel=0.006)
    arms = kit.box("ankh_brazos", (-0.11, -0.012, 0.05), (0.12, 0.026, 0.016), bevel=0.006)
    for o in (loop, stem, arms):
        kit.paint(o, GOLD)
        o.rotation_euler = (0, 0, 0.25)
    # El ojo de Horus: el ojo, la pupila, la ceja, la lágrima y la espiral.
    eye = kit.superellipsoid("ojo", (0.1, 0, 0.052), (0.075, 0.035, 0.012), e=2.0)
    kit.paint(eye, WHITE)
    pupil = kit.superellipsoid("pupila", (0.1, 0, 0.062), (0.026, 0.026, 0.008), e=2.0)
    kit.paint(pupil, LAPIS)
    rim = kit.tube("contorno", [(0.02, 0.0, 0.056), (0.1, -0.04, 0.056), (0.18, 0.0, 0.056), (0.1, 0.04, 0.056), (0.02, 0.0, 0.056)],
                   [(0.007, 0.007)] * 5, levels=1)
    kit.paint(rim, TURQUOISE)
    brow = kit.tube("ceja", [(0.03, -0.06, 0.056), (0.1, -0.075, 0.056), (0.19, -0.058, 0.056)], [(0.011, 0.011)] * 3, levels=1)
    kit.paint(brow, TURQUOISE)
    tear = kit.tube("lagrima", [(0.09, 0.04, 0.056), (0.085, 0.08, 0.056), (0.095, 0.12, 0.056)], [(0.008, 0.008)] * 3, levels=1)
    kit.paint(tear, TURQUOISE)
    swirl = kit.tube("espiral", [(0.13, 0.035, 0.056), (0.16, 0.08, 0.056), (0.2, 0.09, 0.056), (0.21, 0.06, 0.056)], [(0.008, 0.008)] * 4, levels=1)
    kit.paint(swirl, TURQUOISE)
    return [pad, loop, stem, arms, eye, pupil, rim, brow, tear, swirl]


def papiro():
    """Un papiro desenrollado en su atril, con columnas de jeroglíficos y una
    figura en ocre."""
    stand = kit.box("atril", (0, 0.03, 0.04), (0.46, 0.1, 0.08), bevel=0.01)
    kit.paint(stand, WOOD)
    sheet_ = kit.box("hoja", (0, 0.0, 0.15), (0.4, 0.012, 0.2), bevel=0.004, rot=(-0.3, 0, 0))
    kit.paint(sheet_, PAPYRUS)
    out = [stand, sheet_]
    for s in (-1, 1):
        roll = kit.cylinder(f"rollo{s}", (s * 0.21, 0.0, 0.15), 0.022, 0.22, rot=(-0.3, 0, 0), segs=16)
        kit.paint(roll, PAPYRUS)
        out.append(roll)
    rng = __import__("random").Random(3)
    for col in range(6):
        for row in range(4):
            x = -0.15 + col * 0.06
            if abs(x) < 0.03:
                continue
            w, h = rng.choice([(0.02, 0.012), (0.012, 0.024), (0.018, 0.018)])
            g = kit.decal(f"signo{col}{row}", [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], [sheet_],
                          at=(x, 0.21 - row * 0.04), lift=0.001, thickness=0.003, res=6)
            kit.paint(g, INK)
            out.append(g)
    fig = kit.decal("figura", [(-0.012, -0.06), (0.012, -0.06), (0.014, 0.04), (0.02, 0.05), (0.0, 0.07), (-0.02, 0.05), (-0.014, 0.04)],
                    [sheet_], at=(0.0, 0.15), lift=0.001, thickness=0.003, res=12)
    kit.paint(fig, RED)
    return out + [fig]


# --- Sobre peana -------------------------------------------------------------------

def busto_faraon():
    """El busto del faraón: tocado nemes a rayas azules y doradas, barba
    postiza y la cobra en la frente."""
    parts = _faraon()
    for o in parts:
        o.scale = (1.3, 1.3, 1.3)
        o.location = o.location * 1.3
    return parts


def _faraon():
    chest = kit.loft("pecho", [(0.0, 0, 0, 0.16, 0.1, 2.6), (0.06, 0, 0, 0.17, 0.1, 2.6), (0.14, 0, 0, 0.12, 0.08, 2.4),
                               (0.17, 0, 0, 0.05, 0.045, 2.2)], segs=32)
    kit.paint(chest, SKIN)
    collar = kit.band("collar", 0.11, 0.035, 0.155, 0.095, 2.6, grow=0.008)
    kit.paint(collar, TURQUOISE)
    collar_rim = kit.band("collar_borde", 0.076, 0.008, 0.16, 0.1, 2.6, grow=0.008)
    kit.paint(collar_rim, GOLD)
    head = kit.loft("cabeza", [(0.16, 0, 0, 0.045, 0.045, 2.2), (0.2, 0, -0.005, 0.07, 0.07, 2.4), (0.27, 0, 0, 0.075, 0.078, 2.5),
                               (0.32, 0, 0.005, 0.06, 0.065, 2.4), (0.34, 0, 0.005, 0.03, 0.03, 2.0)], segs=24)
    kit.paint(head, SKIN)
    # El nemes: una tela a rayas que cae a los hombros por detrás de las orejas.
    nemes = kit.loft("nemes", [(0.12, 0, 0.02, 0.13, 0.05, 2.6), (0.2, 0, 0.02, 0.1, 0.075, 2.6), (0.29, 0, 0.012, 0.09, 0.085, 2.6),
                               (0.35, 0, 0.012, 0.07, 0.07, 2.4), (0.37, 0, 0.012, 0.02, 0.02, 2.0)], segs=32)
    kit.paint_regions(nemes, [(LAPIS, lambda c, n: int((c.z + 0.2) * 70) % 2 == 0)], GOLD)
    # Cara al descubierto: se borra lo que tapa la cara.
    kit.delete_faces(nemes, lambda c: c.y < -0.035 and 0.2 < c.z < 0.335 and abs(c.x) < 0.07)
    cobra = kit.tube("cobra", [(0, -0.07, 0.31), (0, -0.09, 0.33), (0, -0.085, 0.36)], [(0.01, 0.01), (0.012, 0.012), (0.014, 0.01)], levels=1)
    kit.paint(cobra, GOLD)
    beard = kit.loft("barba", [(0.17, 0, -0.065, 0.012, 0.012, 2.4), (0.2, 0, -0.07, 0.016, 0.016, 2.4), (0.23, 0, -0.07, 0.014, 0.014, 2.4)], segs=12)
    kit.paint(beard, LAPIS)
    out = [chest, collar, collar_rim, head, nemes, cobra, beard]
    for s in (-1, 1):
        eye = kit.superellipsoid(f"ojo{s}", (s * 0.028, -0.07, 0.27), (0.016, 0.006, 0.008), e=2.0)
        kit.paint(eye, WHITE)
        liner = kit.tube(f"kohl{s}", [(s * 0.012, -0.072, 0.271), (s * 0.045, -0.066, 0.268), (s * 0.06, -0.058, 0.262)], [(0.0035, 0.0035)] * 3, levels=1)
        kit.paint(liner, BLACK)
        out += [eye, liner]
    return out


def gato_bastet():
    """La gata Bastet sentada, de basalto, con collar y pendiente de oro."""
    body = kit.loft("cuerpo", [(0.0, 0, 0.02, 0.07, 0.1, 2.4), (0.06, 0, 0.02, 0.075, 0.1, 2.4), (0.16, 0, 0.0, 0.06, 0.07, 2.3),
                               (0.26, 0, -0.01, 0.045, 0.05, 2.2), (0.3, 0, -0.01, 0.035, 0.04, 2.0)], segs=24)
    kit.paint(body, BLACK)
    head = kit.superellipsoid("cabeza", (0, -0.02, 0.34), (0.05, 0.05, 0.045), e=2.2)
    kit.paint(head, BLACK)
    out = [body, head]
    for s in (-1, 1):
        ear = kit.cylinder(f"oreja{s}", (s * 0.03, -0.01, 0.395), 0.0, 0.06, r2=0.02, segs=8, rot=(0, s * -0.2, 0))
        kit.paint(ear, BLACK)
        leg = kit.tube(f"pata{s}", [(s * 0.035, -0.06, 0.2), (s * 0.035, -0.08, 0.08), (s * 0.035, -0.09, 0.015)], [(0.018, 0.018)] * 3, levels=1)
        kit.paint(leg, BLACK)
        eye = kit.superellipsoid(f"ojo{s}", (s * 0.02, -0.066, 0.345), (0.009, 0.004, 0.006), e=2.0)
        kit.paint(eye, GOLD)
        out += [ear, leg, eye]
    tail = kit.tube("cola", [(0.06, 0.08, 0.01), (0.1, 0.0, 0.01), (0.08, -0.09, 0.01)], [(0.014, 0.014)] * 3, levels=1)
    kit.paint(tail, BLACK)
    collar = kit.band("collar", 0.265, 0.01, 0.046, 0.051, 2.2, cy=-0.01, grow=0.006, segs=24)
    kit.paint(collar, GOLD)
    ring = kit.lathe("pendiente", [(0.012, -0.003), (0.016, 0.0), (0.012, 0.003)], loc=(0.03, -0.01, 0.35), rot=(0, math.pi / 2, 0), segs=16)
    kit.paint(ring, GOLD)
    return out + [tail, collar, ring]


def obelisco():
    """Un obelisco de granito rojo con su punta de oro y columnas de signos."""
    base = tema.stand_block("zocalo", 0.2, 0.2, 0.04, SAND_DARK)
    shaft = kit.loft("fuste", [(0.04, 0, 0, 0.055, 0.055, 8.0), (0.42, 0, 0, 0.04, 0.04, 8.0)], segs=16, levels=0)
    kit.paint(shaft, RED)
    tip = kit.cylinder("piramidion", (0, 0, 0.45), 0.057, 0.06, r2=0.0, segs=4, rot=(0, 0, math.pi / 4))
    kit.paint(tip, GOLD)
    out = [base, shaft, tip]
    for k in range(6):
        z = 0.1 + k * 0.05
        g = kit.box(f"signo{k}", (0, -0.05 + k * 0.0015, z), (0.02, 0.006, 0.022), bevel=0.002)
        kit.paint(g, INK)
        out.append(g)
    return out


# --- De pie en el suelo ------------------------------------------------------------

def anubis():
    """Anubis sentado sobre su cofre: el chacal negro con collar dorado,
    como en la tumba de Tutankamón."""
    chest = tema.stand_block("cofre", 0.62, 0.36, 0.32, WOOD, bevel=0.015)
    trim = kit.band("cofre_friso", 0.27, 0.025, 0.31, 0.18, 8.0, grow=0.006, segs=16)
    kit.paint(trim, GOLD)
    body = kit.loft("cuerpo", [(0.32, 0, 0.04, 0.12, 0.2, 2.4), (0.4, 0, 0.03, 0.12, 0.19, 2.4), (0.52, 0, -0.02, 0.09, 0.11, 2.3),
                               (0.62, 0, -0.06, 0.06, 0.07, 2.2)], segs=24)
    kit.paint(body, BLACK)
    head = kit.superellipsoid("cabeza", (0, -0.08, 0.7), (0.055, 0.065, 0.055), e=2.2)
    kit.paint(head, BLACK)
    snout = kit.loft("hocico", [(0.0, 0, 0, 0.03, 0.03, 2.2), (0.09, 0, 0, 0.018, 0.02, 2.2)], segs=12, levels=1)
    snout.rotation_euler = (math.pi / 2 + 0.2, 0, 0)
    snout.location = (0, -0.12, 0.69)
    kit.paint(snout, BLACK)
    collar = kit.band("collar", 0.6, 0.02, 0.07, 0.08, 2.2, cy=-0.06, grow=0.01, segs=24)
    kit.paint(collar, GOLD)
    out = [chest, trim, body, head, snout, collar]
    for s in (-1, 1):
        ear = kit.cylinder(f"oreja{s}", (s * 0.03, -0.07, 0.8), 0.0, 0.13, r2=0.025, segs=8, rot=(0.1, s * -0.12, 0))
        kit.paint(ear, BLACK)
        leg = kit.tube(f"pata{s}", [(s * 0.05, -0.12, 0.5), (s * 0.05, -0.17, 0.4), (s * 0.05, -0.2, 0.335)], [(0.022, 0.022)] * 3, levels=1)
        kit.paint(leg, BLACK)
        eye = kit.superellipsoid(f"ojo{s}", (s * 0.028, -0.135, 0.72), (0.01, 0.004, 0.006), e=2.0)
        kit.paint(eye, GOLD)
        out += [ear, leg, eye]
    tail = kit.tube("cola", [(0.0, 0.2, 0.34), (0.08, 0.22, 0.33), (0.16, 0.18, 0.33)], [(0.02, 0.02)] * 3, levels=1)
    kit.paint(tail, BLACK)
    return out + [tail]


def barca():
    """La barca solar en su soporte: casco curvo de madera, cabina y el disco
    del sol."""
    stand = tema.stand_block("soporte", 0.32, 0.18, 0.5, SAND_DARK)
    top = tema.stand_block("repisa", 0.4, 0.22, 0.03, SAND)
    top.location.z = 0.5
    # El casco: una media luna estirada, con popa y proa que suben.
    pts = [(math.cos(a) * 0.38, 0.62 - math.sin(a) * 0.09 + 0.1 * (abs(math.cos(a)) ** 6)) for a in [math.pi * i / 20 for i in range(21)]]
    hull = kit.tube("casco", [(x, 0, z) for x, z in pts], [(0.03 + 0.03 * math.sin(math.pi * i / 20), 0.06 * math.sin(math.pi * i / 20) + 0.015)
                                                           for i in range(21)], levels=1, up=(0, 0, 1))
    kit.paint(hull, WOOD)
    cabin = kit.box("cabina", (0.05, 0, 0.62), (0.16, 0.08, 0.09), bevel=0.01)
    kit.paint(cabin, GOLD_DARK)
    sun = kit.cylinder("sol", (-0.08, 0, 0.72), 0.06, 0.015, rot=(math.pi / 2, 0, 0), segs=24, bevel=0.004)
    kit.paint(sun, RED)
    sun_rim = kit.cylinder("sol_borde", (-0.08, 0.002, 0.72), 0.068, 0.01, rot=(math.pi / 2, 0, 0), segs=24)
    kit.paint(sun_rim, GOLD)
    oar = kit.tube("remo", [(0.3, 0.05, 0.7), (0.34, 0.06, 0.55), (0.36, 0.07, 0.48)], [(0.008, 0.008), (0.008, 0.008), (0.02, 0.006)], levels=1)
    kit.paint(oar, WOOD)
    return [stand, top, hull, cabin, sun, sun_rim, oar]


tema.run("antiguo", [
    ("escarabajo", "case", escarabajo),
    ("canopos", "case", canopos),
    ("amuletos", "case", amuletos),
    ("papiro", "case", papiro),
    ("busto_faraon", "plinth", busto_faraon),
    ("gato_bastet", "plinth", gato_bastet),
    ("obelisco", "plinth", obelisco),
    ("anubis", "floor", anubis),
    ("barca", "floor", barca),
])
