#!/usr/bin/env python3
"""De dónde sale cada asset y con qué licencia: lee assets/PROCEDENCIA.json.

    python3 tools/procedencia.py                 # comprueba (falla si un asset no tiene regla, una licencia no está permitida
                                                 # o docs/data/propuestas.json o docs/data/referencias.json es incorrecto)
    python3 tools/procedencia.py resumen         # cuántos ficheros hay por licencia y por colección
    python3 tools/procedencia.py lista [texto]   # cada fichero con su colección y licencia (filtra por texto)
    python3 tools/procedencia.py credits         # reescribe CREDITS.md a partir de esa fuente
    python3 tools/procedencia.py credits --check # falla si CREDITS.md no coincide con lo que saldría

La fuente es UNA y se edita a mano (el formato se explica en su campo «_ayuda»). La usan
también tools/docs.py (etiquetas de licencia de las fichas y tabla «Lo que ya usamos» de la documentación) y tests/test_procedencia.gd
(la misma comprobación dentro de tests/run_all.sh). Los patrones son los de fnmatch: '*' vale
para cualquier texto, también '/'; gana la primera regla que cubra el fichero.
"""

import fnmatch
import json
import os
import sys
from datetime import datetime
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "PROCEDENCIA.json")
CREDITS = os.path.join(ROOT, "CREDITS.md")
PROPUESTAS = os.path.join(ROOT, "docs", "data", "propuestas.json")
REFERENCIAS = os.path.join(ROOT, "docs", "data", "referencias.json")
REF_TIPOS = ("icons", "modelos", "audio", "arte", "codigo", "articulo", "otro")
REF_ESTADOS = ("guardada", "evaluada", "usada", "descartada")
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
    errors.extend(propuestas_errors())
    errors.extend(referencias_errors())
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


# --- Propuestas de assets a incorporar (docs/data/propuestas.json) ------------------------
# Una lista de assets concretos (un modelo, un sonido, un icono, un pack pequeño) que se proponen para el
# juego: [{id, nombre, pack, pack_url, url, tipo, licencia, atribucion, preview_url, para, estado, nota}].

PROP_TIPOS = ("modelo", "sonido", "imagen", "otro")
PROP_ESTADOS = ("propuesto", "aceptado", "incorporado", "descartado")
PROP_REQUIRED = ("id", "nombre", "pack", "url", "tipo", "licencia", "para", "estado")


def prop_load():
    """(lista, error o None). Si el fichero no existe, es una lista vacía."""
    try:
        with open(PROPUESTAS, encoding="utf-8") as f:
            d = json.load(f)
    except FileNotFoundError:
        return [], None
    except (OSError, ValueError) as e:
        return [], str(e)
    if not isinstance(d, list):
        return [], "debe ser una lista de propuestas"
    return d, None


