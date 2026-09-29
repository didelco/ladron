#!/usr/bin/env python3
"""La documentación del juego (docs/), sacada del propio juego.

    python3 tools/docs.py build           # capturas, assets, datos y textos (abre una ventana del juego)
    python3 tools/docs.py build --fast    # solo datos y textos, sin capturas ni renders
    python3 tools/docs.py build objects   # solo unas partes: shots, city, assets, models, objects, sounds, data
    python3 tools/docs.py build palette   # solo la auditoría de colores (tools/palette.py, sin Godot)
    python3 tools/docs.py serve           # http://localhost:8765, con los textos editables
    python3 tools/docs.py texts           # solo textos, ESTILO.md y procedencia (rápido, sin Godot)
    python3 tools/docs.py version <asunto> "<título>" [--from <ruta o captura>] [--commit <hash>]
                                          # guarda un hito en docs/versiones/ (ver `version --help`)
    python3 tools/docs.py version --list  # los hitos guardados

`build` corre tools/capture_docs.gd en Godot (pantallas, assets, modelos, sonidos,
paleta, historia) y luego escribe docs/data/*.js a partir de esos JSON y de
locale/texts.csv, para que docs/index.html se pueda abrir tal cual, sin servidor.

`serve` sirve docs/ y deja cambiar textos desde el visor: cada cambio se escribe
en locale/texts.csv (solo esa fila, respetando el resto del fichero) y Godot
reimporta la traducción.

Las etiquetas de licencia de las fichas de objetos y sonidos y la tabla plegada «Lo que ya usamos» (al pie de
«Assets a incorporar») salen de assets/PROCEDENCIA.json, la fuente única de dónde viene cada asset y con qué
licencia: se resuelve con tools/procedencia.py en docs/data/procedencia.js, tanto en `build` como en `texts` y `serve`.

Assets a incorporar: docs/data/propuestas.json es la lista de assets concretos propuestos (un modelo, un sonido, un
icono, un pack pequeño: {id, nombre, pack, pack_url, url, tipo, licencia, atribucion, preview_url, para, estado,
nota}; estado: propuesto / aceptado / incorporado / descartado). Se valida con `python3 tools/procedencia.py` y se
vuelca a docs/data/propuestas.js. Con `serve`: POST /api/propuesta {accion: "añadir"|"estado", …} (añade una
propuesta, o cambia el estado de una; escritura atómica y validada); GET /api/propuestas la lee.

Referencias: docs/data/referencias.json (a mano, o desde la página «Referencias» con `serve`) guarda enlaces de
inspiración y recursos; se validan con `python3 tools/procedencia.py` y se vuelcan a docs/data/referencias.js.
Con `serve`: POST /api/referencia {accion: "añadir"|"estado"|"borrar", …}; GET /api/referencias las lee.

El visor (docs/index.html) lleva la navegación aparte, en docs/navegacion.js y docs/navegacion.css: los
grupos de la barra lateral (GRUPOS: una página nueva se da de alta ahí), el buscador global (/ o Ctrl+K, con
un índice que se construye al cargar desde los datos de docs/data/*.js), las migas, el índice «en esta
página», el pie con anterior y siguiente, y el menú del móvil. No hay que regenerar nada para que salgan.

`version` guarda a propósito una versión de una imagen importante (un hito: un
cambio muy visible, o una muy antigua cuando algo ha ido cambiando poco a poco),
en docs/versiones/<asunto>/<fecha>-<nombre>.webp, y la apunta en
docs/versiones/versiones.json. Nada la guarda solo: cada hito se decide.
"""

