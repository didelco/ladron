"""Edad Media: corona, cáliz, manuscrito iluminado y llave con sello en
vitrina; yelmo, escudo de armas y maqueta de castillo sobre peana; la espada
en la piedra y el trono de pie. La armadura (art/armadura.blend) va suelta por
las salas, como mueble que se cae.

    Blender -b -P art/temas/edad_media.py [-- --sheet /ruta.png]
"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import tema  # noqa: E402
import kit  # noqa: E402
from kit import Vector  # noqa: E402

kit.reset()
GOLD = kit.mat("oro", "#e8b53a", rough=0.3, metal=0.7)
SILVER = kit.mat("plata", "#c9ced8", rough=0.3, metal=0.7)
IRON = kit.mat("hierro", "#5c6370", rough=0.5)
RUBY = kit.mat("rubi", "#d0263e", rough=0.2)
SAPPHIRE = kit.mat("zafiro", "#2f6fe0", rough=0.2)
EMERALD = kit.mat("esmeralda", "#23a861", rough=0.2)
VELVET = kit.mat("terciopelo", "#6a1f2e", rough=0.9)
BLUE_CLOTH = kit.mat("pano_azul", "#27408a", rough=0.9)
PARCHMENT = kit.mat("pergamino", "#ecdcb0", rough=0.9)
INK = kit.mat("tinta", "#2a1e14", rough=0.8)
LEATHER = kit.mat("cuero", "#6b3a1e", rough=0.6)
WAX = kit.mat("lacre", "#b0232e", rough=0.4)
WOOD = kit.mat("madera", "#7a4a26", rough=0.7)
WOOD_DARK = kit.mat("madera_oscura", "#4a2c16", rough=0.7)
STONE = kit.mat("piedra", "#8a8a8e", rough=0.9)
STONE_DARK = kit.mat("piedra_oscura", "#5e5e66", rough=0.9)
ROOF = kit.mat("tejado", "#3f5fa8", rough=0.7)
MOSS = kit.mat("musgo", "#4e7a3a", rough=0.9)


# --- En vitrina ---------------------------------------------------------------------

def corona():
    """Una corona de oro con puntas de flor de lis y piedras, sobre un cojín
    de terciopelo con borlas."""
    pad = tema.cushion("cojin", 0.34, 0.34, VELVET, h=0.06)
    out = [pad]
    for s in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        tassel = kit.superellipsoid(f"borla{s}", (s[0] * 0.16, s[1] * 0.16, 0.03), (0.018, 0.018, 0.03), e=2.0)
        kit.paint(tassel, GOLD)
        out.append(tassel)
    ring = kit.lathe("aro", [(0.085, 0.0), (0.095, 0.0), (0.098, 0.05), (0.09, 0.055), (0.085, 0.05)], loc=(0, 0, 0.06), segs=48)
    kit.paint(ring, GOLD)
    kit.smooth_shade(ring)
    out.append(ring)
    gems = [RUBY, SAPPHIRE, EMERALD]
    for k in range(6):
        a = k / 6 * 2 * math.pi
        x, y = math.cos(a) * 0.092, math.sin(a) * 0.092
        tip = kit.cylinder(f"punta{k}", (x, y, 0.135), 0.022, 0.05, r2=0.004, segs=6)
        kit.paint(tip, GOLD)
        ball = kit.superellipsoid(f"bola{k}", (x * 1.02, y * 1.02, 0.165), (0.012, 0.012, 0.012), e=2.0)
        kit.paint(ball, GOLD)
        gem = kit.superellipsoid(f"gema{k}", (x * 1.07, y * 1.07, 0.085), (0.014, 0.014, 0.014), e=2.0)
        kit.paint(gem, gems[k % 3])
        out += [tip, ball, gem]
    return out


def caliz():
    """Un cáliz de plata dorada con esmaltes, y una patena al lado."""
    cup = kit.lathe("caliz", [(0.0, 0.0), (0.07, 0.0), (0.075, 0.01), (0.03, 0.03), (0.015, 0.07), (0.028, 0.1), (0.015, 0.13),
                              (0.03, 0.15), (0.075, 0.2), (0.085, 0.27), (0.08, 0.275), (0.07, 0.21), (0.0, 0.2)], loc=(-0.06, 0, 0), segs=48)
    kit.paint(cup, GOLD)
    kit.smooth_shade(cup)
    knot = kit.superellipsoid("nudo", (-0.06, 0, 0.1), (0.035, 0.035, 0.025), e=2.2)
    kit.paint(knot, SILVER)
    out = [cup, knot]
    for k in range(4):
        a = k / 4 * 2 * math.pi
        gem = kit.superellipsoid(f"esmalte{k}", (-0.06 + math.cos(a) * 0.035, math.sin(a) * 0.035, 0.1), (0.01, 0.01, 0.01), e=2.0)
        kit.paint(gem, SAPPHIRE if k % 2 else RUBY)
        out.append(gem)
    paten = kit.lathe("patena", [(0.0, 0.0), (0.08, 0.0), (0.09, 0.012), (0.0, 0.008)], loc=(0.14, 0.02, 0.0), segs=40)
    kit.paint(paten, SILVER)
    kit.smooth_shade(paten)
    return out + [paten]


def manuscrito():
    """Un códice abierto en su atril: dos páginas de pergamino con texto, una
    capitular iluminada en rojo y oro, tapas de cuero."""
    stand = kit.box("atril", (0, 0.03, 0.05), (0.44, 0.2, 0.1), bevel=0.01, rot=(0.25, 0, 0))
    kit.paint(stand, WOOD_DARK)
    out = [stand]
    for s in (-1, 1):
        cover = kit.box(f"tapa{s}", (s * 0.105, 0.0, 0.125), (0.22, 0.16, 0.012), bevel=0.004, rot=(-0.95, 0, s * -0.08))
        kit.paint(cover, LEATHER)
        page = kit.box(f"pagina{s}", (s * 0.1, -0.005, 0.132), (0.2, 0.15, 0.012), bevel=0.004, rot=(-0.95, 0, s * -0.12))
        kit.paint(page, PARCHMENT)
        out += [cover, page]
        for row in range(6):
            short = 0.03 if row < 2 and s < 0 else 0.0
            line = kit.decal(f"linea{s}{row}", [(-0.06 + short, -0.003), (0.06, -0.003), (0.06, 0.003), (-0.06 + short, 0.003)], [page],
                             at=(s * 0.1, 0.19 - row * 0.018), lift=0.001, thickness=0.002, res=8)
            kit.paint(line, INK)
            out.append(line)
    cap = kit.decal("capitular", [(-0.022, -0.022), (0.022, -0.022), (0.022, 0.022), (-0.022, 0.022)], [out[2]],
                    at=(-0.15, 0.16), lift=0.0015, thickness=0.003, res=10)
    kit.paint(cap, RUBY)
    capg = kit.decal("capitular_oro", [(-0.012, -0.014), (0.012, -0.014), (0.012, 0.014), (-0.012, 0.014)], [cap],
                     at=(-0.15, 0.16), lift=0.001, thickness=0.002, res=8)
    kit.paint(capg, GOLD)
    ribbon = kit.tube("cinta", [(0.0, -0.02, 0.2), (0.0, -0.06, 0.12), (0.01, -0.07, 0.06)], [(0.008, 0.002)] * 3, levels=1)
    kit.paint(ribbon, RUBY)
    return out + [cap, capg, ribbon]


def llave_sello():
    """La gran llave de hierro de la ciudad y un pergamino enrollado con su
    sello de lacre, sobre un paño azul."""
    cloth = tema.cushion("pano", 0.46, 0.3, BLUE_CLOTH, h=0.02)
    bow_ = kit.lathe("llave_ojo", [(0.03, -0.007), (0.045, 0.0), (0.03, 0.007)], loc=(-0.16, -0.04, 0.03), segs=24)
    shaft = kit.cylinder("llave_cana", (-0.02, -0.04, 0.03), 0.01, 0.22, rot=(0, math.pi / 2, 0), segs=12)
    bit = kit.box("llave_pala", (0.08, -0.06, 0.03), (0.03, 0.04, 0.012), bevel=0.003)
    teeth = kit.box("llave_dientes", (0.07, -0.08, 0.03), (0.01, 0.012, 0.012), bevel=0.002)
    for o in (bow_, shaft, bit, teeth):
        kit.paint(o, IRON)
        o.rotation_euler.z += 0.15
    roll = kit.cylinder("rollo", (0.04, 0.07, 0.045), 0.028, 0.28, rot=(0, math.pi / 2, 0.1), segs=20)
    kit.paint(roll, PARCHMENT)
    string = kit.band("cordel", 0.0, 0.006, 0.03, 0.03, 2.0, grow=0.001, segs=20)
    string.rotation_euler = (0, math.pi / 2, 0.1)
    string.location = (0.04, 0.07, 0.045)
    kit.paint(string, WAX)
    seal = kit.cylinder("sello", (0.05, 0.03, 0.035), 0.03, 0.012, rot=(math.pi / 2 - 0.3, 0, 0), segs=20, bevel=0.004)
    kit.paint(seal, WAX)
    return [cloth, bow_, shaft, bit, teeth, roll, string, seal]


# --- Sobre peana -------------------------------------------------------------------

def yelmo():
    """Un yelmo de cruzado, cilíndrico, con la cruz de las rendijas y un
    penacho, en su soporte de madera."""
    stand = kit.cylinder("soporte", (0, 0, 0.1), 0.03, 0.2, segs=12)
    kit.paint(stand, WOOD)
    foot = tema.stand_block("base", 0.2, 0.2, 0.03, WOOD_DARK)
    helm = kit.loft("yelmo", [(0.16, 0, 0, 0.11, 0.12, 2.6), (0.32, 0, 0, 0.115, 0.125, 2.6), (0.37, 0, 0, 0.1, 0.11, 2.4),
                              (0.4, 0, 0, 0.06, 0.07, 2.2), (0.41, 0, 0, 0.02, 0.02, 2.0)], segs=32)
    kit.paint(helm, SILVER)
    band = kit.band("franja", 0.33, 0.012, 0.115, 0.125, 2.6, grow=0.006)
    kit.paint(band, GOLD)
    slit = kit.decal("rendija", [(-0.07, -0.006), (0.07, -0.006), (0.07, 0.006), (-0.07, 0.006)], helm, at=(0, 0.3), lift=0.001, thickness=0.006, res=20)
    kit.paint(slit, INK)
    nose = kit.decal("cruz", [(-0.008, -0.08), (0.008, -0.08), (0.008, 0.0), (-0.008, 0.0)], helm, at=(0, 0.25), lift=0.001, thickness=0.006, res=12)
    kit.paint(nose, GOLD)
    out = [stand, foot, helm, band, slit, nose]
    for k in range(3):
        for s in (-1, 1):
            hole = kit.decal(f"respiro{k}{s}", kit.ellipse(0.005, 0.005, 10), helm, at=(s * (0.03 + k * 0.014), 0.22 - k * 0.012), lift=0.001,
                             thickness=0.004, res=6)
            kit.paint(hole, INK)
            out.append(hole)
    for i, (y, z, r) in enumerate([(-0.02, 0.45, 0.04), (0.03, 0.47, 0.045), (0.08, 0.46, 0.04)]):
        plume = kit.superellipsoid(f"penacho{i}", (0, y, z), (r * 0.7, r, r), e=2.0)
        kit.paint(plume, RUBY)
        out.append(plume)
    return out


def escudo():
    """Un escudo de armas en su caballete: campo azul, banda de oro y tres
    flores de lis."""
    easel = []
    for s in (-1, 1):
        leg = kit.tube(f"pata{s}", [(s * 0.1, 0.06, 0.0), (s * 0.05, 0.05, 0.42)], [(0.012, 0.012)] * 2, levels=1)
        kit.paint(leg, WOOD_DARK)
        easel.append(leg)
    back = kit.tube("pata_atras", [(0, 0.16, 0.0), (0, 0.06, 0.4)], [(0.012, 0.012)] * 2, levels=1)
    kit.paint(back, WOOD_DARK)
    outline = [(-0.14, 0.18), (0.14, 0.18), (0.14, 0.02), (0.1, -0.1), (0.0, -0.18), (-0.1, -0.1), (-0.14, 0.02)]
    shield = kit.slab("escudo", outline, 0.03, loc=(0, 0.02, 0.26), rot=(-0.2, 0, 0), bevel=0.008)
    kit.paint(shield, SAPPHIRE)
    rim = kit.slab("borde", [(x * 1.07, z * 1.07) for x, z in outline], 0.02, loc=(0, 0.035, 0.26), rot=(-0.2, 0, 0), bevel=0.004)
    kit.paint(rim, SILVER)
    bend = kit.decal("banda", [(-0.12, 0.09), (-0.09, 0.13), (0.09, -0.05), (0.06, -0.09)], [shield], at=(0, 0.26), lift=0.001, thickness=0.004, res=20)
    kit.paint(bend, GOLD)
    out = easel + [back, shield, rim, bend]
    lis = [(0.0, 0.03), (0.012, 0.012), (0.03, 0.02), (0.02, 0.0), (0.012, -0.004), (0.012, -0.03), (-0.012, -0.03), (-0.012, -0.004), (-0.02, 0.0),
           (-0.03, 0.02), (-0.012, 0.012)]
    for k, (x, z) in enumerate([(-0.06, 0.33), (0.07, 0.3), (0.0, 0.17)]):
        f = kit.decal(f"lis{k}", lis, [shield], at=(x, z), lift=0.001, thickness=0.004, res=12)
        kit.paint(f, GOLD if k != 1 else SILVER)
        out.append(f)
    return out


def castillo():
    """La maqueta de un castillo sobre su montículo: muralla almenada, cuatro
    torres con tejados cónicos, la torre del homenaje y la puerta."""
    hill = kit.superellipsoid("monticulo", (0, 0, 0.02), (0.24, 0.24, 0.04), e=2.6)
    kit.paint(hill, MOSS)
    out = [hill]
    wall = kit.loft("muralla", [(0.04, 0, 0, 0.17, 0.17, 6.0), (0.14, 0, 0, 0.17, 0.17, 6.0)], segs=32, levels=0)
    kit.paint(wall, STONE)
    kit.delete_faces(wall, lambda c: c.z > 0.139)
    out.append(wall)
    for k in range(16):
        a = k / 16 * 2 * math.pi
        m = kit.box(f"almena{k}", (math.cos(a) * 0.165, math.sin(a) * 0.165, 0.155), (0.03, 0.03, 0.03), bevel=0.003)
        m.rotation_euler.z = a
        kit.paint(m, STONE)
        out.append(m)
    for i, (x, y) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        t = kit.cylinder(f"torre{i}", (x * 0.16, y * 0.16, 0.12), 0.045, 0.2, segs=16)
        kit.paint(t, STONE_DARK)
        r = kit.cylinder(f"tejado{i}", (x * 0.16, y * 0.16, 0.26), 0.055, 0.09, r2=0.0, segs=16)
        kit.paint(r, ROOF)
        out += [t, r]
    keep = kit.box("homenaje", (0.02, 0.03, 0.2), (0.14, 0.14, 0.26), bevel=0.004)
    kit.paint(keep, STONE)
    keep_roof = kit.cylinder("homenaje_tejado", (0.02, 0.03, 0.37), 0.1, 0.1, r2=0.0, segs=4, rot=(0, 0, math.pi / 4))
    kit.paint(keep_roof, ROOF)
    flag_pole = kit.cylinder("mastil", (0.02, 0.03, 0.46), 0.004, 0.1, segs=6)
    kit.paint(flag_pole, WOOD_DARK)
    flag = kit.slab("bandera", [(0.0, 0.0), (0.06, -0.015), (0.0, -0.035)], 0.004, loc=(0.02, 0.03, 0.51))
    kit.paint(flag, RUBY)
    gate = kit.decal("puerta", [(-0.025, -0.04), (0.025, -0.04), (0.025, 0.01), (0.0, 0.035), (-0.025, 0.01)], wall, at=(0, 0.09), lift=0.001,
                     thickness=0.006, res=12)
    kit.paint(gate, WOOD_DARK)
    return out + [keep, keep_roof, flag_pole, flag, gate]


# --- De pie en el suelo ------------------------------------------------------------

def espada_piedra():
    """La espada clavada en la roca, con su empuñadura de oro."""
    rock = kit.superellipsoid("roca", (0, 0, 0.16), (0.3, 0.26, 0.18), e=2.3)
    kit.paint(rock, STONE)
    rock2 = kit.superellipsoid("roca2", (0.12, 0.08, 0.24), (0.16, 0.14, 0.14), e=2.2)
    kit.paint(rock2, STONE_DARK)
    moss = kit.superellipsoid("musgo", (-0.14, -0.08, 0.3), (0.12, 0.1, 0.05), e=2.2)
    kit.paint(moss, MOSS)
    blade = kit.box("hoja", (0, -0.02, 0.48), (0.05, 0.012, 0.36), bevel=0.004)
    kit.paint(blade, SILVER)
    guard = kit.box("guarda", (0, -0.02, 0.66), (0.2, 0.03, 0.03), bevel=0.01)
    kit.paint(guard, GOLD)
    grip = kit.cylinder("puno", (0, -0.02, 0.73), 0.016, 0.12, segs=12)
    kit.paint(grip, LEATHER)
    pommel = kit.superellipsoid("pomo", (0, -0.02, 0.8), (0.028, 0.028, 0.028), e=2.0)
    kit.paint(pommel, GOLD)
    gem = kit.superellipsoid("gema", (0, -0.05, 0.66), (0.014, 0.008, 0.014), e=2.0)
    kit.paint(gem, RUBY)
    return [rock, rock2, moss, blade, guard, grip, pommel, gem]


def trono():
    """El trono: respaldo alto de madera tallada con remate, cojín rojo y
    brazos, sobre una tarima."""
    dais = tema.stand_block("tarima", 0.74, 0.7, 0.06, STONE_DARK)
    seat = kit.box("asiento", (0, 0.02, 0.3), (0.5, 0.45, 0.08), bevel=0.02)
    kit.paint(seat, WOOD)
    cushion = kit.superellipsoid("cojin", (0, 0.0, 0.36), (0.22, 0.2, 0.04), e=3.0)
    kit.paint(cushion, RUBY)
    back = kit.box("respaldo", (0, 0.22, 0.68), (0.5, 0.07, 0.7), bevel=0.02)
    kit.paint(back, WOOD)
    panel = kit.box("tapiz", (0, 0.18, 0.66), (0.36, 0.02, 0.5), bevel=0.01)
    kit.paint(panel, VELVET)
    crest = kit.cylinder("remate", (0, 0.2, 1.05), 0.08, 0.04, rot=(math.pi / 2, 0, 0), segs=24, bevel=0.01)
    kit.paint(crest, GOLD)
    out = [dais, seat, cushion, back, panel, crest]
    for s in (-1, 1):
        post = kit.cylinder(f"poste{s}", (s * 0.25, 0.22, 0.55), 0.035, 1.0, segs=12)
        kit.paint(post, WOOD_DARK)
        knob = kit.superellipsoid(f"pina{s}", (s * 0.25, 0.22, 1.07), (0.04, 0.04, 0.05), e=2.0)
        kit.paint(knob, GOLD)
        arm = kit.box(f"brazo{s}", (s * 0.24, 0.0, 0.46), (0.06, 0.42, 0.05), bevel=0.015)
        kit.paint(arm, WOOD_DARK)
        leg = kit.box(f"pata{s}", (s * 0.24, -0.19, 0.18), (0.06, 0.06, 0.26), bevel=0.01)
        kit.paint(leg, WOOD_DARK)
        out += [post, knob, arm, leg]
    return out


tema.run("edad_media", [
    ("corona", "case", corona),
    ("caliz", "case", caliz),
    ("manuscrito", "case", manuscrito),
    ("llave_sello", "case", llave_sello),
    ("yelmo", "plinth", yelmo),
    ("escudo", "plinth", escudo),
    ("castillo", "plinth", castillo),
    ("espada_piedra", "floor", espada_piedra),
    ("trono", "floor", trono),
])
