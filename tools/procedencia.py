#!/usr/bin/env python3
"""De dónde sale cada asset y con qué licencia: lee assets/PROCEDENCIA.json.

    python3 tools/procedencia.py                 # comprueba (falla si un asset no tiene regla o una licencia no está permitida)
    python3 tools/procedencia.py resumen         # cuántos ficheros hay por licencia y por colección
    python3 tools/procedencia.py lista [texto]   # cada fichero con su colección y licencia (filtra por texto)
    python3 tools/procedencia.py credits         # reescribe CREDITS.md a partir de esa fuente
    python3 tools/procedencia.py credits --check # falla si CREDITS.md no coincide con lo que saldría

La fuente es UNA y se edita a mano (el formato se explica en su campo «_ayuda»). La usan
también tools/docs.py (página «Procedencia» de la documentación) y tests/test_procedencia.gd
(la misma comprobación dentro de tests/run_all.sh). Los patrones son los de fnmatch: '*' vale
para cualquier texto, también '/'; gana la primera regla que cubra el fichero.
"""

import fnmatch
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "PROCEDENCIA.json")
CREDITS = os.path.join(ROOT, "CREDITS.md")
NO_DOC = "LicenseRef-Sin-Documentar"


def load():
    with open(SOURCE, encoding="utf-8") as f:
        return json.load(f)


def _match(path, patterns):
    return any(fnmatch.fnmatchcase(path, p) for p in patterns)


def files(data):
    """Los ficheros del ámbito (rutas relativas al proyecto, con '/'), sin los ignorados."""
    out = set()
    for item in data.get("ambito", []):
        if isinstance(item, str):
            item = {"ruta": item}
        base = item["ruta"]
        pattern = item.get("patron")
        recursive = item.get("recursivo", True)
        full = os.path.join(ROOT, base)
        if os.path.isfile(full):
            out.add(base)
            continue
        for dirpath, dirs, names in os.walk(full):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            if not recursive:
                dirs[:] = []
            for n in names:
                rel = os.path.relpath(os.path.join(dirpath, n), ROOT).replace(os.sep, "/")
                if pattern and not fnmatch.fnmatchcase(n, pattern):
                    continue
                out.add(rel)
    ignore = data.get("ignorar", [])
    return sorted(p for p in out if not _match(p, ignore))


def licence_of(data, col):
    return data["licencias"].get(col.get("licencia", ""), {})


def needs_credit(data, col):
    """¿Exige atribución? Lo dicho en la colección o, si falta, lo de su licencia; o algún componente."""
    own = col.get("atribucion")
    if own is None:
        own = licence_of(data, col).get("atribucion", False)
    return bool(own) or any(
        c.get("atribucion", data["licencias"].get(c.get("licencia", ""), {}).get("atribucion", False))
        for c in col.get("componentes", []))