import argparse
import csv
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import threading
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402  (tools/palette.py)
import procedencia  # noqa: E402  (tools/procedencia.py: assets/PROCEDENCIA.json)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
DATA = os.path.join(DOCS, "data")
TEXTS = os.path.join(ROOT, "locale", "texts.csv")
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
VERSIONS = os.path.join(DOCS, "versiones")
MANIFEST = os.path.join(VERSIONS, "versiones.json")
# Las partes de `build` que hace Godot (tools/capture_docs.gd); el resto, Python.
GODOT_PARTS = ["shots", "city", "assets", "models", "objects", "sounds", "data"]
PY_PARTS = ["palette", "versions"]
PROPUESTAS_LOCK = threading.Lock()
REFERENCIAS_LOCK = threading.Lock()
PORT = int(os.environ.get("PORT", "8765"))

# Grupos del visor de textos, por el prefijo de la clave.
GROUPS = [
    ("Historia", ["STORY_", "PROLOGUE_", "ENDING_", "NIGHT_", "MUSEUM_", "LESSON_"]),
    ("Menús", ["MENU_", "JOIN_", "SEAT_", "CHALLENGE_", "BRIEF_", "PLAN_", "NEWS_", "TIP_"]),
    ("Juego", ["HUD_", "LOG_", "END_", "GAME_", "GUARD_", "MIND_", "ZONE_", "PROP_", "PIECE_", "LEGEND_", "BRAIN_"]),
    ("Megafonía", ["MEGA_"]),
    ("Descripciones", ["DESC_"]),
    ("Generador", ["GEN_", "GALLERY_", "THEME_"]),
    ("Ajustes y controles", ["SETTINGS_", "CONTROLS_", "ASSETS_"]),
    ("Editor de mapas", ["EDITOR_"]),
]


# --- locale/texts.csv -----------------------------------------------------------------

def read_records():
    """Las filas del CSV con su texto crudo, para poder reescribir solo una."""
    src = open(TEXTS, encoding="utf-8", newline="").read()
    records, i, n = [], 0, len(src)
    while i < n:
        start, in_q = i, False
        while i < n:
            c = src[i]
            if c == '"':
                in_q = not in_q
            elif c == "\n" and not in_q:
                break
            i += 1
        raw = src[start:i]
        i += 1  # el salto de línea
        if raw.strip() == "":
            records.append({"raw": raw, "cells": None})
            continue
        cells = next(csv.reader(io.StringIO(raw)))
        records.append({"raw": raw, "cells": cells})
    return records, src.endswith("\n")


def write_records(records, trailing):
    out = "\n".join(r["raw"] for r in records) + ("\n" if trailing else "")
    with open(TEXTS, "w", encoding="utf-8", newline="") as f:
        f.write(out)


def encode_cell(value):
    """Entre comillas solo si hace falta, para que deshacer un cambio deje el fichero igual."""
    if any(c in value for c in ',"\n') or value != value.strip():
        return '"' + value.replace('"', '""') + '"'
    return value


def set_text(key, value):
    records, trailing = read_records()
    for r in records:
        if r["cells"] and r["cells"][0] == key:
            r["raw"] = key + "," + encode_cell(value)
            break
    else:
        # Las descripciones de los objetos se escriben aquí: la primera vez, fila nueva al final.
        if not key.startswith("DESC_"):
            raise KeyError(key)
        while records and records[-1]["cells"] is None and records[-1]["raw"] == "":
            records.pop()
        records.append({"raw": key + "," + encode_cell(value), "cells": [key, value]})
        trailing = True
    write_records(records, trailing)


def texts():
    records, _ = read_records()
    header = records[0]["cells"]
    out = []
    for line, r in enumerate(records[1:], start=2):
        cells = r["cells"]
        if not cells:
            continue
        out.append({"key": cells[0], "es": cells[1] if len(cells) > 1 else "",
                    "broken": len(cells) != len(header), "extra": cells[len(header):]})
    return out


def group_of(key):
    for name, prefixes in GROUPS:
        if any(key.startswith(p) for p in prefixes):
            return name
    return "Otros"


