"""Edad moderna: arte contemporáneo y cosas de hoy expuestas como piezas de
museo. Todas se leen desde arriba por la silueta y el color.

  peana   tele de tubo (pantalla encendida, antena de cuernos), tostadora con
          dos tostadas saltando, cubo de Rubik de pie sobre una esquina,
          perro-globo
  suelo   máquina recreativa, móvil de Calder, semáforo de cuatro caras
  grande  cochecito de los sesenta en su tarima de exposición (3×2), con la
          puerta entreabierta: un escondite (Hideouts.BIG)

Añade cada pieza a art/tema_moderna.blend (si ya estaba, la sustituye: pisa
sus retoques), ordena la fila, guarda y exporta. El juego escala las de peana
para llenarla (MuseumView._on_pedestal): ahí importan forma y proporción.

    Blender -b -P art/temas/moderna.py                 # todas
    Blender -b -P art/temas/moderna.py -- tele coche   # esas

Así se hizo la primera versión; después se retocan a mano en el .blend y salen
con art/export.py.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, ".."))
sys.path += [HERE, os.path.join(ART, "characters"), ART]
from mathutils import Vector  # noqa: E402

import kit  # noqa: E402
import tema  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TAU = 2 * math.pi


def m(name, colour, **kw):
    return kit.mat(name, colour, **kw)


def paint(o, mat):
    kit.paint(o, mat)
    return o


def rod(name, a, b, r, segs=12):
    """Un cilindro de a a b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    return kit.cylinder(name, tuple((a + b) / 2), r, d.length, rot=tuple(rot), segs=segs)


