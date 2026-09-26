"""El ninja (ladrón) de la hoja de personajes: traje negro de tela para todos,
y el color del jugador en la cinta (con su lazo y colas) y en el cinturón. La
cara no se ve: los ojos asoman sobre la tela negra.

    Blender -b -P art/characters/ninja.py                       # art/ninja.blend
    Blender -b -P art/characters/ninja.py -- --sheet /ruta/ninja --color azul
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

## Los colores de jugador de la hoja: el de la cinta y el cinturón.
COLOURS = {
    "rojo": "#e2262f",
    "azul": "#2f7bf0",
    "verde": "#2fb84a",
    "morado": "#8a3fe0",
    "blanco": "#eef0f5",
    "dorado": "#e6a92a",
}

kit.reset()
band_hex = COLOURS[ARGS[ARGS.index("--color") + 1]] if "--color" in ARGS else COLOURS["rojo"]
SUIT = kit.mat("traje", "#141418", rough=0.8, sheen=0.25)
LAPEL = kit.mat("solapa", "#26262e", rough=0.8, sheen=0.25)
GLOVE = kit.mat("guante", "#101014", rough=0.65, sheen=0.2)
SOLE = kit.mat("suela", "#2a2a31", rough=0.8)
BAND = kit.mat("cinta", band_hex, rough=0.6, sheen=0.3)
EYE_WHITE = kit.mat("ojo", "#ffffff", rough=0.2, coat=0.6)
PUPIL = kit.mat("pupila", "#0d0d12", rough=0.1, coat=1.0)
BROW = kit.mat("ceja", "#050507", rough=0.6)

HEAD_SCALE = 1.1


def body():
    torso = kit.loft("cuerpo", [
        (0.28, 0, 0.0, 0.15, 0.12, 2.5),
        (0.31, 0, 0.0, 0.19, 0.15, 2.6),
        (0.36, 0, -0.005, 0.21, 0.165, 2.6),
        (0.44, 0, -0.01, 0.225, 0.175, 2.6),
        (0.52, 0, -0.005, 0.232, 0.17, 2.7),
        (0.58, 0, 0.0, 0.222, 0.155, 2.8),
        (0.625, 0, 0.0, 0.155, 0.12, 2.5),
        (0.66, 0, 0.0, 0.1, 0.09, 2.2),
    ])
    kit.paint(torso, SUIT)
    out = [torso]
    for s in (-1, 1):
        leg = kit.tube(f"pierna{s}", [(s * 0.1, 0, 0.34), (s * 0.103, -0.005, 0.23), (s * 0.106, -0.01, 0.13)],
                       [(0.1, 0.1), (0.096, 0.096), (0.09, 0.09)], e=2.3)
        arm = kit.tube(f"brazo{s}", [(s * 0.2, 0, 0.565), (s * 0.29, -0.005, 0.44), (s * 0.312, -0.04, 0.33)],
                       [(0.084, 0.084), (0.077, 0.075), (0.07, 0.068)], e=2.2)
        kit.paint(leg, SUIT)
        kit.paint(arm, SUIT)
        # El puño de la manga, con una franja del color del jugador.
        elbow, wrist = Vector((s * 0.29, -0.005, 0.44)), Vector((s * 0.312, -0.04, 0.33))
        cuff = kit.tube(f"puno_manga{s}", [elbow.lerp(wrist, 0.72), elbow.lerp(wrist, 0.93)], [(0.078, 0.076), (0.076, 0.074)], e=2.2, levels=1)
        kit.paint(cuff, BAND)
        out += [leg, arm, cuff]
    return out


def hands():
    out = []
    for s in (-1, 1):
        fist = kit.superellipsoid(f"puno{s}", (s * 0.326, -0.062, 0.264), (0.09, 0.085, 0.092), e=2.4)
        thumb = kit.tube(f"pulgar{s}", [(s * 0.29, -0.12, 0.303), (s * 0.282, -0.145, 0.27)], [(0.03, 0.03), (0.027, 0.027)], levels=1)
        kit.paint(fist, GLOVE)
        kit.paint(thumb, GLOVE)
        out += [fist, thumb]
    return out


def feet():
    out = []
    for s in (-1, 1):
        f = kit.superellipsoid(f"bota{s}", (s * 0.106, -0.035, 0.07), (0.095, 0.14, 0.07), e=2.4)
        ankle = kit.tube(f"tobillo{s}", [(s * 0.106, 0, 0.14), (s * 0.106, -0.005, 0.09)], [(0.08, 0.08), (0.084, 0.084)], levels=1)
        sole = kit.superellipsoid(f"suela{s}", (s * 0.106, -0.035, 0.016), (0.1, 0.146, 0.018), e=2.6)
        kit.paint(f, GLOVE)
        kit.paint(ankle, GLOVE)
        kit.paint(sole, SOLE)
        out += [f, ankle, sole]
    return out


def _on(targets, x, z, lift, back=False):
    """Punto sobre la superficie más cercana de targets en (x, z), mirando
    desde delante (o desde detrás), despegado lift por la normal."""
    best = None
    for t in targets:
        try:
            p, n = kit.hit(t, (x, 2 if back else -2, z), (0, -1 if back else 1, 0))
        except ValueError:
            continue
        if best is None or (p.y > best[0].y if back else p.y < best[0].y):
            best = (p, n)
    return best[0] + best[1] * lift


def gi(b, legs):
    """El cruce del kimono (la solapa derecha encima) y el cinturón anudado
    delante con sus dos puntas, que caen pegadas al cuerpo."""
    out = []
    for s, lift, path in ((-1, 0.004, [(0.1, 0.61), (0.06, 0.54), (0.02, 0.48)]),
                          (1, 0.008, [(0.1, 0.61), (0.06, 0.54), (0.0, 0.47), (-0.07, 0.41), (-0.1, 0.38)])):
        pts = []
        for x, z in path:
            p, n = kit.hit(b, (s * x, -2, z))
            pts.append(p + n * lift)
        lapel = kit.ribbon(f"solapa{s}", pts, [0.05, 0.055, 0.055, 0.05, 0.05][:len(pts)], 0.01, up=(0, -1, 0))
        kit.paint(lapel, LAPEL)
        kit.smooth_shade(lapel)
        out.append(lapel)
    ring = kit.band("cinturon", 0.36, 0.044, 0.21, 0.165, 2.6, cy=-0.005, grow=0.02)
    kit.paint(ring, BAND)
    out.append(ring)
    # Las puntas salen de debajo del nudo: anchas, cortas, un poco abiertas,
    # pegadas a la tripa.
    # Cuelgan como tela: desde el nudo bajan rectas, sin meterse en el hueco
    # entre las piernas.
    top = _on([ring], 0, 0.35, 0.02)
    for s in (-1, 1):
        pts = [Vector((s * x, top.y + 0.008 * i, z)) for i, (x, z) in
               enumerate([(0.01, 0.35), (0.02, 0.31), (0.032, 0.27), (0.045, 0.23)])]
        tail = kit.ribbon(f"punta{s}", pts, [0.05, 0.054, 0.058, 0.064], 0.014, up=(0, -1, 0))
        kit.paint(tail, BAND)
        kit.smooth_shade(tail)
        out.append(tail)
    # El nudo, redondo y abultado, encima de las puntas.
    p, n = kit.hit(ring, (0, -2, 0.36))
    knot = kit.superellipsoid("nudo", p + n * 0.014, (0.042, 0.026, 0.036), e=2.6)
    kit.paint(knot, BAND)
    out.append(knot)
    return out


def head():
    h = kit.loft("cabeza", [
        (0.6, 0, -0.01, 0.13, 0.12, 2.4),
        (0.64, 0, -0.015, 0.2, 0.18, 2.6),
        (0.7, 0, -0.015, 0.245, 0.215, 2.7),
        (0.8, 0, 0.0, 0.262, 0.24, 2.8),
        (0.9, 0, 0.005, 0.255, 0.235, 2.8),
        (0.98, 0, 0.01, 0.215, 0.2, 2.6),
        (1.03, 0, 0.01, 0.14, 0.13, 2.4),
        (1.05, 0, 0.01, 0.05, 0.05, 2.0),
    ], segs=32)
    kit.paint(h, SUIT)
    out = [h]
    # La cinta, justo por encima de los ojos, un poco ladeada.
    band = kit.band("cinta", 0.872, 0.05, 0.257, 0.236, 2.8, cy=0.004, grow=0.014)
    kit.paint(band, BAND)
    out.append(band)
    out += face(h, band)
    out += bow(h, band)
    return out


def face(h, band):
    """Ojos grandes incrustados en la tela y cejas sobre el borde de la cinta."""
    out = []
    for s in (-1, 1):
        x, z = s * 0.088, 0.772
        white = kit.decal(f"ojo{s}", kit.ellipse(0.058, 0.066), h, at=(x, z), lift=0.001, dome=0.016, thickness=0.012)
        kit.paint(white, EYE_WHITE)
        px, pz = x - s * 0.008, z - 0.004
        pupil = kit.decal(f"pupila{s}", kit.ellipse(0.044, 0.053), [white], at=(px, pz), lift=0.0008, dome=0.004, thickness=0.006)
        kit.paint(pupil, PUPIL)
        glint = kit.decal(f"brillo{s}", kit.ellipse(0.013, 0.016), [pupil], at=(px + 0.013, pz + 0.019), lift=0.0008, thickness=0.004, res=16)
        glint2 = kit.decal(f"brillo2{s}", kit.ellipse(0.006, 0.006), [pupil], at=(px - 0.014, pz - 0.022), lift=0.0008, thickness=0.004, res=12)
        kit.paint(glint, EYE_WHITE)
        kit.paint(glint2, EYE_WHITE)
        brow = kit.decal(f"ceja{s}", kit.stroke(0.1, 0.034, 0.02, arch=0.01, tilt=0.22, side=s), [band], at=(s * 0.09, 0.866), lift=0.002, dome=0.01, thickness=0.012, res=40)
        kit.paint(brow, BROW)
        out += [white, pupil, glint, glint2, brow]
    return out


def bow(h, band):
    """El lazo de la cinta en la nuca: el nudo y dos orejas sobre la cinta, y
    dos colas que bajan pegadas a la nuca, abriéndose un poco."""
    out = []
    knot_at = _on([band], 0, 0.872, 0.016, back=True)
    knot = kit.superellipsoid("nudo_lazo", knot_at, (0.042, 0.03, 0.038), e=2.2)
    kit.paint(knot, BAND)
    out.append(knot)
    for s in (-1, 1):
        # Oreja del lazo: una almohadilla de tela apoyada en la cinta.
        ear_at = _on([band], s * 0.07, 0.882, 0.014, back=True)
        ear = kit.superellipsoid(f"lazo{s}", ear_at, (0.066, 0.02, 0.04), e=2.3, rot=(0, s * 0.25, -s * 0.28))
        kit.paint(ear, BAND)
        out.append(ear)
        tail = [_on([band, h], s * x, z, lift, back=True) for x, z, lift in
                [(0.012, 0.852, 0.02), (0.028, 0.8, 0.009), (0.045, 0.74, 0.008), (0.06, 0.69, 0.008), (0.072, 0.65, 0.008)]]
        t = kit.ribbon(f"cola{s}", tail, [0.05, 0.06, 0.066, 0.07, 0.07], 0.012, up=(0, 1, 0))
        kit.paint(t, BAND)
        kit.smooth_shade(t)
        out.append(t)
    return out


def build():
    root = kit.empty("ninja")
    parts = body()
    neck = kit.empty("cabeza_raiz")
    neck.location = (0, 0, 0.62)
    for o in head():
        o.parent = neck
        o.matrix_parent_inverse = neck.matrix_world.inverted()
    neck.scale = (HEAD_SCALE,) * 3
    kit.parent_all(root, parts + hands() + feet() + gi(parts[0], [o for o in parts if o.name.startswith("pierna")]) + [neck])
    return root


def rules(name, side):
    """Huesos de cada pieza del cuerpo (la cabeza va aparte, entera)."""
    if name.startswith(("cuerpo", "solapa")):
        return ["cadera", "columna", "pecho"]
    if name.startswith("pierna"):
        return ["cadera", f"muslo.{side}", f"espinilla.{side}"]
    if name.startswith("brazo"):
        return ["pecho", f"brazo.{side}", f"antebrazo.{side}"]
    if name.startswith("puno_manga"):
        return [f"antebrazo.{side}"]
    if name.startswith(("puno", "pulgar")):
        return [f"mano.{side}"]
    if name.startswith(("bota", "tobillo", "suela")):
        return [f"pie.{side}"]
    if name.startswith(("cinturon", "nudo", "punta")):
        return ["cadera"]
    return None


def main():
    root = build()
    if "--rig" in ARGS or not ARGS or "--preview" in ARGS:
        import rig
        arm, _ = rig.skin(root, rules, "ninja")
        rig.animate(arm, ["reposo", "andar", "correr", "gatear"])
        if "--preview" in ARGS:
            rig.preview(arm, ARGS[ARGS.index("--preview") + 1], ARGS[ARGS.index("--anims") + 1].split(",") if "--anims" in ARGS else ["andar", "correr", "gatear"])
            return
    if "--sheet" in ARGS:
        import sheet
        sheet.render(root, ARGS[ARGS.index("--sheet") + 1], only=ARGS[ARGS.index("--views") + 1].split(",") if "--views" in ARGS else None)
    else:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "ninja.blend"))
        if "--glb" in ARGS or not ARGS:
            import rig
            rig.export(os.path.join(ART, "..", "assets", "models", "ninja.glb"))


main()