def usages(keys):
    """Dónde sale cada clave en el código: archivo:línea. Las que se arman con
    %d (NIGHT_%02d_NAME…) se marcan por su patrón."""
    code = {}
    for folder in ["scenes", "logic"]:
        for f in sorted(os.listdir(os.path.join(ROOT, folder))):
            if f.endswith(".gd"):
                path = f"{folder}/{f}"
                code[path] = open(os.path.join(ROOT, path), encoding="utf-8").read().split("\n")
    patterns = set()
    for lines in code.values():
        for line in lines:
            for m in re.finditer(r'"([A-Z][A-Z0-9_]*%[0-9]*d[A-Z0-9_]*)"', line):
                patterns.add(m.group(1))
    pattern_res = [(p, re.compile("^" + re.sub(r"%[0-9]*d", r"[0-9]+", p) + "$")) for p in patterns]
    # Y las que se arman pegando trozos: "GALLERY_" + id + "_OF", "EDITOR_TOOL_" + tool…
    prefixes = set()
    for lines in code.values():
        for line in lines:
            for m in re.finditer(r'"([A-Z][A-Z0-9]*_(?:[A-Z0-9]+_)*)"\s*[+%]', line):
                prefixes.add(m.group(1))
    out = {}
    for key in keys:
        found = []
        needle = '"' + key + '"'
        for path, lines in code.items():
            for n, line in enumerate(lines, start=1):
                if needle in line:
                    found.append(f"{path}:{n}")
        via = [p for p, rx in pattern_res if rx.match(key)]
        if not found and not via:
            via = [p + "…" for p in sorted(prefixes, key=len, reverse=True) if key.startswith(p)][:1]
        out[key] = {"at": found[:8], "via": via}
    return out


# --- build ----------------------------------------------------------------------------

def load_json(name, default):
    path = os.path.join(DATA, name)
    if not os.path.exists(path):
        return default
    return json.load(open(path, encoding="utf-8"))


def write_js(name, var, data):
    with open(os.path.join(DATA, name), "w", encoding="utf-8") as f:
        f.write(f"window.{var} = ")
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write(";\n")


def build_texts():
    t = texts()
    use = usages([x["key"] for x in t])
    for x in t:
        x["group"] = group_of(x["key"])
        x.update(use[x["key"]])
        if x["group"] == "Megafonía":
            # MEGA_<TIPO>_<NN>: el tipo es el POOL de logic/megaphone.gd; el audio, el de megafonia-tool.
            m = re.match(r"MEGA_(.+)_[0-9]+$", x["key"])
            x["pool"] = m.group(1).lower() if m else ""
            x["audio"] = os.path.exists(os.path.join(ROOT, "audio", "megafonia", x["key"].lower() + ".ogg"))
    write_js("textos.js", "TEXTOS", t)
    return t


def functions():
    """Dónde está cada función de scenes/ y logic/: {nombre: "archivo:línea"} (el árbol de pantallas lo usa)."""
    out = {}
    for folder in ["scenes", "logic"]:
        for f in sorted(os.listdir(os.path.join(ROOT, folder))):
            if not f.endswith(".gd"):
                continue
            for n, line in enumerate(open(os.path.join(ROOT, folder, f), encoding="utf-8"), start=1):
                m = re.match(r"(?:static )?func (\w+)", line)
                if m and m.group(1) not in out:
                    out[m.group(1)] = f"{folder}/{f}:{n}"
    return out


def write_propuestas():
    """procedencia.js, propuestas.js (docs/data/propuestas.json) y referencias.js (enlazadas con las propuestas)."""
    write_js("procedencia.js", "PROCEDENCIA", procedencia.web_data())
    write_js("propuestas.js", "PROPUESTAS", procedencia.prop_web_data())
    write_js("referencias.js", "REFERENCIAS", procedencia.ref_web_data())


def build_static():
    """Lo escrito a mano (docs/ESTILO.md), las constantes del código y la fuente, al lado del HTML."""
    build_code()
    path = os.path.join(DOCS, "ESTILO.md")
    write_js("estilo.js", "ESTILO", open(path, encoding="utf-8").read() if os.path.exists(path) else "")
    write_js("funciones.js", "FUNCIONES", functions())
    write_propuestas()
    os.makedirs(os.path.join(DOCS, "fuentes"), exist_ok=True)
    for f in ["PressStart2P-Regular.ttf", "OFL.txt"]:
        shutil.copy(os.path.join(ROOT, "assets", "fonts", f), os.path.join(DOCS, "fuentes"))


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""