def analyse(data=None):
    """Resuelve todo: {reglas, archivos, sin_regla, errores, avisos, por_licencia, por_coleccion}."""
    data = data or load()
    errors, warnings = [], []
    allowed = set(data.get("permitidas", []))
    for lid in data.get("licencias", {}):
        if lid not in allowed:
            warnings.append(f"licencia descrita pero no permitida: {lid}")
    for lid in allowed:
        if lid not in data["licencias"]:
            errors.append(f"permitida pero sin describir en 'licencias': {lid}")

    def check_licence(where, lid):
        if not lid:
            errors.append(f"{where}: sin licencia")
        elif lid not in data["licencias"]:
            errors.append(f"{where}: licencia desconocida «{lid}»")
        elif lid not in allowed:
            errors.append(f"{where}: licencia «{lid}» no permitida")

    for cid, col in data["colecciones"].items():
        check_licence(f"colección {cid}", col.get("licencia", ""))
        for c in col.get("componentes", []):
            check_licence(f"colección {cid}, componente «{c.get('nombre', '?')}»", c.get("licencia", ""))
        if col.get("tipo") not in ("propio", "externo"):
            errors.append(f"colección {cid}: tipo debe ser «propio» o «externo»")
        if not col.get("metodo"):
            errors.append(f"colección {cid}: sin 'metodo'")
        if col.get("documentado", True) is False and col.get("licencia") != NO_DOC:
            errors.append(f"colección {cid}: sin documentar pero con licencia {col.get('licencia')}")
    rules = data["reglas"]
    for i, r in enumerate(rules):
        if r.get("coleccion") not in data["colecciones"]:
            errors.append(f"regla {i + 1} ({r.get('patron')}): colección desconocida «{r.get('coleccion')}»")
        if "licencia" in r:
            check_licence(f"regla {i + 1}", r["licencia"])

    resolved, sin_regla, used = {}, [], [0] * len(rules)
    for path in files(data):
        for i, r in enumerate(rules):
            pats = r["patron"] if isinstance(r["patron"], list) else [r["patron"]]
            if _match(path, pats):
                used[i] += 1
                resolved[path] = i
                break
        else:
            sin_regla.append(path)
    for path in sin_regla:
        errors.append(f"sin regla de procedencia: {path}")
    for i, r in enumerate(rules):
        if not used[i]:
            warnings.append(f"regla sin ficheros: {r['patron']}")

    def record(i):
        r = rules[i]
        col = dict(data["colecciones"].get(r.get("coleccion"), {}))
        col.update({k: v for k, v in r.items() if k not in ("patron", "coleccion")})
        col["coleccion"] = r.get("coleccion")
        return col

    por_licencia, por_coleccion, undocumented = {}, {}, []
    for path, i in resolved.items():
        col = record(i)
        por_licencia[col.get("licencia", "")] = por_licencia.get(col.get("licencia", ""), 0) + 1
        por_coleccion[col["coleccion"]] = por_coleccion.get(col["coleccion"], 0) + 1
        if col.get("documentado", True) is False:
            undocumented.append(path)
    for cid, col in data["colecciones"].items():
        if col.get("documentado", True) is False:
            warnings.append(f"origen sin documentar: {col['nombre']} ({por_coleccion.get(cid, 0)} ficheros)")
    return {"data": data, "resueltos": resolved, "sin_regla": sin_regla, "errores": errors, "avisos": warnings,
            "por_licencia": por_licencia, "por_coleccion": por_coleccion, "sin_documentar": undocumented,
            "record": record}


# --- La documentación (docs/data/procedencia.js) ---------------------------------------

def web_data():
    """Todo lo que enseña la página «Procedencia» del visor y las fichas de objetos y sonidos."""
    a = analyse()
    data = a["data"]
    colecciones = {}
    for cid, col in data["colecciones"].items():
        c = {k: v for k, v in col.items() if k != "credito"}
        c["atribucion"] = needs_credit(data, col)
        c["documentado"] = col.get("documentado", True)
        c["n"] = a["por_coleccion"].get(cid, 0)
        colecciones[cid] = c
    # Una regla con sobrescrituras (notas propias, otro autor…) sale como variante de su colección.
    variantes, archivos = {}, {}
    for path, i in a["resueltos"].items():
        r = data["reglas"][i]
        extra = {k: v for k, v in r.items() if k not in ("patron", "coleccion")}
        key = r["coleccion"] if not extra else f"{r['coleccion']}#{i}"
        if extra:
            variantes[key] = {**extra, "coleccion": r["coleccion"]}
        archivos[path] = key
    return {"licencias": data["licencias"], "permitidas": data["permitidas"], "colecciones": colecciones,
            "variantes": variantes, "archivos": archivos, "por_licencia": a["por_licencia"],
            "sin_regla": a["sin_regla"], "total": len(a["resueltos"]), "sin_documentar": len(a["sin_documentar"])}


# --- CREDITS.md -----------------------------------------------------------------------

def _lic_link(data, lid):
    lic = data["licencias"].get(lid, {})
    label = lic.get("nombre", lid) if lic.get("url") else lic.get("corta", lid)
    return f"[{label}]({lic['url']})" if lic.get("url") else label


def _first_sentence(text):
    text = text.strip()
    cut = text.find(". ")
    return text if cut < 0 else text[:cut + 1]


