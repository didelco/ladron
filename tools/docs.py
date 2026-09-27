#!/usr/bin/env python3
"""La documentación del juego (docs/), sacada del propio juego.

    python3 tools/docs.py build           # capturas, assets, datos y textos (abre una ventana del juego)
    python3 tools/docs.py build --fast    # solo datos y textos, sin capturas ni renders
    python3 tools/docs.py build objects   # solo unas partes: shots, assets, models, objects, sounds, data
    python3 tools/docs.py serve           # http://localhost:8765, con los textos editables
    python3 tools/docs.py texts           # solo textos y ESTILO.md (rápido, sin Godot)

`build` corre tools/capture_docs.gd en Godot (pantallas, assets, modelos, sonidos,
paleta, historia) y luego escribe docs/data/*.js a partir de esos JSON y de
locale/texts.csv, para que docs/index.html se pueda abrir tal cual, sin servidor.

`serve` sirve docs/ y deja cambiar textos desde el visor: cada cambio se escribe
en locale/texts.csv (solo esa fila, respetando el resto del fichero) y Godot
reimporta la traducción.
"""

import csv
import io
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
DATA = os.path.join(DOCS, "data")
TEXTS = os.path.join(ROOT, "locale", "texts.csv")
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
PORT = int(os.environ.get("PORT", "8765"))

# Grupos del visor de textos, por el prefijo de la clave.
GROUPS = [
    ("Historia", ["STORY_", "PROLOGUE_", "ENDING_", "NIGHT_", "MUSEUM_", "LESSON_"]),
    ("Menús", ["MENU_", "JOIN_", "SEAT_", "CHALLENGE_", "BRIEF_", "PLAN_", "NEWS_", "TIP_"]),
    ("Juego", ["HUD_", "LOG_", "END_", "GAME_", "GUARD_", "MIND_", "ZONE_", "PROP_", "PIECE_", "LEGEND_", "BRAIN_"]),
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


def build_static():
    """Lo escrito a mano (docs/ESTILO.md) y la fuente, al lado del HTML."""
    path = os.path.join(DOCS, "ESTILO.md")
    write_js("estilo.js", "ESTILO", open(path, encoding="utf-8").read() if os.path.exists(path) else "")
    write_js("funciones.js", "FUNCIONES", functions())
    os.makedirs(os.path.join(DOCS, "fuentes"), exist_ok=True)
    for f in ["PressStart2P-Regular.ttf", "OFL.txt"]:
        shutil.copy(os.path.join(ROOT, "assets", "fonts", f), os.path.join(DOCS, "fuentes"))


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""


def build(fast, only=()):
    os.makedirs(DATA, exist_ok=True)
    parts = ["data"] if fast else list(only)
    print("Godot: capturando" + (" (solo datos)" if fast else "") + "…")
    r = subprocess.run([GODOT, "--path", ROOT, "--script", "tools/capture_docs.gd", "--", *parts], cwd=ROOT)
    if r.returncode != 0:
        sys.exit("Godot ha fallado")
    t = build_texts()
    build_static()
    write_js("juego.js", "JUEGO", {
        "paleta": load_json("paleta.json", []),
        "historia": load_json("historia.json", {}),
        "catalogo": load_json("catalogo.json", {}),
        "capturas": load_json("capturas.json", []),
        "assets": load_json("assets.json", {}),
        "modelos": load_json("modelos.json", []),
        "objetos": load_json("objetos.json", []),
        "sonidos": load_json("sonidos.json", []),
        "generado": {"fecha": datetime.now().strftime("%d-%m-%Y %H:%M"), "commit": git("rev-parse", "--short", "HEAD"),
                     "rama": git("rev-parse", "--abbrev-ref", "HEAD")},
    })
    broken = [x["key"] for x in t if x["broken"]]
    print(f"Hecho: {len(t)} textos" + (f"; filas rotas en el CSV: {', '.join(broken)}" if broken else ""))


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
        return super().do_GET()

    def do_POST(self):
        if self.path != "/api/texto":
            return self._json(404, {"error": "no existe"})
        # Solo desde esta máquina: es un editor local, no un servicio.
        if self.client_address[0] not in ("127.0.0.1", "::1"):
            return self._json(403, {"error": "solo en local"})
        n = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(n) or b"{}")
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
    else:
        sys.exit(__doc__)
