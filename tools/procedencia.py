#!/usr/bin/env python3
"""De dónde sale cada asset y con qué licencia: lee assets/PROCEDENCIA.json.

    python3 tools/procedencia.py                 # comprueba (falla si un asset no tiene regla, una licencia no está permitida
                                                 # o un JSON de docs/data/alternativas/ o docs/data/referencias.json es incorrecto)
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
from datetime import datetime
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "PROCEDENCIA.json")
CREDITS = os.path.join(ROOT, "CREDITS.md")
ALT_DIR = os.path.join(ROOT, "docs", "data", "alternativas")
ELEGIDAS = os.path.join(ROOT, "docs", "data", "alternativas_elegidas.json")
NUESTRA = "nuestra"
REFERENCIAS = os.path.join(ROOT, "docs", "data", "referencias.json")
REF_TIPOS = ("icons", "modelos", "audio", "arte", "codigo", "articulo", "texturas", "fuentes", "voz", "otro")
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
    alt_e, alt_w = alternativas_errors(data)
    errors.extend(alt_e)
    errors.extend(referencias_errors())
    warnings.extend(alt_w)
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


# --- Alternativas de terceros (docs/data/alternativas/*.json) ------------------------------
# Un JSON por categoría (modelos, audio, ui): {"categoria", "grupos": [{"coleccion", "que_es", "alternativas": [...]}]}.
# Los ficheros que empiezan por «_» (plantilla) se validan pero no se enseñan en el visor.
# Cada grupo se identifica por su "id" (opcional) o, si falta, por su colección; es lo que se elige.

ALT_REQUIRED = ("id", "nombre", "url", "autor", "licencia", "cubre")


def alt_files():
    if not os.path.isdir(ALT_DIR):
        return []
    return sorted(f for f in os.listdir(ALT_DIR) if f.endswith(".json"))


def alt_group_key(g):
    return g.get("id") or g.get("coleccion", "")


def alt_load():
    """[(fichero, contenido o None si no se puede leer, error o None)]."""
    out = []
    for f in alt_files():
        try:
            with open(os.path.join(ALT_DIR, f), encoding="utf-8") as fh:
                out.append((f, json.load(fh), None))
        except (OSError, ValueError) as e:
            out.append((f, None, str(e)))
    return out


def alternativas_errors(data=None):
    """(errores, avisos) de todos los JSON de alternativas."""
    data = data or load()
    errors, warnings = [], []
    real_ids, real_keys = {}, {}
    for f, doc, err in alt_load():
        w = f"alternativas/{f}"
        # Las plantillas («_…») se validan aparte: sus ids y grupos no chocan con los reales.
        ids, keys = ({}, {}) if f.startswith("_") else (real_ids, real_keys)
        if err:
            errors.append(f"{w}: no es un JSON válido ({err})")
            continue
        if not isinstance(doc, dict) or not isinstance(doc.get("grupos"), list):
            errors.append(f"{w}: falta la lista 'grupos'")
            continue
        if not doc.get("categoria"):
            errors.append(f"{w}: sin 'categoria'")
        for gi, g in enumerate(doc["grupos"]):
            if not isinstance(g, dict):
                errors.append(f"{w}: grupo {gi + 1} no es un objeto")
                continue
            col = g.get("coleccion", "")
            gw = f"{w}, grupo {gi + 1} ({col or '?'})"
            if col not in data["colecciones"]:
                errors.append(f"{gw}: colección desconocida «{col}»")
            if not g.get("que_es"):
                errors.append(f"{gw}: sin 'que_es'")
            key = alt_group_key(g)
            if key in keys:
                errors.append(f"{gw}: grupo «{key}» repetido (ya está en {keys[key]}; usa un 'id' distinto)")
            keys[key] = w
            alts = g.get("alternativas")
            if not isinstance(alts, list):
                errors.append(f"{gw}: falta la lista 'alternativas'")
                continue
            for ai, a in enumerate(alts):
                if not isinstance(a, dict):
                    errors.append(f"{gw}: alternativa {ai + 1} no es un objeto")
                    continue
                aw = f"{gw}, alternativa «{a.get('id', ai + 1)}»"
                for k in ALT_REQUIRED:
                    if not isinstance(a.get(k), str) or not a[k].strip():
                        errors.append(f"{aw}: falta '{k}'")
                aid = a.get("id")
                if isinstance(aid, str) and aid:
                    if aid == NUESTRA or not all(c.isalnum() or c in "-_" for c in aid):
                        errors.append(f"{aw}: id no válido (letras, cifras, - y _; y no «{NUESTRA}»)")
                    if aid in ids:
                        errors.append(f"{aw}: id repetido (también en {ids[aid]})")
                    ids[aid] = w
                if isinstance(a.get("url"), str) and a["url"] and not a["url"].startswith(("http://", "https://")):
                    errors.append(f"{aw}: 'url' debe empezar por http(s)://")
                pv = a.get("preview_url")
                if pv not in (None, "") and not (isinstance(pv, str) and pv.startswith(("http://", "https://"))):
                    errors.append(f"{aw}: 'preview_url' debe ser una URL http(s), vacío o faltar")
                if not isinstance(a.get("atribucion"), bool):
                    errors.append(f"{aw}: 'atribucion' debe ser true o false")
                e = a.get("encaje")
                if not (isinstance(e, int) and not isinstance(e, bool) and 1 <= e <= 5):
                    errors.append(f"{aw}: 'encaje' debe ser un entero de 1 a 5")
                lic = a.get("licencia")
                if isinstance(lic, str) and lic.strip() and lic not in data.get("permitidas", []):
                    warnings.append(f"{aw}: licencia «{lic}» fuera de las permitidas del proyecto (¿se puede usar?)")
    return errors, warnings


def alt_elegidas():
    try:
        with open(ELEGIDAS, encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def alt_web_data():
    """Lo que enseña el visor: los grupos con alternativas (sin los ficheros «_») y lo elegido."""
    grupos, cats = [], []
    for f, doc, err in alt_load():
        if err or f.startswith("_") or not isinstance(doc, dict) or not isinstance(doc.get("grupos"), list):
            continue
        cat = doc.get("categoria", f[:-5])
        if cat not in cats:
            cats.append(cat)
        for g in doc["grupos"]:
            if isinstance(g, dict) and isinstance(g.get("alternativas"), list) and g["alternativas"]:
                grupos.append({**g, "key": alt_group_key(g), "categoria": cat})
    valid = {g["key"]: {a.get("id") for a in g["alternativas"]} | {NUESTRA} for g in grupos}
    elegidas = {k: v for k, v in alt_elegidas().items() if k in valid and v in valid[k] and v != NUESTRA}
    return {"categorias": cats, "grupos": grupos, "elegidas": elegidas}


# --- Referencias guardadas (docs/data/referencias.json) ---------------------------------
# Enlaces de inspiración y recursos: [{id, titulo, url, tipo, etiquetas[], licencia, nota, fecha, estado,
# items[] opcional: {nombre, url?, para, ya_lo_usamos?}}].

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
    its = r.get("items", [])
    if not isinstance(its, list):
        errs.append(f"{w}: 'items' debe ser una lista")
        its = []
    for j, it in enumerate(its):
        iw = f"{w}, item {j + 1}"
        if not isinstance(it, dict):
            errs.append(f"{iw}: no es un objeto")
            continue
        for k in ("nombre", "para"):
            if not isinstance(it.get(k), str) or not it[k].strip():
                errs.append(f"{iw}: falta '{k}'")
        if "url" in it:
            p = urlparse(it["url"]) if isinstance(it["url"], str) else None
            if p is None or p.scheme not in ("http", "https") or not p.netloc:
                errs.append(f"{iw}: 'url' debe ser http(s)://…")
        if "ya_lo_usamos" in it and not isinstance(it["ya_lo_usamos"], bool):
            errs.append(f"{iw}: 'ya_lo_usamos' debe ser verdadero o falso")
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
    """Las referencias para el visor, cada una con lo que comparte dominio con una colección o una alternativa."""
    refs, _ = ref_load()
    src = load()
    hosts = {}  # dominio -> [(coleccion, nombre de la alternativa o "")]
    for cid, c in src.get("colecciones", {}).items():
        for u in [c.get("url")] + [x.get("url") for x in c.get("componentes", [])]:
            if _host(u):
                hosts.setdefault(_host(u), []).append((cid, ""))
    for g in alt_web_data()["grupos"]:
        for a in g["alternativas"]:
            if _host(a.get("url")):
                hosts.setdefault(_host(a["url"]), []).append((g.get("coleccion", ""), a.get("nombre", "")))
    out = []
    for r in refs:
        if not isinstance(r, dict) or ref_item_errors(r):
            continue
        rel, vistos = [], set()
        for cid, alt in hosts.get(_host(r["url"]), []):
            if (cid, alt) in vistos or cid not in src.get("colecciones", {}):
                continue
            vistos.add((cid, alt))
            rel.append({"coleccion": cid, "nombre": src["colecciones"][cid].get("nombre", cid), "alternativa": alt})
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
