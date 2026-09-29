#!/usr/bin/env python3
"""La auditoría de colores y la paleta propuesta (docs/, página «Paleta propuesta»).

    python3 tools/palette.py            # escribe docs/data/paleta_propuesta.js
    python3 tools/docs.py build palette # lo mismo, desde docs.py (sin abrir Godot)

Es una PROPUESTA pendiente de aprobar: todavía no se ha aplicado al juego.

El inventario se saca del código de cada momento: cada Color(...) y cada "#rrggbb"
de los .gd, .gdshader, .tscn y .tres (sin tests/ ni docs/), el color base de cada
material de los .glb de assets/, las paletas de los museos (logic/story.gd) y los
colores de los temas (docs/data/catalogo.json, que escribe tools/capture_docs.gd).
Cada color se clasifica (interfaz, mundo, juego, ilustración, convención), se agrupa
por familia y con los casi iguales (ΔE00 < 5), y se le busca su color de la paleta
propuesta. La propuesta en sí (los 16 colores, la tabla de paso de las constantes
clave, la regla de los museos) está escrita a mano aquí abajo: es lo que se discute.

Sale de la auditoría que se hizo aparte (scratchpad/paleta: extract.py, glb.py,
build.py, museums.py, page.py), adaptada a main: la historia de cinco museos ya
está unida, así que las paletas de museo se leen de logic/story.gd.
"""

import collections
import glob
import itertools
import json
import math
import os
import re
import struct
import subprocess
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
DATA = os.path.join(DOCS, "data")
BACKDROP = os.path.join(ROOT, "assets", "ui", "fondo_menu.png")
BACKDROP_OUT = os.path.join(DOCS, "assets", "paleta", "fondo.webp")


# --- Color: sRGB, luminancia, Lab, ΔE00 y daltonismo -----------------------------------

def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb2hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(x * 255))) for x in c)


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def unlin(c):
    c = max(0, min(1, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def rel_lum(h):
    r, g, b = [lin(x) for x in hex2rgb(h)]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted([rel_lum(a), rel_lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)


def lab_lin(rgb):
    r, g, b = rgb
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


_LAB = {}


def lab(h):
    if h not in _LAB:
        _LAB[h] = lab_lin([lin(x) for x in hex2rgb(h)])
    return _LAB[h]


def lch(h):
    L, a, b = lab(h)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def de2000(l1, l2):
    L1, a1, b1 = l1
    L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360
    h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dLp, dCp = L2 - L1, C2p - C1p
    dh = h2p - h1p
    if C1p * C2p == 0:
        dh = 0
    elif dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh / 2))
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    hs = h1p + h2p
    if C1p * C2p == 0:
        hbp = hs
    elif abs(h1p - h2p) <= 180:
        hbp = hs / 2
    else:
        hbp = (hs + 360) / 2 if hs < 360 else (hs - 360) / 2
    T = (1 - 0.17 * math.cos(math.radians(hbp - 30)) + 0.24 * math.cos(math.radians(2 * hbp))
         + 0.32 * math.cos(math.radians(3 * hbp + 6)) - 0.20 * math.cos(math.radians(4 * hbp - 63)))
    dth = 30 * math.exp(-((hbp - 275) / 25) ** 2)
    Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7))
    Sl = 1 + 0.015 * (Lbp - 50) ** 2 / math.sqrt(20 + (Lbp - 50) ** 2)
    Sc = 1 + 0.045 * Cbp
    Sh = 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dth)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))


