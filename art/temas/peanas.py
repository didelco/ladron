"""Piezas de peana rehechas para verse al aire (antes iban en vitrina y eran
planas o pequeñas): con volumen, altura y color que se lean desde la cámara.

  antiguo      escarabajo (Jepri con el disco solar), canopos (los cuatro)
  edad_media   cáliz (de pie, con su patena), astrolabio (inclinado en su soporte)
  coleccion    amonite (espiral grande sobre su roca), cabeza de Lego (en su proporción)

Sustituye esas piezas en su .blend (pisa sus retoques), ordena la fila,
guarda y exporta. El juego las escala para llenar la peana
(MuseumView._on_pedestal): aquí importan la forma y la proporción.

    Blender -b -P art/temas/peanas.py                    # todas
    Blender -b -P art/temas/peanas.py -- canopos amonite  # esas
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, ".."))
sys.path += [HERE, os.path.join(ART, "characters"), ART]
import kit  # noqa: E402
import tema  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TAU = 2 * math.pi


def m(name, colour, **kw):
    return kit.mat(name, colour, **kw)


def paint(o, mat):
    kit.paint(o, mat)
    return o


# --- Antiguo -------------------------------------------------------------------------

def escarabajo():
    """Jepri: un escarabajo sagrado grande de lapislázuli, con cabeza, patas y
    bordes de oro, empujando el disco solar rojo, sobre un zócalo con una
    franja de jeroglíficos."""
    gold = m("oro", "#e8b53a", rough=0.3, metal=0.7)
    lapis = m("lapislazuli", "#2a4fb0", rough=0.3)
    red = m("disco_solar", "#e0482e", rough=0.4, emit=0.3)
    sand = m("arenisca", "#d9b77a", rough=0.8)
    ink = m("tinta", "#2a1e14", rough=0.8)
    turq = m("turquesa", "#2fb8a8", rough=0.3)
    out = [paint(kit.box("zocalo", (0, 0.02, 0.05), (0.46, 0.38, 0.1), bevel=0.01), sand)]
    out.append(paint(kit.box("franja", (0, -0.171, 0.05), (0.4, 0.004, 0.05)), turq))
    for k in range(7):
        glyph = kit.box(f"glifo{k}", (-0.17 + k * 0.057, -0.174, 0.05), (0.018, 0.004, 0.03 if k % 2 else 0.02))
        out.append(paint(glyph, ink))
    # The body: wing cases split by a gold seam, a gold rim, the thorax.
    body = kit.superellipsoid("elitros", (0, 0.06, 0.19), (0.15, 0.16, 0.09), e=2.3)
    out.append(paint(body, lapis))
    out.append(paint(kit.box("sutura", (0, 0.1, 0.275), (0.012, 0.2, 0.012), bevel=0.004), gold))
    rim = kit.superellipsoid("borde", (0, 0.06, 0.13), (0.158, 0.168, 0.03), e=2.3)
    out.append(paint(rim, gold))
    out.append(paint(kit.superellipsoid("torax", (0, -0.11, 0.2), (0.11, 0.06, 0.07), e=2.4), lapis))
    out.append(paint(kit.superellipsoid("cabeza", (0, -0.18, 0.2), (0.07, 0.04, 0.05), e=2.4), gold))
    for s in (-1, 1):
        for k, y in enumerate((-0.1, 0.0, 0.1)):
            leg = kit.tube(f"pata{s}{k}", [(s * 0.13, y, 0.17), (s * 0.2, y - 0.02, 0.14), (s * 0.21, y - 0.04, 0.1)],
                           [(0.016, 0.016)] * 3, levels=1)
            out.append(paint(leg, gold))
    # The front legs push the sun up in front of it.
    for s in (-1, 1):
        arm = kit.tube(f"brazo{s}", [(s * 0.06, -0.18, 0.2), (s * 0.08, -0.22, 0.3), (s * 0.05, -0.2, 0.37)], [(0.015, 0.015)] * 3, levels=1)
        out.append(paint(arm, gold))
    out.append(paint(kit.cylinder("sol", (0, -0.2, 0.45), 0.1, 0.035, rot=(math.pi / 2, 0, 0), segs=32, bevel=0.006), red))
    out.append(paint(kit.cylinder("aro_sol", (0, -0.2, 0.45), 0.108, 0.02, rot=(math.pi / 2, 0, 0), segs=32), gold))
    return out


def canopos():
    """Los cuatro vasos canopos, en su cofre de madera, dos delante y dos
    detrás: tapas de los cuatro hijos de Horus, humana, de babuino, de
    chacal y de halcón, cada una de su color."""
    alabaster = m("alabastro", "#efe4cc", rough=0.5)
    lapis = m("lapislazuli", "#2a4fb0", rough=0.3)
    gold = m("oro", "#e8b53a", rough=0.3, metal=0.7)
    wood = m("madera", "#7a4a26", rough=0.7)
    skin = m("piel_estatua", "#c07a44", rough=0.6)
    grey = m("babuino", "#8a8a90", rough=0.6)
    black = m("chacal", "#1c1b22", rough=0.4)
    falcon = m("halcon", "#a0703a", rough=0.6)
    turq = m("turquesa", "#2fb8a8", rough=0.3)
    out = [paint(kit.box("cofre", (0, 0, 0.04), (0.46, 0.46, 0.08), bevel=0.01), wood)]
    out.append(paint(kit.box("filo", (0, 0, 0.083), (0.47, 0.47, 0.006)), gold))
    spots = ((-0.11, -0.11, "humana"), (0.11, -0.11, "halcon"), (-0.11, 0.11, "babuino"), (0.11, 0.11, "chacal"))
    for i, (x, y, lid) in enumerate(spots):
        jar = kit.lathe(f"vaso{i}", [(0.0, 0.0), (0.05, 0.0), (0.075, 0.05), (0.08, 0.15), (0.068, 0.24), (0.05, 0.27), (0.0, 0.27)],
                        loc=(x, y, 0.086))
        out.append(paint(kit.smooth_shade(jar), alabaster))
        band = kit.band(f"franja{i}", 0.17, 0.012, 0.081, 0.081, 2.0, grow=0.002, segs=32)
        band.location.x, band.location.y = x, y
        out.append(paint(band, lapis))
        z = 0.086 + 0.27 + 0.055
        colour = {"humana": skin, "halcon": falcon, "babuino": grey, "chacal": black}[lid]
        out.append(paint(kit.superellipsoid(f"tapa{i}", (x, y, z), (0.06, 0.06, 0.06), e=2.1), colour))
        if lid == "humana":
            # A striped nemes headdress.
            out.append(paint(kit.superellipsoid(f"nemes{i}", (x, y + 0.012, z + 0.01), (0.068, 0.062, 0.058), e=2.2), lapis))
            out.append(paint(kit.superellipsoid(f"cara{i}", (x, y - 0.04, z - 0.005), (0.04, 0.02, 0.045), e=2.2), skin))
            for s in (-1, 1):
                out.append(paint(kit.box(f"lapa{i}{s}", (x + s * 0.06, y - 0.01, z - 0.05), (0.02, 0.03, 0.08)), gold))
        elif lid == "halcon":
            out.append(paint(kit.cylinder(f"pico{i}", (x, y - 0.065, z - 0.01), 0.022, 0.05, r2=0.0, rot=(math.pi / 2, 0, 0), segs=8), gold))
            out.append(paint(kit.box(f"ojos{i}", (x, y - 0.052, z + 0.012), (0.08, 0.006, 0.012)), turq))
        elif lid == "babuino":
            out.append(paint(kit.superellipsoid(f"hocico{i}", (x, y - 0.06, z - 0.015), (0.032, 0.03, 0.026), e=2.2), grey))
            out.append(paint(kit.superellipsoid(f"melena{i}", (x, y + 0.02, z - 0.03), (0.075, 0.05, 0.04), e=2.2), grey))
        else:
            for s in (-1, 1):
                out.append(paint(kit.cylinder(f"oreja{i}{s}", (x + s * 0.028, y, z + 0.07), 0.02, 0.06, r2=0.0, segs=8), black))
            out.append(paint(kit.superellipsoid(f"hocico{i}", (x, y - 0.065, z - 0.012), (0.022, 0.045, 0.022), e=2.2), black))
            out.append(paint(kit.box(f"collar{i}", (x, y, z - 0.055), (0.1, 0.1, 0.015)), gold))
    return out


# --- Edad Media ----------------------------------------------------------------------

def caliz():
    """Un cáliz alto de plata dorada, con nudo de esmaltes y pedrería, de pie
    sobre un paño de terciopelo, y la patena apoyada detrás."""
    gold = m("oro", "#e8b53a", rough=0.3, metal=0.7)
    silver = m("plata", "#c9ced8", rough=0.3, metal=0.7)
    velvet = m("terciopelo", "#6a1f2e", rough=0.9)
    ruby = m("rubi", "#d0263e", rough=0.2)
    sapphire = m("zafiro", "#2f6fe0", rough=0.2)
    emerald = m("esmeralda", "#23a861", rough=0.2)
    out = [paint(kit.superellipsoid("pano", (0, 0.02, 0.02), (0.22, 0.2, 0.02), e=3.5), velvet)]
    cup = kit.lathe("caliz", [(0.0, 0.04), (0.12, 0.04), (0.13, 0.055), (0.05, 0.09), (0.028, 0.14), (0.03, 0.2), (0.022, 0.26),
                               (0.03, 0.29), (0.1, 0.33), (0.115, 0.46), (0.105, 0.47), (0.09, 0.35), (0.0, 0.34)], segs=48)
    out.append(paint(kit.smooth_shade(cup), gold))
    out.append(paint(kit.superellipsoid("nudo", (0, 0, 0.2), (0.05, 0.05, 0.03), e=2.2), silver))
    gems = [ruby, sapphire, emerald]
    for k in range(6):
        a = k / 6 * TAU
        out.append(paint(kit.superellipsoid(f"gema{k}", (math.cos(a) * 0.05, math.sin(a) * 0.05, 0.2), (0.012, 0.012, 0.012), e=2.0), gems[k % 3]))
        out.append(paint(kit.superellipsoid(f"piedra{k}", (math.cos(a) * 0.112, math.sin(a) * 0.112, 0.4), (0.014, 0.014, 0.018), e=2.0),
                         gems[(k + 1) % 3]))
    for k in range(6):
        a = k / 6 * TAU + 0.5
        out.append(paint(kit.superellipsoid(f"pie_gema{k}", (math.cos(a) * 0.09, math.sin(a) * 0.09, 0.065), (0.012, 0.012, 0.01), e=2.0),
                         gems[k % 3]))
    paten = kit.cylinder("patena", (0.0, 0.16, 0.14), 0.12, 0.012, rot=(1.2, 0, 0), segs=40, bevel=0.003)
    out.append(paint(paten, gold))
    return out


def astrolabio():
    """Un astrolabio de latón, grande, inclinado hacia quien mira en su
    soporte de madera: la madre con su escala, la red calada con las
    estrellas, la regla y la argolla."""
    brass = m("laton", "#d8a440", rough=0.35, metal=0.6)
    brass_dark = m("laton_oscuro", "#9a7020", rough=0.4, metal=0.5)
    blue = m("esfera_celeste", "#1f3f8a", rough=0.5)
    wood = m("madera", "#6e4424", rough=0.7)
    star = m("estrella", "#fff2c0", rough=0.3, emit=0.4)
    # Leant back from upright, its face to whoever looks (from above).
    tilt = 0.9
    c = (0, 0.02, 0.3)

    parts = [paint(kit.box("base", (0, 0.04, 0.03), (0.34, 0.26, 0.06), bevel=0.01), wood)]
    for s in (-1, 1):
        parts.append(paint(kit.box(f"brazo{s}", (s * 0.2, 0.04, 0.18), (0.03, 0.05, 0.3), bevel=0.006), wood))
    disc = []
    disc.append(paint(kit.cylinder("madre", (0, 0, 0), 0.2, 0.025, segs=64, bevel=0.004), brass))
    disc.append(paint(kit.cylinder("lamina", (0, 0, 0.014), 0.17, 0.004, segs=64), blue))
    disc.append(paint(kit.lathe("limbo", [(0.17, 0.012), (0.2, 0.012), (0.2, 0.022), (0.17, 0.022)], segs=64), brass_dark))
    for k in range(24):
        a = k / 24 * TAU
        disc.append(paint(kit.box(f"marca{k}", (math.cos(a) * 0.185, math.sin(a) * 0.185, 0.024), (0.004, 0.02 if k % 2 else 0.012, 0.003),
                                  rot=(0, 0, a + math.pi / 2)), brass_dark))
    # The rete: a ring for the ecliptic, pointers to the stars.
    disc.append(paint(kit.lathe("ecliptica", [(0.09, 0.018), (0.105, 0.018), (0.105, 0.026), (0.09, 0.026)], loc=(0.03, 0.02, 0), segs=48), brass))
    for k in range(7):
        a = k / 7 * TAU + 0.3
        r = 0.12 + 0.03 * (k % 2)
        disc.append(paint(kit.box(f"puntero{k}", (math.cos(a) * r / 2, math.sin(a) * r / 2, 0.022), (r, 0.008, 0.004), rot=(0, 0, a)), brass))
        disc.append(paint(kit.superellipsoid(f"estrella{k}", (math.cos(a) * r, math.sin(a) * r, 0.026), (0.012, 0.012, 0.006), e=2.0), star))
    disc.append(paint(kit.box("regla", (0, 0, 0.03), (0.38, 0.018, 0.006), rot=(0, 0, 0.6)), brass_dark))
    disc.append(paint(kit.cylinder("eje", (0, 0, 0.03), 0.016, 0.02, segs=16), brass_dark))
    disc.append(paint(kit.cylinder("trono", (0, 0.215, 0), 0.035, 0.025, segs=24), brass))
    ring = kit.lathe("argolla", [(0.03, -0.006), (0.04, -0.006), (0.04, 0.006), (0.03, 0.006)], loc=(0, 0.26, 0), rot=(math.pi / 2, 0, 0), segs=24)
    disc.append(paint(ring, brass))
    pivot = kit.empty("disco")
    kit.parent_all(pivot, disc)
    # Built lying face up: stood up, face to the front, leant back.
    pivot.location = c
    pivot.rotation_euler = (tilt, 0, 0)
    return parts + disc + [pivot]


# --- La colección ----------------------------------------------------------------------

def amonite():
    """Una amonite grande, de canto sobre su trozo de roca: la espiral con sus
    costillas, en tonos de nácar y ocre."""
    shell = m("concha_amonite", "#d8a86a", rough=0.5)
    rib = m("costilla", "#a8743e", rough=0.6)
    pearl = m("nacar", "#f0dcc0", rough=0.3)
    rock = m("roca", "#6e6258", rough=0.9)
    out = [paint(kit.superellipsoid("roca", (0, 0.02, 0.06), (0.2, 0.16, 0.07), e=2.2), rock)]
    # The spiral, face to the front (-Y), standing on its edge.
    turns = 2.6
    steps = 90
    pts, radii = [], []
    for k in range(steps + 1):
        t = k / steps
        a = t * turns * TAU
        r = 0.02 + 0.17 * t
        pts.append((math.cos(a) * r * (1 - t * 0.15), 0.0, 0.3 + math.sin(a) * r))
        w = 0.008 + 0.055 * t
        radii.append((w, w * 1.1))
    spiral = kit.tube("espiral", pts, radii, segs=14, levels=1, up=(0, 1, 0))
    out.append(kit.paint_regions(spiral, [(rib, lambda c, n: int(math.floor(math.atan2(c.z - 0.3, c.x) / 0.22)) % 2 == 0)], shell))
    out.append(paint(kit.superellipsoid("ombligo", (0, -0.01, 0.3), (0.03, 0.03, 0.03), e=2.0), pearl))
    shine = []
    for k, (x, z) in enumerate(((0.12, 0.2), (-0.1, 0.4), (0.05, 0.45))):
        shine.append(paint(kit.superellipsoid(f"brillo{k}", (x, -0.05, z), (0.02, 0.006, 0.014), e=2.0), pearl))
    # Leant back on its rock, its face up to whoever looks from above.
    shell_parts = out[1:] + shine
    pivot = kit.empty("inclinacion")
    kit.parent_all(pivot, shell_parts)
    pivot.location = (0, -0.16, -0.05)
    pivot.rotation_euler = (-0.75, 0, 0)
    return [out[0]] + shell_parts + [pivot]


def craneo_lego():
    """La cabeza de una minifigura de Lego con una calavera impresa, con sus
    proporciones: lados rectos y cantos redondeados, tan alta como ancha,
    la espiga hueca encima (la mitad de ancha) y el cuello debajo."""
    white = m("plastico_blanco", "#f4f3ee", rough=0.2, coat=0.6)
    ink = m("impresion", "#141418", rough=0.3)
    grey = m("impresion_gris", "#8a8a94", rough=0.3)
    r = 0.12  # the head's radius (D = 0.24)
    neck, body, fillet = 0.035, 0.23, 0.028
    z0, z1 = neck, neck + body
    prof = [(0.0, z0)]
    for k in range(7):
        a = math.pi / 2 * k / 6
        prof.append((r - fillet + fillet * math.sin(a), z0 + fillet - fillet * math.cos(a)))
    for k in range(7):
        a = math.pi / 2 * k / 6
        prof.append((r - fillet + fillet * math.cos(a), z1 - fillet + fillet * math.sin(a)))
    prof.append((0.0, z1))
    head = kit.smooth_shade(kit.lathe("cabeza", prof, segs=48))
    out = [paint(head, white)]
    out.append(paint(kit.cylinder("cuello", (0, 0, neck / 2), 0.06, neck, segs=32), white))
    # The stud: a hollow tube, half as wide as the head.
    stud = kit.lathe("espiga", [(0.042, z1 + 0.012), (0.062, z1 - 0.002), (0.062, z1 + 0.036), (0.058, z1 + 0.04),
                                (0.046, z1 + 0.04), (0.042, z1 + 0.036)], segs=40)
    out.append(paint(kit.smooth_shade(stud), white))
    # The print: big round eye sockets, a nose, a grin of teeth.
    mid = z0 + body * 0.52
    for sx in (-1, 1):
        eye = kit.decal(f"ojo{sx}", kit.ellipse(0.032, 0.038), [head], at=(sx * 0.044, mid + 0.024), lift=0.0008, thickness=0.003)
        out.append(paint(eye, ink))
        glint = kit.decal(f"brillo{sx}", kit.ellipse(0.008, 0.009), [eye], at=(sx * 0.044 + 0.009, mid + 0.038), lift=0.0006, thickness=0.002, res=16)
        out.append(paint(glint, grey))
    nose = kit.decal("nariz", [(-0.016, -0.014), (0.016, -0.014), (0.0, 0.014)], [head], at=(0, mid - 0.026), lift=0.0008, thickness=0.003, res=16)
    out.append(paint(nose, ink))
    mouth = kit.decal("boca", [(-0.058, -0.026), (0.058, -0.026), (0.064, -0.018), (0.064, 0.018), (0.058, 0.026), (-0.058, 0.026),
                                (-0.064, 0.018), (-0.064, -0.018)], [head], at=(0, mid - 0.07), lift=0.0008, thickness=0.003)
    out.append(paint(mouth, ink))
    for row, dz in enumerate((0.011, -0.011)):
        for k in range(5):
            x = -0.046 + k * 0.023
            tooth = kit.decal(f"diente{row}{k}", [(-0.009, -0.008), (0.009, -0.008), (0.009, 0.008), (-0.009, 0.008)], [mouth],
                              at=(x, mid - 0.07 + dz), lift=0.0006, thickness=0.002, res=12)
            out.append(paint(tooth, white))
    return out


FILES = {
    "tema_antiguo.blend": ("temas/antiguo", [("escarabajo", escarabajo), ("canopos", canopos)]),
    "tema_edad_media.blend": ("temas/edad_media", [("caliz", caliz), ("astrolabio", astrolabio)]),
    "coleccion.blend": ("", [("amonite", amonite), ("craneo_lego", craneo_lego)]),
}

done = []
for file, (out, pieces) in FILES.items():
    wanted = [(n, f) for n, f in pieces if not ARGS or n in ARGS]
    if wanted:
        done += tema.replace(os.path.join(ART, file), out, wanted, lambda n: "plinth")
print("[peanas]", len(done), "piezas:", ", ".join(done))