def godot_env():
    """El entorno para las capturas: sin mandos fantasma. Algunos Mac tienen un
    dispositivo HID de Apple (05ac:0004) que Godot toma por un mando con el stick
    pegado a un lado, y pasa de página las pantallas mientras se capturan."""
    env = dict(os.environ)
    for k in ["SDL_JOYSTICK_IGNORE_DEVICES", "SDL_GAMECONTROLLER_IGNORE_DEVICES"]:
        env.setdefault(k, "0x05ac/0x0004")
    return env


def build(fast, only=()):
    os.makedirs(DATA, exist_ok=True)
    unknown = [p for p in only if p not in GODOT_PARTS + PY_PARTS]
    if unknown:
        sys.exit(f"No hay partes {', '.join(unknown)}: {', '.join(GODOT_PARTS + PY_PARTS)}")
    parts = ["data"] if fast else [p for p in only if p in GODOT_PARTS]
    # Solo partes de Python: sin abrir Godot.
    if fast or not only or parts:
        print("Godot: capturando" + (" (solo datos)" if fast else "") + "…")
        r = subprocess.run([GODOT, "--path", ROOT, "--script", "tools/capture_docs.gd", "--", *parts], cwd=ROOT, env=godot_env())
        if r.returncode != 0:
            sys.exit("Godot ha fallado")
    t = build_texts()
    build_static()
    if not only or "palette" in only or fast:
        palette.main()
    build_versions()
    write_js("juego.js", "JUEGO", {
        "paleta": load_json("paleta.json", []),
        "historia": load_json("historia.json", {}),
        "catalogo": load_json("catalogo.json", {}),
        "capturas": load_json("capturas.json", []),
        "ciudad": load_json("ciudad.json", {}),
        "assets": load_json("assets.json", {}),
        "modelos": load_json("modelos.json", []),
        "objetos": load_json("objetos.json", []),
        "sonidos": load_json("sonidos.json", []),
        "generado": {"fecha": datetime.now().strftime("%d-%m-%Y %H:%M"), "commit": git("rev-parse", "--short", "HEAD"),
                     "rama": git("rev-parse", "--abbrev-ref", "HEAD")},
    })
    broken = [x["key"] for x in t if x["broken"]]
    print(f"Hecho: {len(t)} textos" + (f"; filas rotas en el CSV: {', '.join(broken)}" if broken else ""))


# --- El código: constantes y comentarios que enseña la documentación --------------------

# Los ficheros cuyas constantes salen en las páginas de minijuegos, escondites, colección y
# la previa; cada página pone al lado lo que significan, en español (docs/mecanicas.js).
CODE_FILES = ["logic/minigame.gd", "logic/minigames/*.gd", "logic/hideouts.gd", "logic/plinths.gd", "logic/collection.gd",
              "logic/themes.gd", "logic/arcades.gd", "logic/briefing.gd", "logic/story.gd"]