def credits_text():
    data = load()
    cols = data["colecciones"]
    ext = [(cid, c) for cid, c in cols.items() if c["tipo"] == "externo"]
    own = [(cid, c) for cid, c in cols.items() if c["tipo"] == "propio" and c.get("documentado", True)]
    nodoc = [(cid, c) for cid, c in cols.items() if c.get("documentado", True) is False]
    out = ["# Créditos", "",
           "<!-- Generado por tools/procedencia.py a partir de assets/PROCEDENCIA.json: no se edita a mano. -->", "",
           "## Recursos de terceros", "",
           "| recurso | autor | licencia |", "|---|---|---|"]
    for cid, c in ext:
        out.append(f"| {c.get('credito') or c['nombre']} | {c['autor']} | {_lic_link(data, c['licencia'])} |")
    out += ["", "### Atribución", ""]
    for cid, c in cols.items():
        if c["tipo"] == "externo" and needs_credit(data, c):
            lic = data["licencias"][c["licencia"]]
            out.append(f"- **Obligatoria** ({lic['corta']}): *{c['nombre'].split(' (')[0]}* por {c['autor']}, con licencia "
                       f"{lic['nombre']}. {c.get('notas', '')}".rstrip())
    for cid, c in cols.items():
        for comp in c.get("componentes", []):
            lic = data["licencias"][comp["licencia"]]
            if comp.get("atribucion", lic.get("atribucion", False)):
                out.append(f"- **Obligatoria** ({lic['corta']}): {comp['nombre']}, de {comp['autor']}"
                           f" ({comp['url']}), dentro de «{c['nombre']}». {comp.get('nota', '')}".rstrip())
    out += ["- Los modelos de Poly Pizza se descargaron de [Poly Pizza](https://poly.pizza).",
            "- Los kits de ciudad y casa de Kenney (www.kenney.nl) son CC0: no piden atribución, pero se la damos igual. "
            "Se usan tal cual, en `.glb`; los colores de noche, las ventanas encendidas y los tejados los pone el juego "
            "(`TownBuilder.NIGHT_SHADER`).",
            "", "## Obra propia y material que la acompaña", "",
            "| colección | cómo se hizo | licencia |", "|---|---|---|"]
    for cid, c in own:
        parts = "; ".join(f"{k['nombre']} — {k['autor']}, {data['licencias'][k['licencia']]['corta']}" for k in c.get("componentes", []))
        how = _first_sentence(c["metodo"]) + (f" Lleva: {parts}." if parts else "")
        out.append(f"| {c['nombre']} | {how} | {data['licencias'][c['licencia']]['corta']} |")
    out += ["", "## Origen sin documentar", "",
            "Estos assets están en el juego pero no se anotó de dónde salen ni con qué licencia. "
            "Cuando se sepa, se completa en `assets/PROCEDENCIA.json`.", ""]
    for cid, c in nodoc:
        out.append(f"- **{c['nombre']}**: {c['metodo']} {c.get('notas', '')}".rstrip())
    out += ["", "El detalle de cada fichero (colección, método, autor y licencia) está en la página «Procedencia» de la "
            "documentación (`python3 tools/docs.py serve`) y se comprueba con `python3 tools/procedencia.py`.", ""]
    return "\n".join(out)


# --- Línea de órdenes -------------------------------------------------------------------

def report(a, verbose=True):
    n = len(a["resueltos"])
    if verbose:
        print(f"{n} ficheros con regla; {len(a['sin_regla'])} sin regla")
        for lic, k in sorted(a["por_licencia"].items(), key=lambda x: -x[1]):
            print(f"  {a['data']['licencias'].get(lic, {}).get('corta', lic):<16} {k}")
    for w in a["avisos"]:
        print(f"AVISO: {w}")
    for e in a["errores"]:
        print(f"FALLO: {e}")
    print(f"FALLOS: {len(a['errores'])}")


def main(argv):
    cmd = argv[0] if argv else "check"
    if cmd == "credits":
        text = credits_text()
        if "--check" in argv:
            cur = open(CREDITS, encoding="utf-8").read() if os.path.exists(CREDITS) else ""
            if cur != text:
                print("FALLO: CREDITS.md no coincide con assets/PROCEDENCIA.json (python3 tools/procedencia.py credits)")
                return 1
            print("CREDITS.md al día")
            return 0
        open(CREDITS, "w", encoding="utf-8").write(text)
        print(f"CREDITS.md escrito ({text.count(chr(10))} líneas)")
        return 0
    a = analyse()
    if cmd in ("check", "comprobar"):
        report(a, verbose=False)
        return 1 if a["errores"] else 0
    if cmd == "resumen":
        report(a)
        for cid, k in sorted(a["por_coleccion"].items(), key=lambda x: -x[1]):
            print(f"  {k:>4}  {cid}")
        return 1 if a["errores"] else 0
    if cmd == "lista":
        q = argv[1].lower() if len(argv) > 1 else ""
        for path, i in a["resueltos"].items():
            rec = a["record"](i)
            row = f"{path}\t{rec['coleccion']}\t{rec.get('licencia')}"
            if q in row.lower():
                print(row)
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