# Machado (2009), al 100 %.
CVD = {
    "normal": None,
    "protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
CVD_NAMES = {"normal": "Visión normal", "protan": "Protanopia", "deutan": "Deuteranopia", "tritan": "Tritanopia"}


def sim(h, kind):
    c = [lin(x) for x in hex2rgb(h)]
    m = CVD[kind]
    if m is None:
        return c
    return [max(0, min(1, sum(m[i][j] * c[j] for j in range(3)))) for i in range(3)]


def simhex(h, kind):
    return rgb2hex([unlin(x) for x in sim(h, kind)])


_DE = {}


def dE(a, b, kind="normal"):
    k = (a, b, kind)
    if k not in _DE:
        _DE[k] = de2000(lab(a) if kind == "normal" else lab_lin(sim(a, kind)),
                        lab(b) if kind == "normal" else lab_lin(sim(b, kind)))
    return _DE[k]


def lerp(a, b, t):
    A, B = hex2rgb(a), hex2rgb(b)
    return rgb2hex([x + (y - x) * t for x, y in zip(A, B)])


# --- La propuesta (a mano: es lo que se discute) ---------------------------------------

# id, nombre, hex, grupo, uso, tonos
PAL = [
    ("noche", "Noche", "#0e0a1a", "Morados", "Fondo, cielo del museo, contornos, tinta de las figuras, zócalos", [("Noche profunda", "#08060f")]),
    ("ciruela", "Ciruela", "#1c1433", "Morados", "Cristal ahumado de menús y HUD, paneles, bloques del mapa, piedra oscura", []),
    ("berenjena", "Berenjena", "#2e2150", "Morados", "Cristal con foco, suelos, papel pintado neutro, calles del mapa", [("Berenjena clara", "#3d2d66")]),
    ("violeta", "Violeta", "#4b3a7e", "Morados", "Bordes, juntas, muros altos, luz de relleno y ambiente", [("Violeta luz", "#6a5aa8")]),
    ("lavanda", "Lavanda", "#9a8cc8", "Morados", "Texto secundario, rebordes de cristal, humo, acero, cristal de vitrina", [("Lavanda clara", "#c4b9e6")]),
    ("lila", "Lila", "#ece6fb", "Morados", "Texto principal, brillos, luz de linterna fría", []),
    ("nogal", "Nogal", "#35211a", "Marrones", "Madera oscura: zócalos, marcos, paneles de aviso", [("Madera", "#6b4a2e")]),
    ("laton", "Latón", "#d8ac5c", "Marrones", "Molduras, anillos, herrajes, marcos dorados", [("Pergamino", "#eadbb8"), ("Latón viejo", "#8a6a3a")]),
    ("vino", "Vino", "#6e1f3a", "Marrones", "Terciopelo, estandartes, papel medieval, uniforme del guardia", [("Vino claro", "#9b3a5a")]),
    ("oro", "Oro", "#ffc35c", "Acento", "Foco de los menús, lámparas, brillo de la pieza, primer aviso de sospecha", [("Oro claro", "#fff0d6")]),
    ("l1", "Turquesa", "#5ee6d0", "Juego", "Ladrón 1", [("Turquesa oscuro", "#17695d")]),
    ("l2", "Mandarina", "#ff8c3a", "Juego", "Ladrón 2 (y segundo aviso de sospecha)", [("Mandarina oscura", "#8a4412")]),
    ("l3", "Orquídea", "#d868b7", "Juego", "Ladrón 3", [("Orquídea oscura", "#6e2a5c")]),
    ("l4", "Cielo", "#64aaff", "Juego", "Ladrón 4", [("Cielo oscuro", "#1f4f8f")]),
    ("rojo", "Alarma", "#ff4d6a", "Juego", "Guardia (marcas), alerta, alarma, «!!!»", [("Alarma oscura", "#8a1f33")]),
    ("menta", "Menta", "#9df0b0", "Juego", "Salida, a salvo, interruptor encendido, «hecho»", [("Menta oscura", "#25683f")]),
]
P = {p[0]: p[2] for p in PAL}


def tone(idx):
    pid, _, n = idx.partition(":")
    p = [x for x in PAL if x[0] == pid][0]
    return (p[1], p[2]) if not n else tuple(p[5][int(n) - 1])


# Los colores con significado, a mano: hex de hoy -> tono de la paleta.
SEM = {
    "#2ec4a6": "l1", "#12705f": "l1:1", "#f0a13a": "l2", "#8a5410": "l2:1", "#b07cff": "l3", "#5b3a99": "l3:1", "#4dabf7": "l4", "#1c5d99": "l4:1",
    "#9b2c3f": "vino", "#5e1826": "rojo:1", "#c42a3c": "rojo", "#b8324c": "rojo", "#6e1a2c": "rojo:1", "#ff3d6e": "rojo", "#ff3048": "rojo", "#e03131": "rojo", "#e2262f": "rojo",
    "#22d3ee": "menta", "#4ade80": "menta", "#0e7490": "menta:1", "#ffd43b": "oro", "#ff922b": "l2", "#ffe066": "oro", "#ffd479": "oro:1", "#ffa94d": "oro", "#f87171": "rojo", "#eef3ff": "lila",
    "#ffae42": "oro", "#fff0d6": "oro:1", "#f0c46a": "oro", "#b45309": "l2:1", "#ff8c2e": "l2", "#5cc98a": "menta", "#e8594f": "rojo", "#c77dff": "l3", "#ff7a7a": "rojo",
}
# Los de la interfaz y el mundo que no van al más cercano.
UIFIX = {
    "#f1dfbd": "lila", "#e8d6b4": "laton:1", "#2a160d": "noche", "#1c1210": "noche", "#b9a07a": "lavanda", "#150f24": "ciruela", "#241838": "berenjena", "#8f82b8": "lavanda",
    "#eef2ff": "lila", "#9aa0c8": "lavanda", "#0b0820": "ciruela", "#140f2e": "ciruela", "#241d52": "berenjena", "#35211a": "nogal", "#4a2f24": "nogal:1", "#120906": "noche:1", "#d8ac5c": "laton", "#7a5a32": "laton:2",
    "#6256aa": "violeta:1", "#6a5a9a": "violeta:1", "#8a7aa8": "violeta:1", "#b8a8d8": "lavanda:1", "#c8c0e0": "lavanda:1", "#8ea2ff": "violeta:1", "#8f9cff": "violeta:1", "#0a0918": "noche", "#0f0d14": "noche", "#08070c": "noche:1",
    "#ffc47e": "oro:1", "#ffb45a": "oro", "#fff1d8": "oro:1", "#ffc98a": "oro:1", "#ffd9a0": "oro:1", "#fff1c8": "oro:1", "#ffe7a8": "oro:1", "#5a3a26": "nogal:1", "#5c1f33": "vino", "#140c24": "noche", "#1a0f2e": "noche",
}

# Las constantes clave, una a una: clase, constante, fichero, hex de hoy, tono, nota.
PASO = [
    ("Interfaz", "Hud.GLASS", "scenes/hud.gd", "#150f24", "ciruela", "al 84 % como ahora"),
    ("Interfaz", "Hud.GLASS_LIT", "scenes/hud.gd", "#241838", "berenjena", "al 92 %"),
    ("Interfaz", "Hud.GLASS_EDGE", "scenes/hud.gd", "#8f82b8", "lavanda", "al 50 %"),
    ("Interfaz", "Hud.GLOW", "scenes/hud.gd", "#ffae42", "oro", "el foco"),
    ("Interfaz", "Hud.GLOW_TEXT", "scenes/hud.gd", "#fff0d6", "oro:1", ""),
    ("Interfaz", "Hud.CREAM", "scenes/hud.gd", "#f1dfbd", "lila", "texto sobre cristal; en Glyph, la cara de la tecla"),
    ("Interfaz", "Hud.INK", "scenes/hud.gd", "#2a160d", "noche", "tinta sobre claro"),
    ("Interfaz", "Hud.INK_SOFT", "scenes/hud.gd", "#b9a07a", "lavanda", ""),
    ("Interfaz", "Hud.WALNUT · _EDGE · _LIT", "scenes/hud.gd", "#35211a", "nogal", "LIT → Madera; EDGE → Noche profunda"),
    ("Interfaz", "Hud.BRASS · BRASS_DARK", "scenes/hud.gd", "#d8ac5c", "laton", "DARK → Latón viejo"),
    ("Interfaz", "Hud.C.text", "scenes/hud.gd", "#eef2ff", "lila", ""),
    ("Interfaz", "Hud.C.dim", "scenes/hud.gd", "#9aa0c8", "lavanda", ""),
    ("Interfaz", "Hud.C.gold", "scenes/hud.gd", "#ffe066", "oro", "se funde con el foco"),
    ("Interfaz", "Hud.C.panel · _ia (#140f2e)", "scenes/hud.gd", "#0b0820", "ciruela", ""),
    ("Interfaz", "MenuStage.CREAM · INK", "scenes/menu_stage.gd", "#e8d6b4", "laton:1", "INK → Noche"),
    ("Interfaz", "MenuStage.LILAC · LILAC_DARK · WALL", "scenes/menu_stage.gd", "#7a6496", "violeta:1", "DARK → Violeta; WALL → Lavanda"),
    ("Interfaz", "MenuStage.PINK · PINK_DARK · VELVET", "scenes/menu_stage.gd", "#7a2e44", "vino", "DARK → Vino"),
    ("Interfaz", "MenuStage.MINT · GRASS · GRASS_NIGHT", "scenes/menu_stage.gd", "#4f8a7a", "violeta", "el césped de la maqueta, a violeta nocturno (o Musgo del museo de naturaleza)"),
    ("Interfaz", "MenuStage.SOIL · WOOD", "scenes/menu_stage.gd", "#5a3a26", "nogal:1", ""),
    ("Interfaz", "MenuStage.GOLD", "scenes/menu_stage.gd", "#d8ac5c", "laton", ""),
    ("Interfaz", "MenuStage.CASE", "scenes/menu_stage.gd", "#8fc4d6", "lavanda:1", "el cristal de vitrina"),
    ("Interfaz", "MenuStage.GUARD · GUARD_DARK", "scenes/menu_stage.gd", "#b8324c", "vino", "uniforme; las marcas en Alarma"),
    ("Interfaz", "MenuStage BACKS (9 fondos)", "scenes/menu_stage.gd", "#15112a", "ciruela", "todos a Ciruela o Noche"),
    ("Interfaz", "TitleScreen.BACK", "scenes/title_screen.gd", "#140c24", "noche", ""),
    ("Mundo", "NightEnv.BACKGROUND", "scenes/night_env.gd", "#0a0918", "noche", ""),
    ("Mundo", "NightEnv.AMBIENT_COLOUR", "scenes/night_env.gd", "#6256aa", "violeta:1", "la luz ambiente"),
    ("Mundo", "NightEnv.MOON_COLOUR · fill lights (#8f9cff)", "scenes/night_env.gd", "#8ea2ff", "violeta:1", "un solo tono de luna"),
    ("Mundo", "Scenery.ROOM_LIGHT · SCONCE · pool (#ffb45a)", "scenes/scenery.gd", "#ffc47e", "oro", "lámparas cálidas, un tono"),
    ("Mundo", "Scenery.TORCH_COLOUR · linternas", "scenes/scenery.gd", "#fff1d8", "oro:1", ""),
    ("Mundo", "Main.COLOURS.cone", "scenes/main.gd", "#ffd479", "oro:1", "el cono en calma"),
    ("Mundo", "Main.COLOURS.cone_alert", "scenes/main.gd", "#ffa94d", "oro", "el cono inquieto"),
    ("Mundo", "MuseumView.C.night · ink · core", "scenes/museum_view.gd", "#0f0d14", "noche", ""),
    ("Mundo", "MuseumView.C.floor · wall_side · case_dark", "scenes/museum_view.gd", "#2b2834", "berenjena", "Ciruela para los lados"),
    ("Mundo", "MuseumView.C.wall_top · wall_cap · stone", "scenes/museum_view.gd", "#544a5e", "violeta", ""),
    ("Mundo", "MuseumView.C.gold · gold_dim", "scenes/museum_view.gd", "#f0c46a", "oro", "DIM → Latón viejo"),
    ("Mundo", "MuseumView.C.bone · bone_dark", "scenes/museum_view.gd", "#e8ddc0", "laton:1", ""),
    ("Mundo", "MuseumView.C.crimson", "scenes/museum_view.gd", "#9b2c3f", "vino", ""),
    ("Mundo", "MuseumView.C.glass", "scenes/museum_view.gd", "#a8d8e8", "lavanda:1", ""),
    ("Mundo", "SmokeFx LIGHT · MID · DARK", "scenes/smoke_fx.gd", "#e8e4dc", "lila", "MID → Lavanda clara; DARK → Lavanda"),
    ("Mundo", "CityStage GROUND · GRASS · GROUND_SIDE", "scenes/city_stage.gd", "#2a2140", "berenjena", "la ciudad de la historia"),
    ("Mundo", "CityStage ROAD · ROAD_LIT · ROAD_DASH", "scenes/city_stage.gd", "#8a7358", "laton", "DASH → Pergamino"),
    ("Mundo", "CityStage RIVER · RING · LOCK", "scenes/city_stage.gd", "#27407a", "l4", "RING → Oro; LOCK → Lavanda"),
    ("Mundo", "Hud.MAP_FLOOR · MapStage paper", "scenes/hud.gd", "#e8d6b4", "laton:1", "Pergamino; ver riesgos"),
    ("Mundo", "Hud.MAP_INK · MAP_WALL · MAP_ROUTE", "scenes/hud.gd", "#1c1210", "noche", "WALL → Nogal; ROUTE → Madera"),
    ("Juego", "Main.COLOURS.thief · thief_dark", "scenes/main.gd", "#2ec4a6", "l1", ""),
    ("Juego", "Main.COLOURS.thief2 · thief2_dark", "scenes/main.gd", "#f0a13a", "l2", "más rojiza, para no ser el foco"),
    ("Juego", "Main.COLOURS.thief3 · thief3_dark", "scenes/main.gd", "#b07cff", "l3", "deja el violeta: se perdía en el fondo"),
    ("Juego", "Main.COLOURS.thief4 · thief4_dark", "scenes/main.gd", "#4dabf7", "l4", ""),
    ("Juego", "Main.COLOURS.guard · guard_dark", "scenes/main.gd", "#9b2c3f", "vino", "el cuerpo en Vino; aro, cono visto y marcas en Alarma"),
    ("Juego", "Main.COLOURS.alert · Hud.C.alert · RED", "scenes/main.gd", "#ff3d6e", "rojo", ""),
    ("Juego", "Hud.MAP_GUARD · MapEditor.GUARD", "scenes/hud.gd", "#c42a3c", "rojo:1", "sobre pergamino, el oscuro"),
    ("Juego", "Main.COLOURS.safe · Hud.C.safe", "scenes/main.gd", "#22d3ee", "menta", "a salvo = salida"),
    ("Juego", "Main.COLOURS.switch_on · C.green · emergency", "scenes/main.gd", "#4ade80", "menta", ""),
    ("Juego", "Main.COLOURS.switch_off", "scenes/main.gd", "#f87171", "rojo", ""),
    ("Juego", "SUSPICION / ALARM 1", "scenes/scenery.gd", "#ffd43b", "oro", "«!»"),
    ("Juego", "SUSPICION / ALARM 2", "scenes/scenery.gd", "#ff922b", "l2", "«!!» (ver dudas)"),
    ("Juego", "SUSPICION / ALARM 3", "scenes/scenery.gd", "#ff3048", "rojo", "«!!!»"),
    ("Juego", "Panel de alarma (#ff922b)", "scenes/scenery.gd", "#ff922b", "oro", "el panel, en Oro"),
    ("Juego", "Pieza en el plano y la leyenda", "scenes/hud.gd", "#74c0fc", "oro", "marca fija: rombo Oro con borde Lila"),
]

# Familia -> paleta.
FAMTO = [
    ("Morados de noche", "Noche · Ciruela · Berenjena", "noche", "ciruela", "berenjena"),
    ("Lilas y lavandas", "Violeta · Lavanda · Lila", "violeta", "lavanda", "lila"),
    ("Violetas vivos", "Orquídea (juego) o Violeta luz (mundo)", "l3", "violeta:1"),
    ("Azules", "Cielo (ladrón 4) o Violeta luz (luces frías)", "l4", "violeta:1"),
    ("Cian y turquesa", "Turquesa (ladrón 1); cristal → Lavanda clara", "l1", "lavanda:1"),
    ("Verdes", "Menta (salida); plantas → Musgo de naturaleza", "menta", "menta:1"),
    ("Amarillos y oro vivo", "Oro", "oro", "oro:1"),
    ("Latón y oro", "Latón · Latón viejo · Oro", "laton", "laton:2", "oro"),
    ("Naranjas", "Mandarina (ladrón 2) · Oro (luces)", "l2", "oro"),
    ("Marrones y madera", "Nogal · Madera", "nogal", "nogal:1"),
    ("Cremas, huesos y pergamino", "Pergamino · Oro claro · Lila", "laton:1", "oro:1", "lila"),
    ("Rojos, carmesí y vino", "Vino (mundo) · Alarma (juego)", "vino", "vino:1", "rojo"),
    ("Rosas", "Orquídea · Vino claro", "l3", "vino:1"),
    ("Grises y humo", "Lavanda · Lavanda clara · Violeta", "lavanda", "lavanda:1", "violeta"),
    ("Blancos", "Lila · Oro claro", "lila", "oro:1"),
    ("Negros", "Noche · Noche profunda", "noche", "noche:1"),
]

# El tono de cada museo, y qué pone en las molduras.
TONE = {
    "prehistoria": ("Ocre", "#b8773a", "laton"), "naturaleza": ("Musgo", "#4f7f45", "laton"),
    "antiguo": ("Lapislázuli", "#3a58a8", "oro"), "edad_media": ("Vino", "#6e1f3a", "laton"), "moderna": ("Rosa pop", "#b04a90", "lila"),
}
THEME_NAMES = {"prehistoria": "Prehistoria", "naturaleza": "Naturaleza", "antiguo": "Mundo antiguo", "edad_media": "Edad Media", "moderna": "Edad moderna"}
# Las telas de las vitrinas, propuestas.
CLOTH_NEW = {"antiguo": "#eadbb8", "edad_media": "#6e1f3a", "prehistoria": "#8a6a3a", "naturaleza": lerp("#35211a", "#4f7f45", 0.5), "moderna": "#c4b9e6"}

# Los colores de juego de hoy (se leen de Main.COLOURS si están) y los propuestos.
CUR_FROM = {"Ladrón 1": "thief", "Ladrón 2": "thief2", "Ladrón 3": "thief3", "Ladrón 4": "thief4", "Guardia": "guard", "Alerta": "alert", "A salvo": "safe"}
CUR = {"Ladrón 1": "#2ec4a6", "Ladrón 2": "#f0a13a", "Ladrón 3": "#b07cff", "Ladrón 4": "#4dabf7", "Guardia": "#9b2c3f", "Alerta": "#ff3d6e",
       "A salvo": "#22d3ee", "Salida": "#4ade80", "Foco": "#ffae42", "Panel/sospecha": "#ff922b"}
NEW = {"Ladrón 1": P["l1"], "Ladrón 2": P["l2"], "Ladrón 3": P["l3"], "Ladrón 4": P["l4"], "Guardia": P["rojo"], "Alerta": P["rojo"],
       "A salvo": P["menta"], "Salida": P["menta"], "Foco": P["oro"], "Panel/sospecha": P["oro"]}


# --- Inventario: lo que hay en el código --------------------------------------------------

RX_COLOR = re.compile(r'Color\(\s*([^()]*?(?:\([^()]*\)[^()]*?)*)\)')
RX_HEXSTR = re.compile(r'"#?([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)"')
NUM = r'-?\d*\.?\d+(?:e-?\d+)?'


def _h(r, g, b):
    c = lambda x: max(0, min(255, round(float(x) * 255)))
    return "#%02x%02x%02x" % (c(r), c(g), c(b))


def extract():
    """Cada Color(...) y "#rrggbb" del código, con su fichero, línea y contexto."""
    out, files = [], []
    for d, _, fs in os.walk(ROOT):
        rel = os.path.relpath(d, ROOT)
        top = rel.split(os.sep)[0]
        if top in (".godot", "docs", ".claude", "tests", ".git", "build", "brain"):
            continue
        for f in fs:
            if f.endswith((".gd", ".gdshader", ".tscn", ".tres")):
                files.append(os.path.join(d, f))
    for p in sorted(files):
        rel = os.path.relpath(p, ROOT)
        for i, line in enumerate(open(p, encoding="utf-8", errors="ignore"), 1):
            s = line.strip()
            if s.startswith("#") and not s.startswith("#!"):
                continue
            seen = set()
            for m in RX_COLOR.finditer(line):
                parts = [x.strip() for x in m.group(1).strip().split(",")]
                hx, kind = None, "expr"
                if parts and re.fullmatch(r'"#?[0-9a-fA-F]{6,8}"', parts[0]):
                    v = parts[0].strip('"#')
                    hx, kind = "#" + v[:6].lower(), "hex"
                    seen.add(v.lower())
                elif len(parts) >= 3 and all(re.fullmatch(NUM, x) for x in parts[:3]):
                    hx, kind = _h(*parts[:3]), "rgb"
                out.append(dict(file=rel, line=i, kind=kind, hex=hx, ctx=s[:160]))
            for m in RX_HEXSTR.finditer(line):
                v = m.group(1).lower()
                if v in seen or line.find('Color("' + m.group(1)) >= 0:
                    continue
                out.append(dict(file=rel, line=i, kind="hexstr", hex="#" + v[:6], ctx=s[:160]))
    return out


def glb_materials():
    """El color base de cada material de cada .glb de assets/, en sRGB."""
    res = {}
    for p in sorted(glob.glob(os.path.join(ROOT, "assets", "**", "*.glb"), recursive=True)):
        b = open(p, "rb").read()
        n = struct.unpack("<I", b[12:16])[0]
        j = json.loads(b[20:20 + n])
        mats = []
        for m in j.get("materials", []):
            pbr = m.get("pbrMetallicRoughness", {})
            f = pbr.get("baseColorFactor", [1, 1, 1, 1])
            mats.append((m.get("name", ""), rgb2hex([unlin(x) for x in f[:3]]), "baseColorTexture" in pbr))
        res[os.path.relpath(p, ROOT)] = mats
    return res


UI_FILES = ["scenes/hud.gd", "scenes/menu_stage.gd", "scenes/title_screen.gd", "scenes/prompt.gd", "scenes/minigame_box.gd", "scenes/glyph.gd",
            "scenes/lesson_stage.gd", "scenes/map_editor.gd", "scenes/minigame_view.gd", "scenes/minigame_stage.gd", "scenes/minigame_views/steady.gd",
            "scenes/minigame_views/sneeze.gd", "scenes/minigame_views/arcade.gd", "tools/capture_docs.gd"]
SEMANTIC = [r'"thief', r'"guard', r'"alert"', r'"safe"', r'"green"', r'"switch_', r'"cone', r'SUSPICION_COLOURS', r'ALARM_COLOURS', r'GANG',
            r'MAP_GUARD', r'const (THIEF|GUARD|EXIT|PIECE|PROP|RED|GREEN|ORANGE|GUARD_DARK) ', r'"emergency"', r'"gold":', r'#ff922b', r'#4ade80', r'LOOT_COLOURS',
            r'"colour": "#', r'"colours": \[', r'#2ec4a6', r'#ff3048', r'#ff3d6e', r'"lit"']


def klass(f, ctx):
    """ui, mundo, juego, ilustracion, convencion o historico."""
    if f == "art/botin/primitivas.gd":
        return "historico"
    if f == "scenes/canvases.gd" or (re.search(r'img\.(fill|set_pixel|fill_rect)', ctx) and f in ("scenes/museum_view.gd", "scenes/props_view.gd")):
        return "ilustracion"
    if f == "scenes/glyph.gd" and "Hud." not in ctx:
        return "convencion"
    if f in ("logic/story.gd", "logic/loot_gen.gd", "logic/map_file.gd") and ('"loot"' in ctx or '"colours"' in ctx or "m.loot" in ctx):
        return "juego"
    if f == "logic/story.gd" and '"name": "MUSEUM' in ctx:
        return "mundo"
    if f == "logic/themes.gd":
        return "mundo"
    if f == "scenes/minigame_views/wires.gd":
        return "juego"
    # La recreativa (MuseumView.ARCADE_GAMES), como los cuadros: ilustración.
    if f == "scenes/museum_view.gd" and re.search(r'"(mueble|marquesina|screen|ink|art)"|"[a-z]": "#', ctx):
        return "ilustracion"
    for r in SEMANTIC:
        if re.search(r, ctx):
            if f == "scenes/museum_view.gd" and '"gold"' in ctx:
                return "mundo"
            return "juego"
    if f == "scenes/hud.gd" and re.search(r'MAP_|img\.|mark\.call|_stamp|ambient', ctx):
        return "mundo"
    if f in UI_FILES:
        return "ui"
    return "mundo"


AREAS = {
    "scenes/hud.gd": "HUD y menús", "scenes/menu_stage.gd": "Escenitas de menú (MenuStage)", "scenes/lesson_stage.gd": "Lecciones (LessonStage)",
    "scenes/museum_view.gd": "Museo (MuseumView)", "logic/story.gd": "Historia (Story)", "logic/themes.gd": "Temas (Themes)", "logic/loot_gen.gd": "Piezas generadas (LootGen)",
    "scenes/main.gd": "Partida (Main)", "scenes/night_env.gd": "La noche (NightEnv)", "scenes/scenery.gd": "El mundo 3D de la ronda (Scenery)", "scenes/preview_stand.gd": "Peana de la vista previa (PreviewStand)", "scenes/house_run.gd": "La casa en juego (HouseRun)", "scenes/brief_screens.gd": "Prólogo y ficha de la noche (BriefScreens)", "scenes/settings_screens.gd": "Ajustes y assets (SettingsScreens)", "scenes/challenge_screens.gd": "Retos (ChallengeScreens)", "scenes/canvases.gd": "Cuadros (Canvases)", "scenes/city_stage.gd": "La ciudad y el museo en 3D (CityStage)", "scenes/tour.gd": "La previa de la historia (Tour)", "scenes/plan_talk.gd": "Lo que se cuenta sobre el plano (PlanTalk)", "scenes/map_stage.gd": "Plano del plan (MapStage)",
    "scenes/bean.gd": "Guardias (Bean)", "scenes/figure.gd": "Figuras (Figure)", "scenes/glyph.gd": "Botones del mando (Glyph)", "scenes/smoke_fx.gd": "Humo (SmokeFx)", "scenes/fx.gd": "Efectos (Fx)",
    "scenes/props_view.gd": "Objetos (PropsView)", "scenes/map_editor.gd": "Editor de mapas", "scenes/loot_models.gd": "Piezas (LootModels)", "scenes/prompt.gd": "Avisos (Prompt)",
    "scenes/title_screen.gd": "Portada", "scenes/minigame_box.gd": "Caja de minijuego", "scenes/minigame_view.gd": "Minijuegos (vista)", "scenes/minigame_stage.gd": "Minijuegos (escena)",
    "art/botin/primitivas.gd": "Piezas antiguas (histórico)", "tools/capture_docs.gd": "Capturas de docs", "logic/map_file.gd": "Ficheros de mapa",
}


def area(f):
    return AREAS.get(f, f.replace("scenes/minigame_views/", "Minijuego: ").replace(".gd", ""))


def label(ctx):
    m = re.search(r'const (\w+)', ctx)
    if m:
        return m.group(1)
    m = re.search(r'"(\w+)":\s*(Color|")', ctx)
    if m:
        return m.group(1)
    m = re.search(r'(\w+)\.(light_color|ambient_light_color|albedo_color|bg_color|border_color|emission|color)\s*=', ctx)
    if m:
        return m.group(1) + "." + m.group(2)
    m = re.search(r'var (\w+)', ctx)
    return m.group(1) if m else ""


def family(h):
    L, C, H = lch(h)
    if L < 8: return "Negros"
    if C < 7 and L > 92: return "Blancos"
    if C < 9 and not (250 <= H <= 330 and L < 45): return "Grises y humo"
    if L > 80 and C < 32 and (40 <= H <= 110): return "Cremas, huesos y pergamino"
    if 280 <= H <= 340 and L < 40: return "Morados de noche"
    if 225 <= H < 285 and L < 40 and C < 14: return "Morados de noche"
    if 225 <= H < 285: return "Azules"
    if 285 <= H <= 340 and C < 40: return "Lilas y lavandas"
    if 285 <= H <= 340: return "Violetas vivos"
    if 20 <= H <= 85 and L < 55: return "Marrones y madera"
    if 60 <= H <= 100 and C >= 25 and 55 <= L < 85: return "Latón y oro"
    if 80 <= H <= 110: return "Amarillos y oro vivo"
    if 40 <= H < 80: return "Naranjas"
    if (H >= 335 or H < 40) and L >= 66 and C < 60 or (330 <= H or H < 5) and L >= 62: return "Rosas"
    if H >= 335 or H < 40: return "Rojos, carmesí y vino"
    if 110 <= H < 165: return "Verdes"
    if 165 <= H < 225: return "Cian y turquesa"
    return "Otros"


FAMORD = ["Morados de noche", "Lilas y lavandas", "Violetas vivos", "Azules", "Cian y turquesa", "Verdes", "Amarillos y oro vivo", "Latón y oro", "Naranjas",
          "Marrones y madera", "Cremas, huesos y pergamino", "Rojos, carmesí y vino", "Rosas", "Grises y humo", "Blancos", "Negros", "Otros"]


def clusters(hexes, th=5.0):
    """Los casi iguales juntos (ΔE00 < th), de oscuro a claro."""
    cl = []
    for h in sorted(set(hexes), key=lambda h: lch(h)[0]):
        for c in cl:
            if dE(h, c[0]) < th:
                c.append(h)
                break
        else:
            cl.append([h])
    return cl


ALLOWED = {
    "ui": ["noche", "ciruela", "berenjena", "violeta", "lavanda", "lila", "oro", "laton", "nogal"],
    "mundo": ["noche", "ciruela", "berenjena", "violeta", "lavanda", "lila", "nogal", "laton", "vino", "oro"],
    "juego": [p[0] for p in PAL], "modelo": [p[0] for p in PAL], "ilustracion": None, "convencion": None, "historico": None,
}


def nearest(h, cls, ctx=""):
    if h == "#ff922b" and re.search(r'ICON_PANEL|Heist.panel|sign|held|ORANGE', ctx):
        return "oro"
    if h in SEM and cls != "mundo":
        return SEM[h]
    if h in UIFIX:
        return UIFIX[h]
    if h in SEM:
        return SEM[h]
    allowed = ALLOWED[cls]
    if allowed is None:
        return None
    best = None
    for p in PAL:
        if p[0] not in allowed:
            continue
        for idx, hx in [(p[0], p[2])] + [(p[0] + ":%d" % (i + 1), t[1]) for i, t in enumerate(p[5])]:
            d = dE(h, hx)
            if best is None or d < best[0]:
                best = (d, idx)
    return best[1]


# --- Museos -------------------------------------------------------------------------

def museums_now():
    """Las paletas de suelo y pared de cada museo, de logic/story.gd."""
    src = open(os.path.join(ROOT, "logic", "story.gd"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r'"theme": "(\w+)", "colour": "(#\w+)",\s*"palette": \{(.*?)\}\}', src, re.S):
        out.append((m.group(1), m.group(2), dict(re.findall(r'"(\w+)": Color\("(#\w+)"\)', m.group(3)))))
    return out


def museum_rule(tonehex, trim):
    return {"stone": lerp(P["ciruela"], tonehex, 0.22), "stone2": lerp(P["berenjena"], tonehex, 0.22), "joint": lerp(P["noche"], tonehex, 0.12),
            "paper": lerp(P["berenjena"], tonehex, 0.5), "paper2": lerp(P["berenjena"], tonehex, 0.62), "wainscot": lerp(P["nogal"], tonehex, 0.15),
            "cap": lerp(P["violeta"], tonehex, 0.3), "trim": P[trim], "skirt": P["noche"]}


# --- La referencia: el fondo de los menús ---------------------------------------------------

def backdrop():
    """Una copia pequeña del fondo de los menús para la página, y sus colores."""
    try:
        from PIL import Image
    except ImportError:
        return None
    if not os.path.exists(BACKDROP):
        return None
    im = Image.open(BACKDROP).convert("RGB")
    os.makedirs(os.path.dirname(BACKDROP_OUT), exist_ok=True)
    small = im.copy()
    small.thumbnail((960, 960))
    small.save(BACKDROP_OUT, "WEBP", quality=72, method=6)
    tiny = im.resize((96, 54))
    px = list(tiny.getdata())
    mean = lambda ps: rgb2hex([sum(p[i] for p in ps) / len(ps) / 255 for i in range(3)])
    w, hh = tiny.size
    bands = [mean([tiny.getpixel((x, y)) for x in range(w) for y in range(a, b)]) for a, b in [(0, hh // 3), (hh // 3, 2 * hh // 3), (2 * hh // 3, hh)]]
    q = tiny.quantize(colors=10, method=Image.MEDIANCUT)
    pal = q.getpalette()[:30]
    counts = sorted(q.getcolors(), reverse=True)
    dominant = [rgb2hex([pal[i * 3 + k] / 255 for k in range(3)]) for _, i in counts]
    return {"image": os.path.relpath(BACKDROP_OUT, DOCS), "mean": mean(px), "bands": bands, "dominant": dominant}


# --- Todo junto -----------------------------------------------------------------------

def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""


def load_json(name, default):
    path = os.path.join(DATA, name)
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else default


def cvd_table(S, merged):
    out = []
    for k in CVD:
        ks = [n for n in S if n not in merged]
        pairs = [(dE(S[a], S[b], k), a, b) for a, b in itertools.combinations(ks, 2) if S[a] != S[b]]
        w = min(pairs)
        out.append({"kind": k, "name": CVD_NAMES[k], "cells": [[n, simhex(v, k)] for n, v in S.items()], "worst": [w[1], w[2], round(w[0], 1)]})
    return out


def build():
    code_found = extract()
    glbs = glb_materials()
    rows = []
    for o in code_found:
        if not o["hex"]:
            continue
        rows.append(dict(hex=o["hex"], file=o["file"], line=o["line"], cls=klass(o["file"], o["ctx"]), area=area(o["file"]), what=label(o["ctx"]), ctx=o["ctx"]))
    # Los valores por defecto del shader del suelo.
    shader = os.path.join(ROOT, "scenes", "floor.gdshader")
    if os.path.exists(shader):
        for n, line in enumerate(open(shader, encoding="utf-8"), 1):
            m = re.search(r'uniform vec3 (\w+).*?=\s*vec3\(\s*(' + NUM + r')\s*,\s*(' + NUM + r')\s*,\s*(' + NUM + r')\s*\)', line)
            if m:
                rows.append(dict(hex=_h(*m.groups()[1:]), file="scenes/floor.gdshader", line=n, cls="mundo", area="Suelo (shader)", what=m.group(1), ctx=line.strip()))
    glbrows = []
    for f, ms in glbs.items():
        for n, h, _ in ms:
            glbrows.append(dict(hex=h, file=f, line=0, cls="juego" if ("botin" in f and n.startswith("color")) else "modelo", area="Modelos .glb", what=n, ctx=""))
    for r in rows + glbrows:
        r["family"] = family(r["hex"])
        t = nearest(r["hex"], r["cls"], r["ctx"])
        r["to"] = t
        if t:
            r["to_name"], r["to_hex"] = tone(t)
            r["de"] = round(dE(r["hex"], r["to_hex"]), 1)
    code = [r for r in rows if r["cls"] != "historico"]
    hist = [r for r in rows if r["cls"] == "historico"]
    allhex = set(r["hex"] for r in code)

    # Por familia, con sus grupos.
    fam = collections.defaultdict(list)
    for r in code:
        fam[r["family"]].append(r)
    families = []
    for f in FAMORD:
        if f not in fam:
            continue
        uses = collections.defaultdict(list)
        for r in fam[f]:
            uses[r["hex"]].append(r)
        cl = clusters(uses)
        groups = []
        for c in sorted(cl, key=lambda c: -sum(len(uses[h]) for h in c)):
            groups.append({"hexes": [[h, len(uses[h])] for h in c], "uses": sum(len(uses[h]) for h in c),
                           "classes": sorted(set(r["cls"] for h in c for r in uses[h])),
                           "areas": sorted(set(r["area"] for h in c for r in uses[h])),
                           "whats": sorted(set(r["what"] for h in c for r in uses[h] if r["what"]))[:8]})
        families.append({"name": f, "n_hex": len(uses), "n_grp": len(cl), "groups": groups,
                         "rows": [[r["hex"], r["cls"], r["area"], r["file"], r["line"], r["what"], r.get("to_name", ""), r.get("to_hex", "")]
                                  for r in sorted(fam[f], key=lambda r: (lch(r["hex"])[0], r["file"], r["line"]))]})
    bycls = {}
    for c in ["ui", "mundo", "juego", "ilustracion", "convencion"]:
        hs = set(r["hex"] for r in code if r["cls"] == c)
        bycls[c] = [len(hs), len(clusters(hs))]
    core = set(r["hex"] for r in code if r["cls"] in ("ui", "mundo", "juego"))
    stats = {"hex": len(allhex), "groups": len(clusters(allhex)), "core_hex": len(core), "core_groups": len(clusters(core)),
             "glb_hex": len(set(r["hex"] for r in glbrows)), "glb_models": len(glbs), "glb_mats": len(glbrows),
             "glb_textured": sum(1 for v in glbs.values() for _, _, t in v if t), "hist_hex": len(set(r["hex"] for r in hist)), "bycls": bycls}

    # Los modelos.
    glb_models = [{"file": f.replace("assets/models/", ""), "mats": [[n, h] for n, h, _ in ms]} for f, ms in sorted(glbs.items())]
    glb_fam = collections.Counter(family(r["hex"]) for r in glbrows).most_common(8)

    # La paleta propuesta.
    palette = []
    for pid, name, h, grp, uso, tones in PAL:
        note = ("sobre Ciruela: %.1f:1" % contrast(h, P["ciruela"])) if rel_lum(h) > 0.12 else ("con Lila encima: %.1f:1" % contrast(P["lila"], h))
        palette.append({"id": pid, "name": name, "hex": h, "group": grp, "use": uso, "tones": [list(t) for t in tones], "contrast": note.replace(".", ",")})

    # Daltonismo: hoy (leído del código si está) y la propuesta.
    colours = {}
    for e in load_json("paleta.json", []):
        if e.get("file") == "scenes/main.gd" and e.get("name") == "COLOURS":
            colours = {c["key"]: c["hex"][:7] for c in e["colours"]}
    cur = dict(CUR)
    for k, v in CUR_FROM.items():
        if v in colours:
            cur[k] = colours[v]
    cvd = {"now": cvd_table(cur, []), "new": cvd_table(NEW, ["Alerta", "Salida", "Panel/sospecha"])}

    # La tabla de paso, y si cada color de hoy sigue en el código.
    paso = []
    for g, k, f, h, t, n in PASO:
        tn, th = tone(t)
        present = any(r["hex"] == h and r["file"] == f for r in code) or h in allhex
        paso.append({"cls": g, "key": k, "file": f, "hex": h, "to": t, "to_name": tn, "to_hex": th, "note": n, "present": present})
    famstats = {f["name"]: f for f in families}
    famto = []
    for f, txt, *ids in FAMTO:
        if f not in famstats:
            continue
        s = famstats[f]
        famto.append({"family": f, "n_hex": s["n_hex"], "n_grp": s["n_grp"], "sample": [g["hexes"][0][0] for g in s["groups"][:10]],
                      "to": [tone(i)[1] for i in ids], "text": txt})

    # Museos y temas.
    museums = []
    for th, col, pal in museums_now():
        name, T, trim = TONE.get(th, ("?", "#808080", "laton"))
        museums.append({"theme": th, "name": THEME_NAMES.get(th, th), "tone": name, "tone_hex": T, "colour_old": col,
                        "colour_new": lerp(T, P["lila"], 0.35), "old": pal, "new": museum_rule(T, trim)})
    themes = []
    for k, v in load_json("catalogo.json", {}).get("themes", {}).items():
        themes.append({"theme": k, "name": THEME_NAMES.get(k, k), "old": v.get("colours", []), "new": [lerp(c, P["violeta"], 0.28) for c in v.get("colours", [])],
                       "cloth_old": v.get("cloth", ""), "cloth_new": CLOTH_NEW.get(k, "")})
    themes.sort(key=lambda t: list(THEME_NAMES).index(t["theme"]) if t["theme"] in THEME_NAMES else 9)

    # Las piezas de la historia con poco contraste como texto sobre el cristal.
    loot = [n["loot"]["colour"] for n in load_json("historia.json", {}).get("nights", [])]
    glass = "#150f24"
    loot_low = sorted(set(c for c in loot if contrast(c, glass) < 4.5))
    arcade = sorted(set(c for g in load_json("catalogo.json", {}).get("arcade_games", {}).values() for c in [g.get("mueble"), g.get("marquesina")] if c))

    return {"generated": {"date": datetime.now().strftime("%d-%m-%Y %H:%M"), "commit": git("rev-parse", "--short", "HEAD"), "branch": git("rev-parse", "--abbrev-ref", "HEAD")},
            "stats": stats, "families": families, "glb": {"models": glb_models, "families": glb_fam}, "palette": palette, "cvd": cvd,
            "paso": paso, "famto": famto, "museums": museums, "themes": themes, "reference": backdrop(), "loot_low": loot_low,
            "loot_count": len(set(loot)), "arcade": arcade,
            "classes": {"ui": "Interfaz", "mundo": "Mundo", "juego": "Juego", "ilustracion": "Ilustración", "convencion": "Convención", "historico": "Histórico", "modelo": "Modelo"}}


def write(data):
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, "paleta_propuesta.js"), "w", encoding="utf-8") as f:
        f.write("window.PALETA_PROPUESTA = ")
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.write(";\n")


def main():
    data = build()
    write(data)
    s = data["stats"]
    print(f"Paleta: {s['hex']} colores en el código ({s['groups']} grupos), {s['glb_hex']} en {s['glb_models']} modelos")


if __name__ == "__main__":
    main()