def gd_consts(path):
    """El comentario ## de cabecera de un script y cada const con el ## de encima
    (una fila de consts bajo un mismo comentario lo comparte): {doc, consts}."""
    lines = open(os.path.join(ROOT, path), encoding="utf-8").read().split("\n")
    doc, i = [], 0
    while i < len(lines) and (lines[i].startswith(("class_name", "extends", "@")) or lines[i].strip() == ""):
        i += 1
    while i < len(lines) and lines[i].startswith("##"):
        doc.append(lines[i][2:].strip())
        i += 1
    consts, last = {}, ""
    for n, line in enumerate(lines):
        m = re.match(r"const (\w+)\s*(?::\s*[\w\[\]]+\s*)?:?=\s*(.*)", line)
        if not m:
            if line.strip() and not line.startswith(("##", "\t", " ", "}", "]")):
                last = ""
            continue
        note, j = [], n - 1
        while j >= 0 and lines[j].startswith("##"):
            note.insert(0, lines[j][2:].strip())
            j -= 1
        last = " ".join(note) if note else last
        value, depth, k = m.group(2), 0, n
        depth = value.count("[") + value.count("{") + value.count("(") - value.count("]") - value.count("}") - value.count(")")
        while depth > 0 and k + 1 < len(lines):
            k += 1
            value += " " + lines[k].strip()
            depth += lines[k].count("[") + lines[k].count("{") + lines[k].count("(") - lines[k].count("]") - lines[k].count("}") - lines[k].count(")")
        value = re.sub(r"\s*#[^\"]*$", "", value).strip()
        consts[m.group(1)] = {"value": value if len(value) <= 400 else value[:400] + "…", "note": last, "line": n + 1}
    return {"doc": " ".join(doc), "consts": consts}


def build_code():
    out = {}
    for pattern in CODE_FILES:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            rel = os.path.relpath(path, ROOT)
            out[rel] = gd_consts(rel)
    write_js("codigo.js", "CODIGO", out)


# --- Versiones: los hitos de las imágenes importantes -------------------------------------

def manifest():
    if not os.path.exists(MANIFEST):
        return {"asuntos": [], "versiones": []}
    return json.load(open(MANIFEST, encoding="utf-8"))


def save_manifest(m):
    os.makedirs(VERSIONS, exist_ok=True)
    order = [a["id"] for a in m["asuntos"]]
    m["versiones"].sort(key=lambda v: (order.index(v["asunto"]) if v["asunto"] in order else 99, v["fecha"]))
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)
        f.write("\n")


def build_versions():
    """El manifiesto, al lado del HTML (docs/data/versiones.js), con lo que pesan."""
    m = manifest()
    total = 0
    for v in m["versiones"]:
        path = os.path.join(DOCS, v["file"])
        v["bytes"] = os.path.getsize(path) if os.path.exists(path) else 0
        total += v["bytes"]
    m["bytes"] = total
    write_js("versiones.js", "VERSIONES", m)


def slug(text):
    t = text.lower()
    for a, b in zip("áéíóúüñ", "aeiouun"):
        t = t.replace(a, b)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")[:40] or "version"


def _source_bytes(src, commit):
    """Los bytes de la imagen: de un commit (git show), del disco, o una captura por su id."""
    cands = [src, os.path.join("docs", "capturas", src + ".webp"), os.path.join("docs", "assets", "modelos", src.replace("/", "__") + ".webp")]
    if commit:
        for c in cands:
            r = subprocess.run(["git", "show", f"{commit}:{c}"], cwd=ROOT, capture_output=True)
            if r.returncode == 0:
                return r.stdout, c
        # Un fichero de fuera del repo (una captura hecha a mano de ese commit):
        # el commit solo dice de dónde es.
        if not os.path.exists(src) or os.path.abspath(src).startswith(ROOT + os.sep):
            sys.exit(f"{src} no está en el commit {commit}")
    for c in cands:
        path = c if os.path.isabs(c) else os.path.join(ROOT, c)
        if os.path.exists(path):
            return open(path, "rb").read(), os.path.relpath(path, ROOT) if path.startswith(ROOT) else path
    sys.exit(f"No encuentro {src} (ni como ruta, ni como captura de docs/capturas, ni como modelo)")


def _image(data):
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Hace falta Pillow para convertir a webp: python3 -m pip install --user pillow")
    return Image.open(io.BytesIO(data))