def prop_save(props):
    """Escritura atómica de docs/data/propuestas.json (quien llame se encarga del candado)."""
    tmp = PROPUESTAS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(props, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.replace(tmp, PROPUESTAS)


def _is_http(u):
    p = urlparse(u) if isinstance(u, str) else None
    return bool(p and p.scheme in ("http", "https") and p.netloc)


def prop_item_errors(r, w="propuesta"):
    """Errores de una propuesta suelta: campos, URL http(s), tipo y estado."""
    if not isinstance(r, dict):
        return [f"{w}: no es un objeto"]
    errs = []
    for k in PROP_REQUIRED:
        if not isinstance(r.get(k), str) or not r[k].strip():
            errs.append(f"{w}: falta '{k}'")
    rid = r.get("id")
    if isinstance(rid, str) and rid and not all(c.isalnum() or c in "-_" for c in rid):
        errs.append(f"{w}: id no válido (letras, cifras, - y _)")
    if isinstance(r.get("url"), str) and r["url"] and not _is_http(r["url"]):
        errs.append(f"{w}: 'url' debe ser http(s)://…")
    for k in ("pack_url", "preview_url"):
        if r.get(k) not in (None, "") and not _is_http(r[k]):
            errs.append(f"{w}: '{k}' debe ser una URL http(s), vacío o faltar")
    if isinstance(r.get("tipo"), str) and r["tipo"] and r["tipo"] not in PROP_TIPOS:
        errs.append(f"{w}: tipo «{r['tipo']}» no válido ({', '.join(PROP_TIPOS)})")
    if isinstance(r.get("estado"), str) and r["estado"] and r["estado"] not in PROP_ESTADOS:
        errs.append(f"{w}: estado «{r['estado']}» no válido ({', '.join(PROP_ESTADOS)})")
    if not isinstance(r.get("atribucion"), bool):
        errs.append(f"{w}: 'atribucion' debe ser true o false")
    if "nota" in r and not isinstance(r["nota"], str):
        errs.append(f"{w}: 'nota' debe ser un texto")
    return errs


def propuestas_errors():
    props, err = prop_load()
    if err:
        return [f"propuestas.json: {err}"]
    errors, seen = [], {}
    for i, r in enumerate(props):
        w = f"propuestas.json, {i + 1}" + (f" («{r['id']}»)" if isinstance(r, dict) and r.get("id") else "")
        errors += prop_item_errors(r, w)
        rid = r.get("id") if isinstance(r, dict) else None
        if isinstance(rid, str) and rid:
            if rid in seen:
                errors.append(f"{w}: id repetido")
            seen[rid] = True
    return errors


def prop_web_data():
    """Las propuestas válidas para el visor (con todos los campos normalizados)."""
    props, _ = prop_load()
    out = []
    for r in props:
        if isinstance(r, dict) and not prop_item_errors(r):
            out.append({**r, "pack_url": r.get("pack_url") or "", "preview_url": r.get("preview_url") or "",
                        "nota": r.get("nota") or ""})
    return out


# --- Referencias guardadas (docs/data/referencias.json) ---------------------------------
# Enlaces de inspiración y recursos: [{id, titulo, url, tipo, etiquetas[], licencia, nota, fecha, estado}].

REF_REQUIRED = ("id", "titulo", "url", "tipo", "fecha", "estado")


def ref_load():
    """(lista, error o None). Si el fichero no existe, es una lista vacía."""
    try:
        with open(REFERENCIAS, encoding="utf-8") as f:
            d = json.load(f)
    except FileNotFoundError:
        return [], None
    except (OSError, ValueError) as e:
        return [], str(e)
    if not isinstance(d, list):
        return [], "debe ser una lista de referencias"
    return d, None


def ref_save(refs):
    """Escritura atómica de docs/data/referencias.json (quien llame se encarga del candado)."""
    tmp = REFERENCIAS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(refs, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.replace(tmp, REFERENCIAS)


def ref_item_errors(r, w="referencia"):
    """Errores de una referencia suelta (los campos obligatorios, la URL http(s), tipo, estado y fecha)."""
    if not isinstance(r, dict):
        return [f"{w}: no es un objeto"]
    errs = []
    for k in REF_REQUIRED:
        if not isinstance(r.get(k), str) or not r[k].strip():
            errs.append(f"{w}: falta '{k}'")
    rid = r.get("id")
    if isinstance(rid, str) and rid and not all(c.isalnum() or c in "-_" for c in rid):
        errs.append(f"{w}: id no válido (letras, cifras, - y _)")
    u = r.get("url")
    if isinstance(u, str) and u:
        p = urlparse(u)
        if p.scheme not in ("http", "https") or not p.netloc:
            errs.append(f"{w}: 'url' debe ser http(s)://…")
    if isinstance(r.get("tipo"), str) and r["tipo"] and r["tipo"] not in REF_TIPOS:
        errs.append(f"{w}: tipo «{r['tipo']}» no válido ({', '.join(REF_TIPOS)})")
    if isinstance(r.get("estado"), str) and r["estado"] and r["estado"] not in REF_ESTADOS:
        errs.append(f"{w}: estado «{r['estado']}» no válido ({', '.join(REF_ESTADOS)})")
    if isinstance(r.get("fecha"), str) and r["fecha"]:
        try:
            datetime.strptime(r["fecha"], "%Y-%m-%d")
        except ValueError:
            errs.append(f"{w}: 'fecha' debe ser YYYY-MM-DD")
    et = r.get("etiquetas", [])
    if not isinstance(et, list) or not all(isinstance(x, str) and x.strip() for x in et):
        errs.append(f"{w}: 'etiquetas' debe ser una lista de textos")
    for k in ("licencia", "nota"):
        if k in r and not isinstance(r[k], str):
            errs.append(f"{w}: '{k}' debe ser un texto")
    return errs


def referencias_errors():
    refs, err = ref_load()
    if err:
        return [f"referencias.json: {err}"]
    errors, seen = [], {}
    for i, r in enumerate(refs):
        w = f"referencias.json, {i + 1}" + (f" («{r['id']}»)" if isinstance(r, dict) and r.get("id") else "")
        errors += ref_item_errors(r, w)
        rid = r.get("id") if isinstance(r, dict) else None
        if isinstance(rid, str) and rid:
            if rid in seen:
                errors.append(f"{w}: id repetido")
            seen[rid] = True
    return errors


def _host(u):
    h = urlparse(u).netloc.lower() if isinstance(u, str) else ""
    return h[4:] if h.startswith("www.") else h


def ref_web_data():
    """Las referencias para el visor, cada una con las propuestas que comparten dominio con ella."""
    refs, _ = ref_load()
    hosts = {}  # dominio -> [(id de la propuesta, nombre)]
    for p in prop_web_data():
        for u in (p.get("url"), p.get("pack_url")):
            if _host(u):
                hosts.setdefault(_host(u), []).append((p["id"], p["nombre"]))
    out = []
    for r in refs:
        if not isinstance(r, dict) or ref_item_errors(r):
            continue
        rel, vistos = [], set()
        for pid, nombre in hosts.get(_host(r["url"]), []):
            if pid not in vistos:
                vistos.add(pid)
                rel.append({"propuesta": pid, "nombre": nombre})
        out.append({**r, "etiquetas": r.get("etiquetas", []), "dominio": _host(r["url"]), "relacionadas": rel})
    return out


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
