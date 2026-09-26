"""La armadura del museo, con las proporciones de los personajes (cabezona y
rechoncha, como un guardia con armadura) sobre su peana, con la lanza.

Cada pieza es un objeto aparte, con el nombre que busca el juego: al caer, se
desmonta (stand, leg_l, leg_r, torso, arm_l, arm_r, helm, lance).

    Blender -b -P art/characters/armadura.py                 # art/armadura.blend
    Blender -b -P art/characters/armadura.py -- --sheet /ruta/armadura
y después: Blender -b -P art/export.py -- armadura
"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import kit  # noqa: E402
from kit import Vector  # noqa: E402

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

kit.reset()
# Los nombres y colores de siempre: el juego les pone el sombreado toon.
STEEL = kit.mat("steel", "#a9b2c3", rough=0.3, metal=0.6)
STEEL_DARK = kit.mat("steel_dark", "#5c6370", rough=0.7)
INK = kit.mat("ink", "#08070c", rough=0.7)
GOLD = kit.mat("gold", "#f0c46a", rough=0.7)
CRIMSON = kit.mat("crimson", "#9b2c3f", rough=0.7)
WOOD = kit.mat("wood", "#6b4a2e", rough=0.7)
CASE = kit.mat("case_dark", "#232634", rough=0.7)
GOLD_DIM = kit.mat("gold_dim", "#9a7a3c", rough=0.7)

## Sobre la peana.
BASE = 0.06
HEAD_SCALE = 1.1
NECK = 0.62


def up(z):
    return z + BASE


def head_z(z):
    """La cabeza, como en los personajes, algo más grande desde el cuello."""
    return up(NECK + (z - NECK) * HEAD_SCALE)


def stand():
    plate = kit.box("peana", (0, 0, 0.03), (0.62, 0.52, 0.06), bevel=0.012)
    kit.paint(plate, CASE)
    trim = kit.box("moldura", (0, 0, 0.008), (0.64, 0.54, 0.016), bevel=0.005)
    kit.paint(trim, GOLD_DIM)
    return kit.join([plate, trim], "stand")


def leg(side, s):
    thigh = kit.tube("muslo", [(s * 0.1, 0, up(0.34)), (s * 0.103, -0.005, up(0.23)), (s * 0.106, -0.01, up(0.13))],
                     [(0.1, 0.1), (0.096, 0.096), (0.09, 0.09)], e=2.4)
    kit.paint(thigh, STEEL)
    knee = kit.superellipsoid("rodillera", (s * 0.104, -0.075, up(0.22)), (0.07, 0.04, 0.06), e=2.4)
    kit.paint(knee, STEEL)
    ring = kit.band("aro", up(0.16), 0.012, 0.094, 0.094, 2.2, cy=-0.009, grow=0.006, segs=32)
    ring.location.x = s * 0.106
    kit.paint(ring, STEEL_DARK)
    foot = kit.superellipsoid("escarpe", (s * 0.106, -0.04, up(0.07)), (0.098, 0.15, 0.07), e=2.6)
    kit.paint(foot, STEEL_DARK)
    toe = kit.superellipsoid("puntera", (s * 0.106, -0.13, up(0.06)), (0.06, 0.05, 0.045), e=2.4)
    kit.paint(toe, STEEL)
    return kit.join([thigh, knee, ring, foot, toe], f"leg_{side}")


def torso():
    cuirass = kit.loft("peto", [
        (up(0.26), 0, 0.0, 0.17, 0.14, 2.6),
        (up(0.31), 0, 0.0, 0.21, 0.165, 2.7),
        (up(0.44), 0, -0.015, 0.24, 0.19, 2.7),
        (up(0.53), 0, -0.01, 0.25, 0.18, 2.8),
        (up(0.59), 0, 0.0, 0.24, 0.165, 2.8),
        (up(0.63), 0, 0.0, 0.16, 0.12, 2.5),
        (up(0.66), 0, 0.0, 0.1, 0.09, 2.2),
    ])
    kit.paint(cuirass, STEEL)
    parts = [cuirass]
    # La arista del peto, bajando por el centro.
    ridge = kit.tube("arista", [kit.hit(cuirass, (0, -2, up(z)))[0] + Vector((0, 0.004, 0)) for z in (0.58, 0.5, 0.42, 0.35)],
                     [(0.012, 0.012)] * 4, levels=1)
    kit.paint(ridge, STEEL)
    parts.append(ridge)
    # Cinturón oscuro con hebilla dorada, y la faldeta de láminas.
    belt = kit.band("cinto", up(0.36), 0.026, 0.215, 0.172, 2.6, cy=-0.008, grow=0.016)
    kit.paint(belt, STEEL_DARK)
    p, q = kit.on_surface(belt, 0, up(0.36), lift=0.004)
    buckle = kit.orient(kit.box("hebilla", (0, 0, 0), (0.06, 0.016, 0.042), bevel=0.006), p, q)
    kit.paint(buckle, GOLD)
    parts += [belt, buckle]
    for i, z in enumerate((0.32, 0.285)):
        lame = kit.band(f"lama{i}", up(z), 0.018, 0.205 + i * 0.012, 0.165 + i * 0.01, 2.6, grow=0.012)
        kit.paint(lame, STEEL if i % 2 == 0 else STEEL_DARK)
        parts.append(lame)
    # La gola, al cuello.
    gorget = kit.band("gola", up(0.635), 0.025, 0.15, 0.115, 2.4, grow=0.02)
    kit.paint(gorget, STEEL_DARK)
    parts.append(gorget)
    # Remaches dorados en el peto.
    for s in (-1, 1):
        for z in (0.55, 0.46):
            p, n = kit.hit(cuirass, (s * 0.16, -2, up(z)))
            rivet = kit.superellipsoid("remache", p + n * 0.004, (0.012, 0.012, 0.012), e=2.0)
            kit.paint(rivet, GOLD)
            parts.append(rivet)
    return kit.join(parts, "torso")


def arm(side, s):
    pauldron = kit.superellipsoid("hombrera", (s * 0.235, 0, up(0.585)), (0.1, 0.11, 0.075), e=2.3, rot=(0, s * 0.35, 0))
    kit.paint(pauldron, STEEL)
    rim = kit.band("borde", 0, 0.01, 0.095, 0.105, 2.3, grow=0.008, segs=32)
    rim.location = (s * 0.26, 0, up(0.545))
    rim.rotation_euler = (0, s * 0.35, 0)
    kit.paint(rim, GOLD)
    limb = kit.tube("brazo", [(s * 0.205, 0, up(0.565)), (s * 0.292, -0.005, up(0.44)), (s * 0.314, -0.04, up(0.33))],
                    [(0.084, 0.084), (0.077, 0.075), (0.07, 0.068)], e=2.3)
    kit.paint(limb, STEEL)
    elbow = kit.superellipsoid("codera", (s * 0.3, 0.03, up(0.44)), (0.06, 0.05, 0.06), e=2.4)
    kit.paint(elbow, STEEL)
    fist = kit.superellipsoid("guantelete", (s * 0.326, -0.062, up(0.266)), (0.09, 0.085, 0.092), e=2.4)
    kit.paint(fist, STEEL_DARK)
    cuff = kit.band("puno", up(0.325), 0.022, 0.078, 0.076, 2.3, grow=0.01, segs=32)
    cuff.location.x = s * 0.313
    cuff.location.y = -0.04
    kit.paint(cuff, STEEL_DARK)
    return kit.join([pauldron, rim, limb, elbow, fist, cuff], f"arm_{side}")


def helm():
    rings = [(0.6, 0, -0.01, 0.14, 0.13, 2.4), (0.64, 0, -0.015, 0.21, 0.19, 2.6), (0.7, 0, -0.015, 0.255, 0.225, 2.7),
             (0.8, 0, 0.0, 0.265, 0.245, 2.8), (0.9, 0, 0.005, 0.258, 0.238, 2.8), (0.98, 0, 0.01, 0.215, 0.2, 2.6),
             (1.03, 0, 0.01, 0.13, 0.12, 2.4), (1.045, 0, 0.01, 0.04, 0.04, 2.0)]
    shell = kit.loft("yelmo", [(head_z(z), cx, cy, rx * HEAD_SCALE, ry * HEAD_SCALE, e) for z, cx, cy, rx, ry, e in rings], segs=32)
    kit.paint(shell, STEEL)
    parts = [shell]
    # La cresta del yelmo, de delante atrás.
    crest = kit.tube("cresta", [(0, y, head_z(z)) for y, z in [(-0.2, 0.96), (-0.1, 1.035), (0.05, 1.05), (0.18, 1.0)]],
                     [(0.014, 0.03)] * 4, levels=1, up=(1, 0, 0))
    kit.paint(crest, STEEL_DARK)
    parts.append(crest)
    # El visor: una placa abombada con la ranura de los ojos y los respiraderos.
    visor = kit.decal("visor", kit.ellipse(0.2, 0.13), shell, at=(0, head_z(0.78)), lift=0.004, dome=0.02, thickness=0.02, res=48)
    kit.paint(visor, STEEL)
    slit = kit.decal("ranura", _slot(0.17, 0.022), [visor], at=(0, head_z(0.8)), lift=0.001, thickness=0.006, res=40)
    kit.paint(slit, INK)
    parts += [visor, slit]
    for i in range(3):
        vent = kit.decal(f"respiradero{i}", _slot(0.018, 0.007), [visor], at=((i - 1) * 0.05, head_z(0.72)), lift=0.001,
                         thickness=0.004, res=12, rot=math.pi / 2)
        kit.paint(vent, INK)
        parts.append(vent)
    # Aro dorado alrededor del yelmo.
    ring = kit.band("aro", head_z(0.66), 0.014, 0.23 * HEAD_SCALE, 0.205 * HEAD_SCALE, 2.6, cy=-0.016, grow=0.012)
    kit.paint(ring, GOLD)
    parts.append(ring)
    # Penacho rojo en la coronilla, cayendo hacia atrás.
    for i, (y, z, r) in enumerate([(0.0, 1.1, 0.07), (0.07, 1.11, 0.068), (0.14, 1.09, 0.062), (0.2, 1.05, 0.055), (0.24, 0.99, 0.045)]):
        tuft = kit.superellipsoid(f"penacho{i}", (0, y, head_z(z)), (r * 0.8, r, r), e=2.0)
        kit.paint(tuft, CRIMSON)
        parts.append(tuft)
    return kit.join(parts, "helm")


def _slot(w, h):
    """Una ranura: rectángulo de puntas redondas."""
    pts = []
    for i in range(12):
        a = -math.pi / 2 + math.pi * i / 11
        pts.append((w / 2 - h / 2 + math.cos(a) * h / 2, math.sin(a) * h / 2))
    for i in range(12):
        a = math.pi / 2 + math.pi * i / 11
        pts.append((-w / 2 + h / 2 + math.cos(a) * h / 2, math.sin(a) * h / 2))
    return pts


def lance():
    x, y = 0.33, -0.07
    pole = kit.cylinder("asta", (x, y, up(0.62)), 0.018, 1.2, segs=16)
    kit.paint(pole, WOOD)
    tip = kit.lathe("punta", [(0.0, 0.0), (0.035, 0.02), (0.03, 0.06), (0.0, 0.16)], loc=(x, y, up(1.22)), segs=16)
    kit.paint(tip, STEEL)
    guard = kit.band("arandela", up(1.215), 0.01, 0.03, 0.03, 2.0, grow=0.004, segs=16)
    guard.location = (x, y, 0)
    kit.paint(guard, GOLD)
    pennant = kit.slab("banderin", [(0.0, 0.0), (0.2, -0.045), (0.0, -0.09)], 0.008, loc=(x + 0.012, y, up(1.2)))
    kit.paint(pennant, CRIMSON)
    for o in (pole, tip, guard, pennant):
        kit.smooth_shade(o)
    return kit.join([pole, tip, guard, pennant], "lance")


def build():
    root = kit.empty("armadura")
    objs = [stand(), leg("l", 1), leg("r", -1), torso(), arm("l", 1), arm("r", -1), helm(), lance()]
    kit.parent_all(root, objs)
    return root, objs


def main():
    root, objs = build()
    if "--sheet" in ARGS:
        import sheet
        sheet.render(root, ARGS[ARGS.index("--sheet") + 1], height=1.35)
        return
    # Sueltas, sin padre, como las busca el juego al desmontarla; y aligeradas
    # para el juego (el render no lo nota).
    for o in objs:
        o.parent = None
        d = o.modifiers.new("aligerar", "DECIMATE")
        d.ratio = 0.2
        kit.apply_mods(o)
    bpy.data.objects.remove(root)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "armadura.blend"))


main()