def _compose(images):
    """Varias imágenes en una rejilla (hasta tres por fila), cada una en su casilla."""
    from PIL import Image
    cols = min(3, len(images))
    rows = (len(images) + cols - 1) // cols
    cell = max(max(im.size) for im in images)
    out = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for i, im in enumerate(images):
        im = im.convert("RGBA")
        out.paste(im, ((i % cols) * cell + (cell - im.size[0]) // 2, (i // cols) * cell + (cell - im.size[1]) // 2), im)
    return out


def commit_info(commit):
    out = git("show", "-s", "--format=%h%x00%cI%x00%s", commit)
    if not out:
        sys.exit(f"No existe el commit {commit}")
    h, when, subject = out.split("\x00")
    return h, datetime.fromisoformat(when.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%dT%H:%M"), subject


def version(argv):
    ap = argparse.ArgumentParser(prog="docs.py version", description=(
        "Guarda un hito de una imagen importante en docs/versiones/<asunto>/ y lo apunta en "
        "docs/versiones/versiones.json. Solo hitos: un cambio muy visible, o una versión antigua "
        "cuando algo ha cambiado poco a poco y ya se parece poco al principio."))
    ap.add_argument("asunto", nargs="?", help="de qué es: fondo-menus, menus, icono, recreativa, ciudad, museo… (uno nuevo se crea)")
    ap.add_argument("titulo", nargs="?", help="título corto del hito")
    ap.add_argument("--from", dest="src", action="append", default=[],
                    help="la imagen: una ruta del repo (assets/ui/fondo_menu.png), una captura (menu_titulo), "
                         "un modelo (temas/moderna/recreativa) o un fichero cualquiera; varias --from, en rejilla. "
                         "Sin --from, la de siempre del asunto")
    ap.add_argument("--commit", help="sacarla de este commit (git show <commit>:<ruta>) en vez del disco")
    ap.add_argument("--why", default="", help="por qué se guarda")
    ap.add_argument("--what", default="", help="qué cambió respecto al hito anterior")
    ap.add_argument("--date", help="fecha y hora (AAAA-MM-DDTHH:MM); por defecto, la del commit o ahora")
    ap.add_argument("--asunto-title", help="el nombre del asunto, si es nuevo")
    ap.add_argument("--max", type=int, default=1280, help="lado mayor en píxeles (1280)")
    ap.add_argument("--quality", type=int, default=80, help="calidad webp (80)")
    ap.add_argument("--list", action="store_true", help="enseña los hitos guardados")
    a = ap.parse_args(argv)
    m = manifest()
    if a.list or not a.asunto:
        for s in m["asuntos"]:
            print(f"{s['id']}: {s['title']}")
            for v in [v for v in m["versiones"] if v["asunto"] == s["id"]]:
                print(f"   {v['fecha']}  {v['commit']:8}  {v['titulo']}  ({v['file']})")
        return
    if not a.titulo:
        ap.error("falta el título")
    asunto = next((s for s in m["asuntos"] if s["id"] == a.asunto), None)
    if asunto is None:
        asunto = {"id": slug(a.asunto), "title": a.asunto_title or a.asunto, "text": "", "source": a.src[0] if len(a.src) == 1 else ""}
        m["asuntos"].append(asunto)
        print(f"Asunto nuevo: {asunto['id']}")
    srcs = a.src or ([asunto["source"]] if asunto.get("source") else [])
    if not srcs:
        ap.error("este asunto no tiene imagen de siempre: di cuál con --from")
    pulled = [_source_bytes(s, a.commit) for s in srcs]
    images = [_image(b) for b, _ in pulled]
    im = images[0] if len(images) == 1 else _compose(images)
    im.thumbnail((a.max, a.max))
    if a.commit:
        commit, when, subject = commit_info(a.commit)
    else:
        commit, when, subject = git("rev-parse", "--short", "HEAD"), datetime.now().strftime("%Y-%m-%dT%H:%M"), ""
    when = a.date or when
    rel = os.path.join("versiones", asunto["id"], f"{when[:10]}-{slug(a.titulo)}.webp")
    os.makedirs(os.path.join(DOCS, os.path.dirname(rel)), exist_ok=True)
    keep_alpha = im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info)
    im = im.convert("RGBA" if keep_alpha else "RGB")
    im.save(os.path.join(DOCS, rel), "WEBP", quality=a.quality, method=6)
    m["versiones"] = [v for v in m["versiones"] if v["file"] != rel]
    m["versiones"].append({"asunto": asunto["id"], "fecha": when, "commit": commit, "titulo": a.titulo, "porque": a.why,
                           "cambio": a.what, "file": rel, "from": ", ".join(p for _, p in pulled), "commit_msg": subject,
                           "size": list(im.size)})
    save_manifest(m)
    build_versions()
    kb = os.path.getsize(os.path.join(DOCS, rel)) / 1024
    print(f"Guardado {rel} ({im.size[0]}×{im.size[1]}, {kb:.0f} KB) desde {', '.join(p for _, p in pulled)} @ {commit}")


# --- serve ----------------------------------------------------------------------------

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=DOCS, **kw)

    def log_message(self, fmt, *args):
        pass

    def _json(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/ping":
            return self._json(200, {"ok": True, "editable": True})
        if self.path == "/api/propuestas":
            return self._json(200, procedencia.prop_web_data())
        if self.path == "/api/referencias":
            return self._json(200, procedencia.ref_web_data())
        return super().do_GET()

    def _referencia(self, body):
        """Añade, cambia de estado o borra una referencia en docs/data/referencias.json (y solo ahí)."""
        accion = body.get("accion")
        if accion not in ("añadir", "estado", "borrar"):
            return self._json(400, {"error": "acción no válida"})
        with REFERENCIAS_LOCK:
            refs, err = procedencia.ref_load()
            if err:
                return self._json(500, {"error": f"referencias.json no es válido: {err}"})
            if accion == "añadir":
                url = str(body.get("url", "")).strip()
                titulo = str(body.get("titulo", "")).strip() or procedencia._host(url)
                base = re.sub(r"[^a-z0-9]+", "-", titulo.lower()).strip("-")[:40] or "referencia"
                ids = {r.get("id") for r in refs if isinstance(r, dict)}
                rid, n = base, 2
                while rid in ids:
                    rid, n = f"{base}-{n}", n + 1
                etq = body.get("etiquetas", [])
                if not isinstance(etq, list):
                    etq = []
                nueva = {"id": rid, "titulo": titulo, "url": url, "tipo": str(body.get("tipo", "otro")),
                         "etiquetas": [str(x).strip() for x in etq if str(x).strip()],
                         "licencia": str(body.get("licencia", "")).strip(), "nota": str(body.get("nota", "")).strip(),
                         "fecha": datetime.now().strftime("%Y-%m-%d"), "estado": "guardada"}
                errs = procedencia.ref_item_errors(nueva)
                if errs:
                    return self._json(400, {"error": "; ".join(errs)})
                if any(isinstance(r, dict) and r.get("url") == url for r in refs):
                    return self._json(409, {"error": "esa URL ya está guardada"})
                refs.append(nueva)
                print(f"referencia añadida: {rid}")
            else:
                rid = body.get("id")
                i = next((k for k, r in enumerate(refs) if isinstance(r, dict) and r.get("id") == rid), None)
                if not isinstance(rid, str) or i is None:
                    return self._json(404, {"error": f"no hay referencia {rid}"})
                if accion == "borrar":
                    refs.pop(i)
                else:
                    estado = body.get("estado")
                    if estado not in procedencia.REF_ESTADOS:
                        return self._json(400, {"error": f"estado no válido: {estado}"})
                    refs[i]["estado"] = estado
                print(f"referencia {accion}: {rid}")
            procedencia.ref_save(refs)
        return self._json(200, {"ok": True, "referencias": procedencia.ref_web_data()})

    def _propuesta(self, body):
        """Añade una propuesta o cambia su estado en docs/data/propuestas.json (y solo ahí)."""
        accion = body.get("accion")
        if accion not in ("añadir", "estado"):
            return self._json(400, {"error": "acción no válida"})
        with PROPUESTAS_LOCK:
            props, err = procedencia.prop_load()
            if err:
                return self._json(500, {"error": f"propuestas.json no es válido: {err}"})
            if accion == "añadir":
                txt = lambda k: str(body.get(k, "") or "").strip()
                url = txt("url")
                nombre = txt("nombre") or procedencia._host(url)
                base = re.sub(r"[^a-z0-9]+", "-", nombre.lower()).strip("-")[:40] or "propuesta"
                ids = {r.get("id") for r in props if isinstance(r, dict)}
                rid, n = base, 2
                while rid in ids:
                    rid, n = f"{base}-{n}", n + 1
                nueva = {"id": rid, "nombre": nombre, "pack": txt("pack") or nombre, "pack_url": txt("pack_url") or url,
                         "url": url, "tipo": txt("tipo") or "otro", "licencia": txt("licencia") or "por comprobar",
                         "atribucion": body.get("atribucion") is True, "preview_url": txt("preview_url"),
                         "para": txt("para"), "estado": "propuesto", "nota": txt("nota")}
                errs = procedencia.prop_item_errors(nueva)
                if errs:
                    return self._json(400, {"error": "; ".join(errs)})
                if any(isinstance(r, dict) and r.get("url") == url for r in props):
                    return self._json(409, {"error": "esa URL ya está propuesta"})
                props.append(nueva)
                print(f"propuesta añadida: {rid}")
            else:
                rid, estado = body.get("id"), body.get("estado")
                i = next((k for k, r in enumerate(props) if isinstance(r, dict) and r.get("id") == rid), None)
                if not isinstance(rid, str) or i is None:
                    return self._json(404, {"error": f"no hay propuesta {rid}"})
                if estado not in procedencia.PROP_ESTADOS:
                    return self._json(400, {"error": f"estado no válido: {estado}"})
                props[i]["estado"] = estado
                print(f"propuesta {rid}: {estado}")
            procedencia.prop_save(props)
            write_propuestas()
        return self._json(200, {"ok": True, "propuestas": procedencia.prop_web_data(),
                                "referencias": procedencia.ref_web_data()})

    def do_POST(self):
        if self.path not in ("/api/texto", "/api/propuesta", "/api/referencia"):
            return self._json(404, {"error": "no existe"})
        # Solo desde esta máquina: es un editor local, no un servicio.
        if self.client_address[0] not in ("127.0.0.1", "::1"):
            return self._json(403, {"error": "solo en local"})
        try:
            n = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            return self._json(400, {"error": "cuerpo no válido"})
        if not isinstance(body, dict):
            return self._json(400, {"error": "cuerpo no válido"})
        if self.path == "/api/propuesta":
            return self._propuesta(body)
        if self.path == "/api/referencia":
            return self._referencia(body)
        key, value = body.get("key", ""), body.get("es")
        if not isinstance(value, str) or not re.fullmatch(r"[A-Z][A-Z0-9_]*", key or ""):
            return self._json(400, {"error": "clave o texto no válidos"})
        try:
            set_text(key, value)
        except KeyError:
            return self._json(404, {"error": f"no hay texto {key}"})
        build_texts()
        # Que el juego lo vea sin abrir el editor de Godot.
        subprocess.Popen([GODOT, "--headless", "--path", ROOT, "--import"], cwd=ROOT,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"texto cambiado: {key}")
        return self._json(200, {"ok": True})


def serve():
    # La procedencia se edita a mano en assets/PROCEDENCIA.json: se relee al arrancar.
    write_propuestas()
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Documentación en http://localhost:{PORT}  (Ctrl+C para parar)")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "build":
        build("--fast" in sys.argv, [a for a in sys.argv[2:] if not a.startswith("--")])
    elif cmd == "serve":
        serve()
    elif cmd == "texts":
        os.makedirs(DATA, exist_ok=True)
        build_texts()
        build_static()
    elif cmd == "version":
        version(sys.argv[2:])
    else:
        sys.exit(__doc__)