def puff(name, a, b, r, segs=24):
    """Un tramo de globo de a a b: un huso redondo, estrecho en las puntas."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    return kit.sphere(name, tuple((a + b) / 2), (r, r, d.length / 2 + r * 0.35), rot=tuple(rot), segs=segs)


# --- Peana ---------------------------------------------------------------------------

def tele():
    """Una tele de tubo de los setenta: mueble de madera, pantalla abombada
    encendida (azul, brilla en la oscuridad), panel de botones, patas
    abiertas y antena de cuernos."""
    wood = m("madera_tele", "#8a5a32", rough=0.6)
    wood_dark = m("madera_oscura", "#5a3a20", rough=0.7)
    screen = m("pantalla", "#6fd6ff", rough=0.2, emit=1.2)
    bezel = m("marco", "#2a2a30", rough=0.6)
    silver = m("plata", "#c8ccd4", rough=0.3, metal=0.6)
    knob = m("boton", "#ff4f9a", rough=0.4)
    w, d, h, lift = 0.46, 0.34, 0.34, 0.1
    out = [paint(kit.superellipsoid("mueble", (0, 0, lift + h / 2), (w / 2, d / 2, h / 2), e=6.0), wood)]
    # The picture tube: a dark bezel, the lit screen bulging out of it.
    out.append(paint(kit.superellipsoid("bisel", (-0.05, -d / 2 + 0.01, lift + h / 2), (0.15, 0.02, 0.125), e=4.5), bezel))
    out.append(paint(kit.superellipsoid("pantalla", (-0.05, -d / 2 - 0.004, lift + h / 2), (0.13, 0.022, 0.105), e=4.0), screen))
    # The control panel to its right: two knobs and a speaker grille.
    out.append(paint(kit.box("panel", (0.16, -d / 2 + 0.004, lift + h / 2), (0.09, 0.012, 0.26), bevel=0.006), wood_dark))
    for k, z in enumerate((0.1, 0.03)):
        out.append(paint(kit.cylinder(f"mando{k}", (0.16, -d / 2 - 0.012, lift + h / 2 + z), 0.024, 0.03, rot=(math.pi / 2, 0, 0), segs=16), knob))
    for k in range(4):
        out.append(paint(kit.box(f"rejilla{k}", (0.16, -d / 2 - 0.004, lift + 0.07 + k * 0.022), (0.06, 0.006, 0.008)), bezel))
    # Splayed legs.
    for sx in (-1, 1):
        for sy in (-1, 1):
            out.append(paint(rod(f"pata{sx}{sy}", (sx * 0.17, sy * 0.1, lift + 0.01), (sx * 0.2, sy * 0.13, 0.0), 0.014, segs=8), wood_dark))
    # Rabbit ears: a little dome, two long rods in a V, a ball on each tip.
    top = lift + h
    out.append(paint(kit.sphere("base_antena", (0.02, 0.04, top), (0.05, 0.05, 0.03), segs=24), bezel))
    for s in (-1, 1):
        tip = (0.02 + s * 0.2, 0.08, top + 0.3)
        out.append(paint(rod(f"antena{s}", (0.02, 0.04, top + 0.02), tip, 0.006, segs=8), silver))
        out.append(paint(kit.sphere(f"punta{s}", tip, (0.014, 0.014, 0.014), segs=12), silver))
    return out


def tostadora():
    """Una tostadora retro roja, de cantos muy redondos, con dos tostadas
    saltando por las ranuras, la palanca y la rueda del tostado."""
    body_c = m("roja", "#e8404a", rough=0.3, coat=0.6)
    chrome = m("cromo", "#e0e4ea", rough=0.15, metal=0.9)
    slot = m("ranura", "#1c1a1e", rough=0.9)
    bread = m("miga", "#f0c878", rough=0.9)
    crust = m("corteza_pan", "#a8642a", rough=0.9)
    black = m("negro", "#26242a", rough=0.6)
    w, d, h = 0.42, 0.26, 0.26
    out = [paint(kit.superellipsoid("cuerpo", (0, 0, h / 2 + 0.02), (w / 2, d / 2, h / 2), e=4.5), body_c)]
    out.append(paint(kit.box("zocalo", (0, 0, 0.012), (w * 0.94, d * 0.9, 0.024), bevel=0.008), chrome))
    out.append(paint(kit.band("franja", h * 0.45, 0.012, w / 2, d / 2, 4.5, grow=0.004), chrome))
    for k, x in enumerate((-0.09, 0.09)):
        out.append(paint(kit.box(f"ranura{k}", (x, 0, h + 0.015), (0.05, 0.19, 0.02), bevel=0.006), slot))
        # The toast, half out and leaning a little: crust round the edge.
        tilt = (0.1 if k else -0.14, 0, 0)
        z = h + 0.08
        out.append(paint(kit.box(f"corteza{k}", (x, 0, z), (0.028, 0.18, 0.17), rot=tilt, bevel=0.012), crust))
        out.append(paint(kit.box(f"tostada{k}", (x, 0, z + 0.004), (0.032, 0.155, 0.15), rot=tilt, bevel=0.01), bread))
    # The lever and the browning dial on the front.
    out.append(paint(kit.box("guia", (w / 2 - 0.07, -d / 2 + 0.004, h * 0.6), (0.014, 0.01, 0.13)), slot))
    out.append(paint(kit.box("palanca", (w / 2 - 0.07, -d / 2 - 0.02, h * 0.5), (0.05, 0.04, 0.022), bevel=0.008), black))
    out.append(paint(kit.cylinder("rueda", (-w / 2 + 0.08, -d / 2 - 0.006, h * 0.45), 0.026, 0.016, rot=(math.pi / 2, 0, 0), segs=20), black))
    return out


RUBIK = ["#ffffff", "#ffd400", "#e8303a", "#ff8a1c", "#2a6ef0", "#1eb85a"]


def rubik():
    """Un cubo de Rubik a medio resolver, de pie sobre una esquina en un
    soporte de cromo: desde arriba se ven tres caras de colores."""
    black = m("plastico_negro", "#18161c", rough=0.5)
    chrome = m("cromo", "#e0e4ea", rough=0.15, metal=0.9)
    stickers = [m(f"pegatina{i}", c, rough=0.35) for i, c in enumerate(RUBIK)]
    s = 0.3
    cell = s / 3
    parts = [paint(kit.box("nucleo", (0, 0, 0), (s, s, s), bevel=0.012), black)]
    # Six faces, nine stickers each; a scramble that never repeats a colour
    # next to itself, so it reads as a puzzle and not as a block.
    faces = [((0, 0, 1), 0), ((0, 0, -1), 1), ((0, -1, 0), 2), ((0, 1, 0), 3), ((1, 0, 0), 4), ((-1, 0, 0), 5)]
    for f, (n, own) in enumerate(faces):
        n = Vector(n)
        u = Vector((1, 0, 0)) if abs(n.x) < 0.5 else Vector((0, 1, 0))
        v = n.cross(u)
        for i in range(3):
            for j in range(3):
                pick = own if (i + j * 2 + f) % 3 == 0 else (own + 1 + (i * 3 + j + f * 2) % 5) % 6
                c = n * (s / 2 + 0.002) + u * ((i - 1) * cell) + v * ((j - 1) * cell)
                size = Vector((abs(u.x), abs(u.y), abs(u.z))) * cell * 0.86 + Vector((abs(v.x), abs(v.y), abs(v.z))) * cell * 0.86 + \
                    Vector((abs(n.x), abs(n.y), abs(n.z))) * 0.006
                parts.append(paint(kit.box(f"pegatina{f}{i}{j}", tuple(c), tuple(size), bevel=0.004, segs=1), stickers[pick]))
    cube = kit.empty("cubo")
    kit.parent_all(cube, parts)
    # On a corner: the long diagonal straight up.
    corner = math.sqrt(3) / 2 * s
    cube.rotation_mode = "QUATERNION"
    cube.rotation_quaternion = Vector((1, 1, 1)).normalized().rotation_difference(Vector((0, 0, 1)))
    cube.location = (0, 0, 0.06 + corner - 0.012)
    out = [paint(kit.lathe("soporte", [(0.0, 0.0), (0.12, 0.0), (0.12, 0.012), (0.03, 0.03), (0.02, 0.06), (0.0, 0.06)], segs=32), chrome)]
    return out + parts + [cube]


def perro_globo():
    """El perro-globo de acero espejo (el de las subastas): rosa brillante,
    hecho de tramos de globo redondos, con su hocico, orejas y rabo."""
    pink = m("globo_rosa", "#ff4f9a", rough=0.1, coat=1.0)
    parts = []

    def p(name, a, b, r=0.045):
        parts.append(paint(puff(name, a, b, r), pink))

    # Legs, splayed out; the body between them; the tail pointing up.
    for sy in (-1, 1):
        p(f"pata_del{sy}", (-0.12, sy * 0.045, 0.2), (-0.14, sy * 0.1, 0.04))
        p(f"pata_tra{sy}", (0.14, sy * 0.045, 0.2), (0.16, sy * 0.1, 0.04))
    p("cuerpo", (-0.12, 0, 0.21), (0.14, 0, 0.21), 0.05)
    p("rabo", (0.15, 0, 0.23), (0.2, 0, 0.33), 0.035)
    # The neck up, the head forward, the snout out; two ears back.
    p("cuello", (-0.13, 0, 0.22), (-0.16, 0, 0.34))
    p("cabeza", (-0.17, 0, 0.36), (-0.12, 0, 0.4), 0.05)
    p("hocico", (-0.19, 0, 0.36), (-0.3, 0, 0.35), 0.04)
    for sy in (-1, 1):
        p(f"oreja{sy}", (-0.14, sy * 0.03, 0.4), (-0.08, sy * 0.06, 0.46), 0.032)
    # The knots where the tramos twist.
    for k, at in enumerate(((-0.13, 0, 0.22), (0.14, 0, 0.21), (-0.16, 0, 0.35))):
        parts.append(paint(kit.sphere(f"nudo{k}", at, (0.05, 0.05, 0.05), segs=24), pink))
    return parts


# --- Suelo ---------------------------------------------------------------------------

def recreativa():
    """Una máquina recreativa de los ochenta: mueble morado de lados
    inclinados, cartel luminoso arriba, pantalla encendida, mandos con su
    palanca y botones, y la ranura de las monedas."""
    purple = m("morado", "#7a3ce0", rough=0.5)
    purple_dark = m("morado_oscuro", "#4a2290", rough=0.6)
    black = m("negro", "#1a1820", rough=0.6)
    screen = m("pantalla_juego", "#3cffb0", rough=0.2, emit=1.3)
    marquee = m("cartel", "#ffd400", rough=0.3, emit=1.0)
    red = m("rojo", "#ff3a4a", rough=0.3)
    cyan = m("cian", "#00c2d8", rough=0.3)
    coin = m("monedero", "#ff9a1c", rough=0.3, emit=0.6)
    w = 0.58
    # The side, seen from +X: the foot at the back, the control panel
    # sticking out at the front (-Y), the screen leaning back, the marquee on top.
    side = [(0.26, 0.0), (-0.26, 0.0), (-0.26, 0.5), (-0.32, 0.56), (-0.3, 0.62), (-0.18, 0.66), (-0.12, 0.94), (-0.16, 1.0),
            (-0.16, 1.08), (0.26, 1.08)]
    out = []
    for sx in (-1, 1):
        panel = kit.slab(f"lado{sx}", side, 0.03, loc=(sx * (w / 2 - 0.015), 0, 0), rot=(0, 0, math.pi / 2), bevel=0.006)
        out.append(paint(panel, purple))
    out.append(paint(kit.box("fondo", (0, 0.05, 0.54), (w - 0.06, 0.4, 1.06)), purple_dark))
    out.append(paint(kit.box("frente", (0, -0.25, 0.25), (w - 0.06, 0.02, 0.5)), purple_dark))
    # The control panel: a sloped board with the stick and four buttons.
    board = kit.box("tablero", (0, -0.25, 0.6), (w - 0.06, 0.16, 0.03), rot=(-0.3, 0, 0))
    out.append(paint(board, black))
    out.append(paint(rod("palanca", (-0.12, -0.26, 0.62), (-0.12, -0.27, 0.7), 0.008, segs=8), black))
    out.append(paint(kit.sphere("bola", (-0.12, -0.27, 0.71), (0.025, 0.025, 0.025), segs=16), red))
    for k in range(4):
        c = cyan if k % 2 else red
        out.append(paint(kit.cylinder(f"boton{k}", (0.03 + k * 0.055, -0.26 + (k % 2) * 0.02, 0.625), 0.016, 0.02, rot=(-0.3, 0, 0), segs=12), c))
    # The screen, leaning back between the sides, and its black bezel.
    tilt = (math.atan2(0.06, 0.28), 0, 0)
    out.append(paint(kit.box("bisel", (0, -0.155, 0.8), (w - 0.07, 0.02, 0.3), rot=tilt), black))
    out.append(paint(kit.box("pantalla", (0, -0.165, 0.8), (w - 0.16, 0.012, 0.23), rot=tilt, bevel=0.01), screen))
    # The marquee, lit, across the top at the front.
    out.append(paint(kit.box("cartel", (0, -0.165, 1.04), (w - 0.06, 0.02, 0.08)), marquee))
    # A lit lid: from above, and from behind, it still reads as the machine.
    out.append(paint(kit.box("techo", (0, 0.05, 1.07), (w, 0.44, 0.02)), marquee))
    # The coin door.
    out.append(paint(kit.box("puerta", (0, -0.262, 0.28), (0.16, 0.006, 0.2), bevel=0.004), black))
    for k, x in enumerate((-0.035, 0.035)):
        out.append(paint(kit.box(f"moneda{k}", (x, -0.266, 0.32), (0.03, 0.006, 0.045), bevel=0.004), coin))
    return out


def movil_calder():
    """Un móvil de Calder de pie: base negra de chapa, un mástil y brazos de
    alambre en equilibrio con discos de colores planos, que desde arriba se
    ven enteros."""
    black = m("chapa_negra", "#1c1a20", rough=0.5)
    wire = m("alambre", "#26242a", rough=0.5)
    discs = {"rojo": m("disco_rojo", "#e8303a", rough=0.4), "amarillo": m("disco_amarillo", "#ffd400", rough=0.4),
             "azul": m("disco_azul", "#2a5ee8", rough=0.4), "blanco": m("disco_blanco", "#f4f2ec", rough=0.4),
             "negro": black}
    out = []
    # The stabile: three sheet-metal fins meeting under the mast.
    for k in range(3):
        a = k * TAU / 3
        fin = kit.slab(f"aleta{k}", [(0.0, 0.0), (0.3, 0.0), (0.0, 0.55)], 0.012, rot=(0, 0, a))
        out.append(paint(fin, black))
    out.append(paint(rod("mastil", (0, 0, 0.5), (0, 0, 0.82), 0.01), wire))

    def arm(name, pivot, left, right):
        """A wire from left to right balanced on pivot (hung from it by a
        short drop), each end with a disc or another arm."""
        out.append(paint(rod(name, left, right, 0.006, segs=6), wire))
        out.append(paint(rod(name + "_cuelga", pivot, (pivot[0], pivot[1], left[2] + (right[2] - left[2]) * 0.4), 0.004, segs=6), wire))

    def disc(name, at, r, colour, tilt):
        out.append(paint(kit.cylinder(name, at, r, 0.012, rot=tilt, segs=28), discs[colour]))

    # Level one: across the mast top, a big red disc against the rest.
    top = (0, 0, 0.82)
    arm("brazo1", top, (-0.36, 0.05, 0.8), (0.3, -0.05, 0.84))
    disc("disco_grande", (-0.3, 0.1, 0.78), 0.1, "rojo", (0.25, 0.1, 0))
    # Level two, hanging from its right end: two discs and a third arm.
    arm("brazo2", (0.3, -0.05, 0.84), (0.1, -0.2, 0.96), (0.38, 0.1, 0.94))
    disc("disco_amarillo", (0.36, 0.14, 0.94), 0.07, "amarillo", (-0.2, 0.3, 0))
    arm("brazo3", (0.1, -0.2, 0.96), (-0.12, -0.3, 1.04), (0.2, -0.32, 1.06))
    disc("disco_azul", (-0.14, -0.3, 1.02), 0.075, "azul", (0.3, -0.2, 0))
    disc("disco_blanco", (0.24, -0.33, 1.06), 0.05, "blanco", (-0.1, 0.2, 0))
    # And a small black one hanging under the first arm.
    out.append(paint(rod("cuelga_negro", (-0.14, 0.03, 0.81), (-0.14, 0.03, 0.69), 0.004, segs=6), wire))
    disc("disco_negro", (-0.14, 0.03, 0.68), 0.055, "negro", (0.3, 0, 0))
    return out


def semaforo():
    """Un semáforo de cruce como obra de arte: pintado de amarillo pop, con
    las tres luces encendidas en las cuatro caras (así se ve desde cualquier
    lado) y una tapa roja arriba."""
    yellow = m("amarillo_pop", "#ffd400", rough=0.4)
    black = m("negro", "#1a1820", rough=0.6)
    grey = m("hormigon", "#9aa0aa", rough=0.9)
    lights = [m("luz_roja", "#ff3040", rough=0.2, emit=1.4), m("luz_ambar", "#ffa81c", rough=0.2, emit=1.4),
              m("luz_verde", "#28e070", rough=0.2, emit=1.4)]
    pink = m("rosa_pop", "#ff4f9a", rough=0.4)
    out = [paint(kit.box("base", (0, 0, 0.04), (0.4, 0.4, 0.08), bevel=0.01), grey)]
    # The pole, in pop stripes.
    for k in range(5):
        c = yellow if k % 2 == 0 else black
        out.append(paint(kit.cylinder(f"poste{k}", (0, 0, 0.08 + 0.055 + k * 0.11), 0.035, 0.11, segs=16), c))
    head_z, head_h = 0.63, 0.42
    out.append(paint(kit.box("caja", (0, 0, head_z + head_h / 2), (0.24, 0.24, head_h), bevel=0.02), yellow))
    for f in range(4):
        a = f * math.pi / 2
        n = Vector((math.sin(a), -math.cos(a), 0))
        for i, lamp in enumerate(lights):
            z = head_z + head_h - 0.075 - i * 0.135
            c = n * 0.122
            out.append(paint(kit.cylinder(f"luz{f}{i}", (c.x, c.y, z), 0.045, 0.012, rot=(math.pi / 2, 0, a), segs=20), lamp))
            v = n * 0.15
            visor = kit.cylinder(f"visera{f}{i}", (v.x, v.y, z + 0.03), 0.052, 0.05, rot=(math.pi / 2, 0, a), segs=20)
            kit.delete_faces(visor, lambda c, top=z + 0.03: c.z < top - 0.005)
            out.append(paint(visor, black))
    out.append(paint(kit.superellipsoid("tapa", (0, 0, head_z + head_h + 0.02), (0.14, 0.14, 0.03), e=3.0), pink))
    return out


# --- Grande --------------------------------------------------------------------------

def coche():
    """Un cochecito de los sesenta (de los que cabía la familia entera) en su
    tarima de exposición: cian con el techo blanco, faros redondos, tapacubos
    de cromo, y la puerta de este lado entreabierta, para colarse dentro. A lo
    largo de X, el morro a -X; cabe en 3×2 casillas."""
    body_c = m("cian_coche", "#1ec8d8", rough=0.3, coat=0.8)
    white = m("blanco_techo", "#f6f4ee", rough=0.4)
    glass = m("cristal", "#2a3e52", rough=0.1)
    chrome = m("cromo", "#e0e4ea", rough=0.15, metal=0.9)
    tyre = m("rueda", "#1c1b20", rough=0.9)
    lamp = m("faro", "#fff4c0", rough=0.2, emit=1.2)
    tail = m("piloto", "#ff3040", rough=0.2, emit=0.8)
    inside = m("interior", "#3a2a2a", rough=0.9)
    seat = m("asiento", "#c8402e", rough=0.8)
    stage = m("tarima", "#d8d8e0", rough=0.8)
    stripe = m("franja_tarima", "#ff4f9a", rough=0.5)
    L, W = 2.3, 1.1
    deck = 0.08
    out = [paint(kit.box("tarima", (0, 0, deck / 2), (2.8, 1.7, deck), bevel=0.02), stage)]
    out.append(paint(kit.box("franja", (0, -0.851, deck / 2), (2.7, 0.004, 0.03)), stripe))
    # Wheels first: the body sits on them.
    r = 0.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            at = (sx * 0.72, sy * (W / 2 - 0.1), deck + r)
            out.append(paint(kit.cylinder(f"rueda{sx}{sy}", at, r, 0.16, rot=(math.pi / 2, 0, 0), segs=24, bevel=0.03), tyre))
            hub = (at[0], sy * (W / 2 - 0.01), at[2])
            out.append(paint(kit.cylinder(f"tapacubos{sx}{sy}", hub, 0.11, 0.03, rot=(math.pi / 2, 0, 0), segs=20, bevel=0.01), chrome))
    # The body: a rounded tub, the cabin on top with a white roof.
    base = deck + 0.18
    body = kit.superellipsoid("carroceria", (0, 0, base + 0.25), (L / 2, W / 2, 0.25), e=3.2)
    out.append(paint(body, body_c))
    cab_z = base + 0.5
    out.append(paint(kit.superellipsoid("cabina", (0.08, 0, cab_z + 0.18), (0.62, W / 2 - 0.08, 0.22), e=3.0), glass))
    out.append(paint(kit.superellipsoid("techo", (0.1, 0, cab_z + 0.39), (0.56, W / 2 - 0.1, 0.045), e=4.0), white))
    # Round headlamps at the nose, rear lamps, chrome bumpers.
    for sy in (-1, 1):
        out.append(paint(kit.cylinder(f"faro{sy}", (-L / 2 + 0.03, sy * 0.33, base + 0.3), 0.085, 0.05, rot=(0, math.pi / 2, 0), segs=24), lamp))
        out.append(paint(kit.cylinder(f"aro{sy}", (-L / 2 + 0.02, sy * 0.33, base + 0.3), 0.095, 0.03, rot=(0, math.pi / 2, 0), segs=24), chrome))
        out.append(paint(kit.box(f"piloto{sy}", (L / 2 - 0.02, sy * 0.38, base + 0.32), (0.04, 0.12, 0.08), bevel=0.015), tail))
    for sx in (-1, 1):
        out.append(paint(kit.superellipsoid(f"parachoques{sx}", (sx * (L / 2 + 0.01), 0, base + 0.08), (0.04, W / 2 - 0.02, 0.035), e=3.0), chrome))
    # A little oval grille and a badge on the nose.
    out.append(paint(kit.superellipsoid("rejilla", (-L / 2 - 0.005, 0, base + 0.16), (0.02, 0.18, 0.04), e=2.5), chrome))
    # This side's door, ajar: its outline, and a dark gap behind the open edge.
    door_x0, door_x1 = -0.4, 0.2
    y = -W / 2
    out.append(paint(kit.box("hueco_puerta", (door_x1 - 0.03, y + 0.06, base + 0.35), (0.07, 0.1, 0.5)), inside))
    door = kit.box("puerta", (0, 0, 0), (door_x1 - door_x0, 0.05, 0.42), bevel=0.02)
    door.location = ((door_x0 + door_x1) / 2 - 0.02, y - 0.1, base + 0.32)
    door.rotation_euler = (0, 0, -0.35)
    out.append(paint(door, body_c))
    out.append(paint(kit.box("tirador", (door_x1 - 0.1, y - 0.25, base + 0.42), (0.08, 0.02, 0.02), rot=(0, 0, -0.35), bevel=0.006), chrome))
    out.append(paint(kit.box("asiento", (0.0, 0, cab_z + 0.02), (0.3, W - 0.4, 0.14), bevel=0.03), seat))
    return out


# --- Cada pieza a su fichero ----------------------------------------------------------

PIECES = [("tele", tele), ("tostadora", tostadora), ("rubik", rubik), ("perro_globo", perro_globo),
          ("recreativa", recreativa), ("movil_calder", movil_calder), ("semaforo", semaforo), ("coche", coche)]
SITIO = {"tele": "plinth", "tostadora": "plinth", "rubik": "plinth", "perro_globo": "plinth",
         "recreativa": "floor", "movil_calder": "floor", "semaforo": "floor", "coche": "grande"}

wanted = [(n, f) for n, f in PIECES if not ARGS or n in ARGS]
done = tema.replace(os.path.join(ART, "tema_moderna.blend"), "temas/moderna", wanted, lambda n: SITIO[n])
print("[moderna]", len(done), "piezas:", ", ".join(done))
