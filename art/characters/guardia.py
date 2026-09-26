"""El guardia de seguridad (variante «ejecutivo» de la hoja de personajes):
cabezón, bigote, gorra de plato echada atrás con escudo, camisa blanca de
manga corta con corbata, pantalón y botas negras, cinturón con fundas, radio y
linterna.

    Blender -b -P art/characters/guardia.py            # guarda art/guardia.blend
    Blender -b -P art/characters/guardia.py -- --sheet /ruta/guardia
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

# Escena vacía antes de crear los materiales (un reset los borraría).
kit.reset()
SKIN = kit.mat("piel", "#f7b98e", rough=0.5, sheen=0.3)
SHIRT = kit.mat("camisa", "#f2f3f7", rough=0.8, sheen=0.4)
POCKET = kit.mat("bolsillo", "#e3e5ec", rough=0.8, sheen=0.4)
TROUSERS = kit.mat("pantalon", "#1f2638", rough=0.75, sheen=0.4)
BOOT = kit.mat("bota", "#121318", rough=0.28, coat=0.6)
SOLE = kit.mat("suela", "#2b2d34", rough=0.8)
LEATHER = kit.mat("cuero", "#16171c", rough=0.35, coat=0.3)
CAP = kit.mat("gorra", "#1e2842", rough=0.55, sheen=0.3)
PEAK = kit.mat("visera", "#0f1014", rough=0.15, coat=0.8)
GOLD = kit.mat("oro", "#f0b93f", rough=0.3, metal=0.7)
HAIR = kit.mat("pelo", "#3b2519", rough=0.7)
BROW = kit.mat("vello", "#17100d", rough=0.7)
EYE_WHITE = kit.mat("ojo", "#ffffff", rough=0.2, coat=0.6)
PUPIL = kit.mat("pupila", "#0d0d12", rough=0.1, coat=1.0)
TIE = kit.mat("corbata", "#121319", rough=0.5, sheen=0.3)
RADIO = kit.mat("radio", "#23252c", rough=0.45)
GRILL = kit.mat("rejilla", "#101114", rough=0.6)
LED = kit.mat("piloto", "#57ff7a", rough=0.3, emit=4.0)
LENS = kit.mat("lente", "#fff2c2", rough=0.1, emit=6.0)
TORCH = kit.mat("linterna", "#1d1f25", rough=0.3, metal=0.4)

HEAD_SCALE = 1.1


# --- Cuerpo -------------------------------------------------------------------

def body():
    torso = kit.loft("cuerpo", [
        (0.28, 0, 0.0, 0.15, 0.12, 2.5),
        (0.31, 0, 0.0, 0.195, 0.155, 2.6),
        (0.36, 0, -0.008, 0.215, 0.172, 2.6),
        (0.44, 0, -0.015, 0.235, 0.185, 2.6),
        (0.52, 0, -0.008, 0.245, 0.178, 2.7),
        (0.58, 0, 0.0, 0.235, 0.16, 2.8),
        (0.625, 0, 0.0, 0.16, 0.12, 2.5),
        (0.66, 0, 0.0, 0.1, 0.09, 2.2),
    ])
    kit.paint_regions(torso, [(TROUSERS, lambda c, n: c.z < 0.345), (SKIN, lambda c, n: c.z > 0.63)], SHIRT)
    out = [torso]
    for s in (-1, 1):
        leg = kit.tube(f"pierna{s}", [(s * 0.1, 0, 0.34), (s * 0.103, -0.005, 0.23), (s * 0.106, -0.01, 0.13)],
                       [(0.1, 0.1), (0.096, 0.096), (0.09, 0.09)], e=2.3)
        kit.paint(leg, TROUSERS)
        arm = kit.tube(f"brazo{s}", [(s * 0.205, 0, 0.565), (s * 0.292, -0.005, 0.44), (s * 0.314, -0.04, 0.33)],
                       [(0.082, 0.082), (0.075, 0.073), (0.068, 0.066)], e=2.2)
        kit.paint(arm, SKIN)
        # La manga corta: un tubo algo más ancho que acaba en un borde limpio.
        sleeve = kit.tube(f"manga{s}", [(s * 0.2, 0, 0.575), (s * 0.245, -0.002, 0.51), (s * 0.268, -0.004, 0.462)],
                          [(0.096, 0.096), (0.093, 0.092), (0.088, 0.087)], e=2.3)
        kit.paint(sleeve, SHIRT)
        out += [leg, arm, sleeve]
    return out


def hands():
    out = []
    for s in (-1, 1):
        fist = kit.superellipsoid(f"mano{s}", (s * 0.326, -0.062, 0.266), (0.09, 0.085, 0.092), e=2.3)
        thumb = kit.tube(f"pulgar{s}", [(s * 0.29, -0.12, 0.305), (s * 0.282, -0.145, 0.272)], [(0.03, 0.03), (0.027, 0.027)], levels=1)
        kit.paint(fist, SKIN)
        kit.paint(thumb, SKIN)
        out += [fist, thumb]
    return out


def boots():
    out = []
    for s in (-1, 1):
        b = kit.superellipsoid(f"bota{s}", (s * 0.106, -0.035, 0.07), (0.096, 0.142, 0.072), e=2.4)
        ankle = kit.tube(f"cana{s}", [(s * 0.106, 0, 0.145), (s * 0.106, -0.005, 0.09)], [(0.085, 0.085), (0.088, 0.088)], levels=1)
        sole = kit.superellipsoid(f"suela{s}", (s * 0.106, -0.035, 0.016), (0.1, 0.148, 0.018), e=2.6)
        kit.paint(b, BOOT)
        kit.paint(ankle, BOOT)
        kit.paint(sole, SOLE)
        out += [b, ankle, sole]
    return out


def belt():
    out = []
    ring = kit.band("cinturon", 0.355, 0.03, 0.215, 0.172, 2.6, cy=-0.008, grow=0.018)
    kit.paint(ring, LEATHER)
    out.append(ring)
    p, q = kit.on_surface(ring, 0, 0.355, lift=0.004)
    buckle = kit.orient(kit.box("hebilla", (0, 0, 0), (0.08, 0.018, 0.052), bevel=0.008), p, q)
    kit.paint(buckle, GOLD)
    hole = kit.orient(kit.box("hebilla_dentro", (0, -0.006, 0), (0.05, 0.012, 0.026), bevel=0.004), p, q)
    kit.paint(hole, LEATHER)
    out += [buckle, hole]
    # Fundas y bolsas alrededor del cinturón, mirando hacia fuera.
    for i, (ang, size) in enumerate([(-0.8, (0.065, 0.05, 0.075)), (0.8, (0.065, 0.05, 0.075)),
                                     (-1.5, (0.06, 0.07, 0.11)), (1.4, (0.05, 0.045, 0.06))]):
        d = Vector((math.sin(ang), -math.cos(ang), 0))
        p, n = kit.hit(ring, Vector((0, -0.008, 0.355)) + d * 1.0, -d)
        pouch = kit.box(f"funda{i}", (0, 0, 0), size, bevel=0.012)
        pouch.location = p + n * size[1] * 0.45 - Vector((0, 0, 0.02 if size[2] > 0.1 else 0.0))
        pouch.rotation_euler = (0, 0, ang)
        kit.paint(pouch, LEATHER)
        flap = kit.box(f"solapa{i}", (0, -size[1] / 2 - 0.002, size[2] / 2 - 0.018), (size[0] * 0.95, 0.01, 0.034), bevel=0.004)
        flap.parent = pouch
        kit.paint(flap, RADIO)
        out.append(pouch)
    return out


def shirt(b):
    out = []
    # Cuello de la camisa: dos solapas en pico.
    for s in (-1, 1):
        p, q = kit.on_surface(b, s * 0.05, 0.6, lift=0.004)
        c = kit.slab(f"cuello{s}", [(0, 0.02), (s * 0.075, 0.03), (s * 0.02, -0.045)], 0.012, bevel=0.004)
        kit.orient(c, p, q, (0.35, 0, 0))
        kit.paint(c, SHIRT)
        out.append(c)
    # Corbata: el nudo y la pala, pegada al pecho.
    pts, widths = [], []
    for i, z in enumerate([0.575, 0.54, 0.49, 0.44, 0.4, 0.382]):
        p, n = kit.hit(b, (0, -2, z))
        pts.append(p + n * 0.01)
        widths.append([0.042, 0.05, 0.058, 0.066, 0.05, 0.002][i])
    tie = kit.ribbon("corbata", pts, widths, 0.012, up=(0, -1, 0))
    kit.paint(tie, TIE)
    kit.smooth_shade(tie)
    p, q = kit.on_surface(b, 0, 0.59, lift=0.012)
    knot = kit.orient(kit.box("nudo", (0, 0, 0), (0.045, 0.03, 0.04), bevel=0.012), p, q)
    kit.paint(knot, TIE)
    out += [tie, knot]
    # Bolsillos con solapa.
    for s in (-1, 1):
        p, q = kit.on_surface(b, s * 0.12, 0.5, lift=0.002)
        pk = kit.orient(kit.box(f"bolsillo{s}", (0, 0, 0), (0.08, 0.012, 0.075), bevel=0.008), p, q)
        kit.paint(pk, POCKET)
        p, q = kit.on_surface(b, s * 0.12, 0.535, lift=0.008)
        fl = kit.orient(kit.box(f"solapa_b{s}", (0, 0, 0), (0.086, 0.012, 0.03), bevel=0.006), p, q)
        kit.paint(fl, POCKET)
        out += [pk, fl]
    out.append(radio(b))
    # La placa dorada sobre el bolsillo derecho.
    badge = kit.decal("placa", _shield(1.0), b, at=(0.12, 0.5), scale=0.05, lift=0.013, dome=0.006, thickness=0.012, res=24)
    kit.paint(badge, GOLD)
    out.append(badge)
    # Hombreras y el escudo de la manga.
    for s in (-1, 1):
        p, n = kit.hit(b, (s * 0.17, 0, 2), (0, 0, -1))
        ep = kit.box(f"hombrera{s}", (0, 0, 0), (0.12, 0.07, 0.016), bevel=0.006)
        ep.location = p + n * 0.006
        ep.rotation_euler = (0, s * -0.35, 0)
        kit.paint(ep, CAP)
        btn = kit.cylinder(f"boton{s}", (s * -0.045, 0, 0.01), 0.011, 0.008)
        btn.parent = ep
        kit.paint(btn, GOLD)
        out.append(ep)
    return out


def radio(b):
    """El walkie en el pecho: grande, que se lea desde lejos. Cuerpo, antena
    gruesa, rejilla del altavoz, rueda y el piloto verde."""
    p, q = kit.on_surface(b, -0.13, 0.49, lift=0.045)
    r = kit.orient(kit.box("radio", (0, 0, 0), (0.11, 0.07, 0.18), bevel=0.022), p, q, (0, 0, 0.12))
    kit.paint(r, RADIO)
    for name, loc, size, m in [
        ("rejilla", (0, -0.036, -0.025), (0.074, 0.008, 0.085), GRILL),
        ("clip", (0, 0.04, 0.03), (0.04, 0.014, 0.08), RADIO),
    ]:
        o = kit.box(name, loc, size, bevel=0.006)
        o.parent = r
        kit.paint(o, m)
    ant = kit.cylinder("antena", (0.03, 0, 0.14), 0.016, 0.12, bevel=0.006)
    ant.parent = r
    kit.paint(ant, RADIO)
    knob = kit.cylinder("rueda", (-0.03, 0, 0.1), 0.017, 0.026, bevel=0.004)
    knob.parent = r
    kit.paint(knob, GRILL)
    led = kit.sphere("piloto", (-0.032, -0.034, 0.062), (0.01, 0.006, 0.01))
    led.parent = r
    kit.paint(led, LED)
    return r


# --- Cabeza ---------------------------------------------------------------------

def head():
    h = kit.loft("cabeza", [
        (0.6, 0, -0.01, 0.14, 0.13, 2.4),
        (0.64, 0, -0.02, 0.21, 0.19, 2.6),
        (0.7, 0, -0.02, 0.25, 0.22, 2.7),
        (0.8, 0, 0.0, 0.262, 0.24, 2.8),
        (0.9, 0, 0.005, 0.252, 0.232, 2.8),
        (0.97, 0, 0.01, 0.21, 0.2, 2.6),
        (1.02, 0, 0.01, 0.13, 0.12, 2.4),
        (1.035, 0, 0.01, 0.04, 0.04, 2.0),
    ], segs=32)
    kit.paint(h, SKIN)
    out = [h]
    for s in (-1, 1):
        ear = kit.superellipsoid(f"oreja{s}", (s * 0.266, 0.02, 0.77), (0.042, 0.062, 0.082), e=2.2, rot=(0, s * -0.25, 0))
        kit.paint(ear, SKIN)
        out.append(ear)
    # Pelo: por detrás y los lados, más atrás que la cara; asoma bajo la
    # gorra, baja en pico por la nuca y termina en patillas delante de las
    # orejas.
    hair = kit.loft("pelo", [
        (0.665, 0, 0.1, 0.12, 0.1, 2.2),
        (0.7, 0, 0.075, 0.215, 0.17, 2.5),
        (0.75, 0, 0.045, 0.264, 0.222, 2.7),
        (0.85, 0, 0.035, 0.27, 0.236, 2.8),
        (0.95, 0, 0.035, 0.252, 0.222, 2.7),
        (1.0, 0, 0.03, 0.2, 0.18, 2.5),
    ], segs=32)
    kit.paint(hair, HAIR)
    out.append(hair)
    for s in (-1, 1):
        burn = kit.superellipsoid(f"patilla{s}", (s * 0.252, -0.07, 0.79), (0.026, 0.036, 0.07), e=2.4, rot=(0.15, 0, s * -0.12))
        kit.paint(burn, HAIR)
        out.append(burn)
    out += face(h)
    return out


def face(h):
    """Ojos grandes y bajos, cejas gruesas con aire decidido y un bigote de
    manillar. Sin nariz."""
    out = []
    for s in (-1, 1):
        # Ojos de la hoja: óvalos negros sin blanco, con dos brillos.
        x, z = s * 0.088, 0.755
        pupil = kit.decal(f"ojo{s}", kit.ellipse(0.038, 0.056), h, at=(x, z), lift=0.001, dome=0.012, thickness=0.01)
        kit.paint(pupil, PUPIL)
        glint = kit.decal(f"brillo{s}", kit.ellipse(0.012, 0.015), [pupil], at=(x + 0.012, z + 0.022), lift=0.0008, thickness=0.004, res=16)
        glint2 = kit.decal(f"brillo2{s}", kit.ellipse(0.006, 0.006), [pupil], at=(x - 0.012, z - 0.024), lift=0.0008, thickness=0.004, res=12)
        kit.paint(glint, EYE_WHITE)
        kit.paint(glint2, EYE_WHITE)
        white = pupil
        brow = kit.decal(f"ceja{s}", kit.stroke(0.105, 0.036, 0.022, arch=0.012, tilt=0.2, side=s), h, at=(s * 0.093, 0.832), lift=0.002, dome=0.012, thickness=0.014, res=40)
        kit.paint(brow, BROW)
        out += [pupil, glint, glint2, brow]
    tache = kit.decal("bigote", MOUSTACHE, h, at=(0, 0.672), scale=0.95, lift=0.002, dome=0.022, thickness=0.02, res=56)
    kit.paint(tache, BROW)
    out.append(tache)
    return out


def brow_outline(s):
    """Ceja gruesa: ancha y baja por dentro, afilada y alta por fuera."""
    pts = [(-0.065, 0.004), (-0.02, 0.02), (0.03, 0.03), (0.066, 0.022), (0.068, 0.01), (0.03, 0.01), (-0.02, -0.008), (-0.066, -0.02)]
    return [(x * s, z) for x, z in pts] if s > 0 else [(x * s, z) for x, z in reversed(pts)]


## Bigote poblado, como en la hoja: dos lóbulos redondos y gruesos que caen
## un poco hacia fuera, con una muesca arriba y otra abajo en el centro.
_TACHE_TOP = [(0.0, 0.016), (0.02, 0.028), (0.045, 0.034), (0.07, 0.032), (0.092, 0.024), (0.108, 0.01), (0.116, -0.006)]
_TACHE_BOT = [(0.114, -0.02), (0.104, -0.032), (0.088, -0.04), (0.068, -0.041), (0.048, -0.036), (0.028, -0.036),
              (0.012, -0.03), (0.0, -0.022)]
MOUSTACHE = (_TACHE_TOP + _TACHE_BOT
             + [(-x, z) for x, z in reversed(_TACHE_BOT[:-1])]
             + [(-x, z) for x, z in reversed(_TACHE_TOP[1:])])


def cap():
    """Gorra de plato echada hacia atrás: copa mullida, más alta por delante
    (lleva el escudo), cinta negra con cordón dorado y botones, y la visera
    de charol curvada hacia abajo."""
    pivot = kit.empty("gorra_raiz")
    crown = kit.lathe("gorra", [(0.243, 0.0), (0.247, 0.06), (0.27, 0.095), (0.31, 0.14), (0.326, 0.165), (0.323, 0.19),
                                (0.3, 0.212), (0.25, 0.228), (0.15, 0.238), (0.0, 0.24)], size=(1, 0.93, 1), segs=64)
    # La parte de delante de la copa se levanta.
    for v in crown.data.vertices:
        if v.co.z > 0.07:
            v.co.z += 0.055 * max(0.0, -v.co.y / 0.3) * min(1.0, (v.co.z - 0.07) / 0.14)
    kit.paint(crown, CAP)
    kit._subsurf(crown, 1)
    band = kit.lathe("cinta", [(0.244, -0.002), (0.2515, 0.004), (0.2525, 0.05), (0.245, 0.058)], size=(1, 0.93, 1), segs=64)
    kit.paint(band, PEAK)
    kit.smooth_shade(band)
    # Visera: más larga en el centro y curvada hacia abajo por los lados.
    # Nace de la cinta (su borde de dentro queda metido en ella) y sale hacia
    # delante con algo de caída.
    peak = kit.superellipsoid("visera", (0, -0.3, 0.012), (0.235, 0.135, 0.026), e=2.3, rot=(0.32, 0, 0))
    for v in peak.data.vertices:
        v.co.z -= 0.7 * v.co.x ** 2 + 0.6 * max(0.0, -(v.co.y + 0.28)) ** 2
    kit.paint(peak, PEAK)
    kit.smooth_shade(peak)
    parts = [crown, band, peak]
    # Cordón dorado por delante, entre dos botones.
    cord_pts = []
    for i in range(9):
        a = math.radians(-58 + 116 * i / 8)
        cord_pts.append((math.sin(a) * 0.256, -math.cos(a) * 0.256 * 0.93, 0.022 + 0.004 * math.cos(a * 2)))
    cord = kit.tube("cordon", cord_pts, [(0.0065, 0.0065)] * len(cord_pts), levels=1, up=(0, 0, 1))
    kit.paint(cord, GOLD)
    parts.append(cord)
    for sgn in (-1, 1):
        a = math.radians(sgn * 60)
        btn = kit.superellipsoid(f"boton_gorra{sgn}", (math.sin(a) * 0.257, -math.cos(a) * 0.257 * 0.93, 0.022), (0.013, 0.013, 0.013), e=2.0)
        kit.paint(btn, GOLD)
        parts.append(btn)
    for o in parts:
        o.parent = pivot
    pivot.location = (0, 0.03, 0.9)
    pivot.rotation_euler = (-0.2, 0, 0)
    bpy.context.view_layer.update()
    badge = kit.decal("escudo", _shield(1.0), crown, at=(0, 1.06), scale=0.048, lift=0.002, dome=0.008, thickness=0.01, res=24)
    kit.paint(badge, GOLD)
    return [pivot, badge]


def _shield(w):
    return [(-w, w * 0.9), (0, w * 1.05), (w, w * 0.9), (w, -w * 0.1), (w * 0.55, -w * 0.75), (0, -w * 1.1), (-w * 0.55, -w * 0.75), (-w, -w * 0.1)]


def torch():
    """Linterna grande en la mano derecha, apuntando al frente."""
    parts = []
    x, z = 0.326, 0.266
    rot = (math.pi / 2, 0, 0)
    body = kit.cylinder("mango", (x, -0.13, z), 0.042, 0.24, rot=rot, bevel=0.01)
    grip = kit.cylinder("goma", (x, -0.1, z), 0.045, 0.1, rot=rot, bevel=0.008)
    head_ = kit.cylinder("cabezal", (x, -0.285, z), 0.068, 0.085, rot=rot, r2=0.046, bevel=0.01)
    ring = kit.cylinder("aro", (x, -0.328, z), 0.07, 0.014, rot=rot, bevel=0.004)
    lens = kit.cylinder("lente", (x, -0.336, z), 0.06, 0.006, rot=rot)
    for o, m in ((body, TORCH), (grip, RADIO), (head_, TORCH), (ring, GOLD), (lens, LENS)):
        kit.paint(o, m)
        kit.smooth_shade(o)
        parts.append(o)
    return parts


def build():
    root = kit.empty("guardia")
    parts = body()
    neck = kit.empty("cabeza_raiz")
    neck.location = (0, 0, 0.62)
    for o in head() + cap():
        o.parent = neck
        o.matrix_parent_inverse = neck.matrix_world.inverted()
    neck.scale = (HEAD_SCALE,) * 3
    kit.parent_all(root, parts + hands() + boots() + belt() + shirt(parts[0]) + torch() + [neck])
    return root


def rules(name, side):
    """Huesos de cada pieza del cuerpo (la cabeza y la gorra van aparte)."""
    if name.startswith("cuerpo"):
        return ["cadera", "columna", "pecho"]
    if name.startswith("pierna"):
        return ["cadera", f"muslo.{side}", f"espinilla.{side}"]
    if name.startswith("brazo"):
        return ["pecho", f"brazo.{side}", f"antebrazo.{side}"]
    if name.startswith("manga"):
        return ["pecho", f"brazo.{side}"]
    if name.startswith(("mano", "pulgar", "mango", "goma", "cabezal", "aro", "lente")):
        return [f"mano.{side}"]
    if name.startswith(("bota", "cana", "suela")):
        return [f"pie.{side}"]
    if name.startswith(("cinturon", "hebilla", "funda", "solapa")) and not name.startswith("solapa_b"):
        return ["cadera"]
    if name.startswith(("cuello", "corbata", "nudo", "bolsillo", "solapa_b", "radio", "rejilla", "clip", "antena",
                        "rueda", "piloto", "placa", "hombrera", "boton")):
        return ["pecho"]
    return None


def main():
    root = build()
    if "--rig" in ARGS or not ARGS or "--preview" in ARGS:
        import rig
        arm, _ = rig.skin(root, rules, "guardia")
        rig.animate(arm, ["reposo", "andar", "correr"], rig.GUARD_ANIMATIONS)
        if "--preview" in ARGS:
            rig.preview(arm, ARGS[ARGS.index("--preview") + 1], ["andar", "correr"])
            return
    if "--sheet" in ARGS:
        import sheet
        sheet.render(root, ARGS[ARGS.index("--sheet") + 1], only=ARGS[ARGS.index("--views") + 1].split(",") if "--views" in ARGS else None)
    else:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "guardia.blend"))
        if not ARGS:
            import rig
            rig.export(os.path.join(ART, "..", "assets", "models", "guardia.glb"))


main()
