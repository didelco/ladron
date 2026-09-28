#!/usr/bin/env python3
"""Las pegatinas de cabezas ninja del bocadillo de cuántos ladrones (Hud.pop_bubble).

    python3 tools/ninja_stickers.py            # escribe assets/ui/ninjas_1.png … ninjas_4.png
    python3 tools/ninja_stickers.py --out DIR  # o en otra carpeta, para mirarlas

Una, dos, tres o cuatro cabezas de ninja juntas, un poco solapadas, cada una del
color de su ladrón (COLOURS.thief…thief4 de scenes/main.gd, leídos de ahí). Planas:
formas sencillas de color liso, sin degradados ni volumen. Cabeza redonda, banda
negra con dos ojos blancos grandes y el nudo de la banda con dos colas detrás; cada
cabeza con un filo blanco que la separa de la de detrás. Todo el grupo con un
contorno blanco grueso y una sombra plana, como una pegatina. Se dibujan a mano
(PIL, sin numpy) con supermuestreo, y salen a 2x del tamaño con que se ven (SIZE):
el juego las pone a color o apagadas con un shader, así que no hay versión oscura.
"""

import argparse
import math
import os
import re

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Lo que ocupa en el bocadillo, en píxeles del juego; el PNG sale a 2x.
SIZE = (120, 80)
OUT_SCALE = 2
# Se dibuja a 4x del PNG y se reduce: bordes suaves.
SUPER = 4
# Diámetro de cada cabeza según cuántas son (en píxeles del juego).
HEAD = {1: 56, 2: 46, 3: 38, 4: 31}
# Cuánto se separan los centros, en diámetros (menos de 1: se solapan).
STEP = 0.66
# Un poco de baile: altura (en diámetros) y giro (grados) de cada una.
BOB = [0.0, -0.07, 0.03, -0.05]
TILT = [-6.0, 5.0, -4.0, 7.0]
# La pegatina: contorno blanco y sombra plana, en píxeles del juego.
OUTLINE = 5.0
SHADOW_DROP = 3.0
SHADOW_ALPHA = 0.35
# El filo blanco de cada cabeza, en diámetros.
RIM = 0.05

BAND = (20, 16, 28)
WHITE = (255, 255, 255)


def thief_colours():
    """Los colores de los ladrones, de COLOURS en scenes/main.gd."""
    src = open(os.path.join(ROOT, "scenes", "main.gd"), encoding="utf-8").read()
    found = dict(re.findall(r'"(thief\d?)":\s*Color\("#([0-9a-fA-F]{6})"\)', src))
    return [tuple(int(found[k][i:i + 2], 16) for i in (0, 2, 4)) for k in ["thief", "thief2", "thief3", "thief4"]]


def head(d, colour):
    """Una cabeza de d píxeles de diámetro, en una capa cuadrada suya, mirando un
    poco a la derecha: el nudo y sus colas asoman por detrás, a la izquierda."""
    size = int(d * 1.9)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g = ImageDraw.Draw(layer)
    c = size / 2
    r = d / 2
    rim = d * RIM

    def disc(x, y, rad, fill, img=None):
        (ImageDraw.Draw(img) if img else g).ellipse((x - rad, y - rad, x + rad, y + rad), fill=fill)

    # The knot's two tails and the knot, behind the head's left side.
    kx, ky = c - r * 0.9, c - r * 0.12
    g.polygon([(kx, ky - r * 0.16), (kx - r * 0.5, ky - r * 0.62), (kx - r * 0.78, ky - r * 0.34), (kx - r * 0.12, ky + r * 0.12)], fill=BAND)
    g.polygon([(kx, ky + r * 0.0), (kx - r * 0.66, ky + r * 0.16), (kx - r * 0.6, ky + r * 0.56), (kx - r * 0.02, ky + r * 0.2)], fill=BAND)
    disc(kx, ky, r * 0.22, BAND)
    # The head: a white rim, then the colour, flat.
    disc(c, c, r + rim, WHITE)
    disc(c, c, r, colour)
    # The band across the eyes, cut to the head.
    mask = Image.new("L", (size, size), 0)
    disc(c, c, r, 255, mask)
    band = Image.new("L", (size, size), 0)
    ImageDraw.Draw(band).rectangle((0, c - r * 0.3, size, c + r * 0.16), fill=255)
    layer.paste(BAND, (0, 0), ImageChops.multiply(mask, band))
    # Two big white eyes poking out of the band, looking a little right.
    for ex in (c - r * 0.2, c + r * 0.38):
        ey = c - r * 0.07
        w, h = r * 0.24, r * 0.3
        g.ellipse((ex - w, ey - h, ex + w, ey + h), fill=WHITE)
        disc(ex + w * 0.35, ey + h * 0.1, w * 0.5, BAND)
    return layer


def dilate(alpha, radius):
    """alpha grown by radius in every direction, round: the most of it shifted
    to every point of a disc (the canvas has room round it, so nothing wraps in)."""
    out = alpha.copy()
    rad = int(math.ceil(radius))
    for dy in range(-rad, rad + 1):
        for dx in range(-rad, rad + 1):
            if dx * dx + dy * dy <= radius * radius:
                out = ImageChops.lighter(out, ImageChops.offset(alpha, dx, dy))
    return out


def sticker(n, colours):
    """The sticker for n thieves, at OUT_SCALE."""
    k = OUT_SCALE * SUPER
    w, h = SIZE[0] * k, SIZE[1] * k
    art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = HEAD[n] * k
    step = d * STEP
    # The whole group, knots and all, centred; a touch of room below for the shadow.
    left = d * 0.62
    span = left + step * (n - 1) + d * 0.5
    x0 = (w - span) / 2 + left
    y0 = h / 2 - SHADOW_DROP * k * 0.5
    # From the back (the last, on the right) to the front (the first).
    for i in reversed(range(n)):
        layer = head(d, colours[i]).rotate(TILT[i], resample=Image.BICUBIC)
        cx, cy = x0 + step * i, y0 + BOB[i] * d
        art.alpha_composite(layer, (round(cx - layer.width / 2), round(cy - layer.height / 2)))
    # The outline and shadow are worked at half the drawing's size: plenty.
    half = art.resize((w // 2, h // 2), Image.LANCZOS)
    s = k // 2
    edge = dilate(half.getchannel("A"), OUTLINE * s)
    shadow = ImageChops.offset(edge, 0, round(SHADOW_DROP * s)).point(lambda v: round(v * SHADOW_ALPHA))
    out = Image.new("RGBA", half.size, (0, 0, 0, 0))
    out.putalpha(shadow)
    white = Image.new("RGBA", half.size, WHITE + (0,))
    white.putalpha(edge)
    out.alpha_composite(white)
    out.alpha_composite(half)
    return out.resize((SIZE[0] * OUT_SCALE, SIZE[1] * OUT_SCALE), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "ui"), help="la carpeta (assets/ui)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    colours = thief_colours()
    for n in range(1, 5):
        path = os.path.join(args.out, "ninjas_%d.png" % n)
        sticker(n, colours).save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    main()
