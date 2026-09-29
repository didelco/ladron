"""CLI de megafonía: frases.csv -> TTS (con caché) -> efectos -> LUFS -> out/{dry,wet}/<id>.ogg

  python src/build.py                     # todas las frases
  python src/build.py --only cierre_15    # una
  python src/build.py --preset pasillo    # fuerza un preset para todas
  python src/build.py --force             # regenera también el TTS
  python src/build.py --takes 3           # 3 tomas por frase (velocidad ±3 %)
  python src/build.py --desde-juego --limit 5   # frases MEGA_* de locale/texts.csv
  python src/build.py --godot-dir ../..   # además copia out/ a <proyecto>/audio/megafonia/
  python src/build.py preview cierre_15   # escucha out/wet/cierre_15.ogg con afplay
"""
import argparse
import csv
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
import yaml
from pedalboard import Pedalboard

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export  # noqa: E402
import fx  # noqa: E402
import tts  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
llamadas_tts = 0


def carga_config(ruta):
    cfg = yaml.safe_load(open(ruta, encoding="utf-8"))
    cfg["_raiz"] = Path(ruta).resolve().parent
    return cfg


def ruta(cfg, clave):
    return cfg["_raiz"] / cfg["paths"][clave]


def ruta_ir(cfg, nombre):
    """Una IR se nombra por su fichero en ir/ (sin .wav) o por ruta."""
    p = Path(nombre)
    return str(p if p.suffix else ruta(cfg, "ir") / f"{nombre}.wav")


def si(valor):
    return str(valor).strip().lower() in ("true", "1", "si", "sí", "yes")


# --- TTS con caché ---------------------------------------------------------

def voz_seca(cfg, texto, voz, velocidad, force=False):
    """Wav seco del TTS; se reutiliza si no cambian texto, voz, velocidad ni modelo."""
    global llamadas_tts
    t = cfg["tts"]
    fichero = ruta(cfg, "cache") / f"{tts.clave(texto, voz, velocidad, t['model'])}.wav"
    if fichero.exists() and not force:
        a, sr = sf.read(fichero, dtype="float32")
        return a, sr
    llamadas_tts += 1
    a, sr = tts.sintetiza(texto, voz, velocidad, {**t, "_raiz": cfg["_raiz"]})
    fichero.parent.mkdir(parents=True, exist_ok=True)
    sf.write(fichero, a, sr, subtype="FLOAT")
    return a, sr


# --- Locución con sonidos: "[carraspeo] Atención. [risa]" ----------------------

ETIQUETA = re.compile(r"\[(\w+)(?::(muestra|tts))?\]")


def _rms_banda(x, sr, p):
    """Nivel RMS dentro de la banda de la bocina (lo que se va a oír tras los filtros)."""
    y = Pedalboard(fx._filtros(p))(x.astype(np.float32), sr)
    w = int(0.02 * sr)
    r = np.sqrt(np.mean(y[: len(y) // w * w].reshape(-1, w) ** 2, axis=1))
    activo = r[r > r.max() * 10 ** (-30 / 20)]  # solo los tramos con señal
    return float(np.sqrt(np.mean(activo ** 2))) if len(activo) else 1e-6


def locucion(cfg, texto, voz, velocidad, preset="sala", force=False, modo=None):
    """Texto con etiquetas -> audio seco (sample_rate de export) listo para la cadena.

    El texto se trocea por las etiquetas; cada trozo va al TTS (con su caché) y cada etiqueta
    se sustituye por su muestra (o por el TTS de su texto), con pausas antes y después.
    El nivel de las muestras se iguala al de la voz dentro de la banda del preset, + gain_db.
    Solo suenan si vocales.activas y la etiqueta está en vocales.permitidas; las demás se quitan
    sin sonar.
    `modo` ("muestra"/"tts") fuerza que suenen todas (lo usan las pruebas A/B)."""
    sr = cfg["export"]["sample_rate"]
    v = cfg.get("vocales", {})
    p = cfg["presets"][preset]
    trozos = []  # (tipo, audio): tipo "voz" o "sonido"
    pos = 0
    for m in list(ETIQUETA.finditer(texto)) + [None]:
        frase = texto[pos: m.start() if m else len(texto)].strip()
        if frase:
            a, sra = voz_seca(cfg, frase, voz, velocidad, force)
            trozos.append(("voz", fx.remuestrea(a, sra, sr)))
        if m is None:
            break
        pos = m.end()
        nombre, forzado = m.group(1), m.group(2)
        if modo is None and not (v.get("activas") and nombre in (v.get("permitidas") or [])):
            continue  # sonido apagado: la etiqueta se quita del texto
        if nombre not in v.get("tipos", {}):
            raise SystemExit(f"Etiqueta desconocida [{nombre}]: añádela en config.yaml (vocales.tipos)")
        t = v["tipos"][nombre]
        if (forzado or modo or v.get("modo", "muestra")) == "tts":
            a, sra = voz_seca(cfg, t["tts"], voz, velocidad, force)
            trozos.append(("tts", fx.remuestrea(a, sra, sr)))
        else:
            a, sra = sf.read(cfg["_raiz"] / t["muestra"], dtype="float32")
            trozos.append(("sonido", (fx.remuestrea(a, sra, sr), t.get("gain_db", 0.0))))
    voces = [a for tipo, a in trozos if tipo != "sonido"]
    ref = _rms_banda(np.concatenate(voces), sr, p) if voces else 0.1
    salida = []
    for tipo, a in trozos:
        if tipo == "sonido":
            a, g = a
            a = a * (ref / _rms_banda(a, sr, p)) * 10 ** (g / 20)
            salida += [np.zeros(int(v.get("pausa_antes", 0.2) * sr), np.float32), a,
                       np.zeros(int(v.get("pausa_despues", 0.3) * sr), np.float32)]
        else:
            salida.append(a)
    return np.concatenate(salida).astype(np.float32), sr


# --- Montaje ---------------------------------------------------------------

def chime(cfg):
    """assets/chime.wav: si no existe se sintetiza (ding-dong de dos notas)."""
    f = ruta(cfg, "chime")
    sr = cfg["export"]["sample_rate"]
    if not f.exists():
        c = cfg["chime"]
        partes = []
        for hz in c["notes"]:
            n = int(c["note_length"] * sr)
            t = np.arange(n) / sr
            # campana: fundamental + parciales con caída exponencial y ataque corto
            nota = sum(g * np.sin(2 * np.pi * hz * m * t) * np.exp(-t * d)
                       for m, g, d in [(1, 1.0, 3.0), (2, 0.35, 5.0), (3, 0.12, 8.0), (4.2, 0.06, 12.0)])
            nota *= np.minimum(1, t / 0.005)
            partes.append(nota)
        paso = int(c["note_length"] * 0.55 * sr)  # la segunda nota entra antes de que acabe la primera
        out = np.zeros(paso * (len(partes) - 1) + len(partes[-1]))
        for i, p in enumerate(partes):
            out[i * paso: i * paso + len(p)] += p
        out = out / np.abs(out).max() * 0.7  # el nivel final lo pone chime.volume_db al montar
        f.parent.mkdir(parents=True, exist_ok=True)
        sf.write(f, out.astype(np.float32), sr, subtype="PCM_16")
    a, sr_c = sf.read(f, dtype="float32")
    return fx.remuestrea(a, sr_c, sr)


def mezcla(base, cambios):
    """Copia de un preset con cambios (los dicts anidados se mezclan, no se sustituyen)."""
    out = dict(base)
    for k, v in (cambios or {}).items():
        out[k] = mezcla(base.get(k, {}), v) if isinstance(v, dict) else v
    return out


def procesa(cfg, voz, sr_voz, preset, wet, con_chime=False, ir=None, ajustes=None, cola=None):
    """Audio seco -> audio final normalizado (float32, sample_rate de export).
    `ajustes` cambia valores del preset solo para esta llamada (para pruebas A/B).
    `cola`: segundos de silencio al final (por defecto export.tail_silence)."""
    e = cfg["export"]
    sr = e["sample_rate"]
    p = mezcla(cfg["presets"][preset], ajustes)
    x = fx.remuestrea(voz, sr_voz, sr)
    x = np.concatenate([np.zeros(int(e["lead_silence"] * sr), np.float32), x])
    y = fx.aplica(x, sr, p, wet=wet, ir=ruta_ir(cfg, ir or p["reverb"]["ir"]),
                  cola=e["tail_silence"] if cola is None else cola)
    n = min(len(y), int(e.get("fade_out", 0.05) * sr))  # fundido final: sin clic si la cola corta la reverb
    y[-n:] *= np.linspace(1, 0, n)
    techo = p["limiter_db"] - e.get("true_peak_margin_db", 0.0)
    y = export.normaliza_lufs(y, sr, e["lufs"], techo)
    if con_chime and p.get("chime", True):
        # el chime va limpio (no pasa por la bocina), a volume_db respecto a la voz
        c = export.normaliza_lufs(chime(cfg), sr, e["lufs"] + cfg["chime"]["volume_db"], techo)
        y = np.concatenate([c, np.zeros(int(cfg["chime"]["gap"] * sr), np.float32), y])
        y = export.normaliza_lufs(y, sr, e["lufs"], techo)
    return y


def lee_frases(cfg):
    """Filas de frases.csv: id, texto, preset, voz, velocidad, chime."""
    with open(ruta(cfg, "csv"), newline="", encoding="utf-8") as f:
        return [r for r in csv.DictReader(f) if r.get("id") and not r["id"].startswith("#")]


def con_sonidos(texto, spec):
    """Mete etiquetas en el texto: spec {sonido: "inicio" | "final" | N (tras la frase N)}."""
    frases = [f for f in re.split(r"(?<=[.!?…])\s+", texto.strip()) if f]
    antes, despues = [], {}
    for sonido, pos in spec.items():
        if pos == "inicio":
            antes.append(f"[{sonido}]")
        elif pos == "final":
            despues.setdefault(len(frases), []).append(f"[{sonido}]")
        else:
            despues.setdefault(min(int(pos), len(frases)), []).append(f"[{sonido}]")
    partes = antes[:]
    for i, f in enumerate(frases, 1):
        partes += [f] + despues.get(i, [])
    return " ".join(partes)


def sonidos_activos(cfg, texto):
    v = cfg.get("vocales", {})
    if not v.get("activas"):
        return []
    return [m.group(1) for m in ETIQUETA.finditer(texto) if m.group(1) in (v.get("permitidas") or [])]


def aplica_sonidos_por_frase(cfg, filas):
    """Añade los sonidos de vocales_por_frase.yaml (por id) y avisa si se pasa algún tope."""
    v = cfg.get("vocales", {})
    f = cfg["_raiz"] / v.get("por_frase", "vocales_por_frase.yaml")
    mapa = (yaml.safe_load(open(f, encoding="utf-8")) or {}) if f.exists() else {}
    for r in filas:
        if r["id"] in mapa:
            r["texto"] = con_sonidos(r["texto"], mapa[r["id"]])
        r["tags"] = sonidos_activos(cfg, r["texto"])
    for sonido, tope in (v.get("max_por_lote") or {}).items():
        n = sum(sonido in r["tags"] for r in filas)
        limite = tope * len(filas) if tope < 1 else tope
        if n > max(1, limite):
            print(f"  AVISO: [{sonido}] sale en {n} de {len(filas)} frases (tope {tope})")
    return filas


CLAVE_JUEGO = re.compile(r"^MEGA_[A-Z0-9_]+_\d+$")


def lee_frases_juego(cfg):
    """Frases MEGA_* del CSV de textos del juego, como filas de frases.csv.

    id = clave en minúsculas (MEGA_ACT_ROLL_WALL_10 -> mega_act_roll_wall_10). El preset sale de
    juego.presets (por prefijo de clave; si no, juego.preset). Las frases con %s (la pieza se pone
    al jugar) se saltan, salvo que juego.relleno_pieza diga con qué rellenarlas."""
    j = cfg["juego"]
    filas, saltadas = [], []
    validas = claves_megaphone(cfg)
    vistas = set()
    with open(cfg["_raiz"] / j["csv"], newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            clave, texto = r["keys"], r[j["columna"]]
            if not CLAVE_JUEGO.match(clave) or (validas and clave not in validas):
                continue
            vistas.add(clave)
            if "%s" in texto:
                if not j.get("relleno_pieza"):
                    saltadas.append(clave)
                    continue
                texto = texto.replace("%s", j["relleno_pieza"])
            preset = next((pr for pref, pr in (j.get("presets") or {}).items() if clave.startswith(pref)),
                          j["preset"])
            filas.append({"id": clave.lower(), "clave": clave, "texto": texto, "preset": preset, "voz": "",
                          "velocidad": "", "chime": str(j.get("chime", False))})
    faltan = sorted(set(validas) - vistas)
    if faltan:
        print(f"  AVISO: megaphone.gd usa {len(faltan)} claves que no están en el CSV: {', '.join(faltan)}")
    if saltadas:
        print(f"  (se saltan {len(saltadas)} frases con %s: {', '.join(saltadas)})")
    return filas


def claves_megaphone(cfg):
    """Claves que dice el juego (POOLS de logic/megaphone.gd): MEGA_<POOL>_<NN>."""
    gd = cfg["_raiz"] / cfg["juego"].get("megaphone_gd", "")
    if not gd.is_file():
        return set()
    texto = gd.read_text(encoding="utf-8")
    bloque = re.search(r"const POOLS := \{(.*?)\n\}", texto, re.S).group(1)
    return {f"MEGA_{pool.upper()}_{i:02d}" for pool, n in re.findall(r'"(\w+)":\s*(\d+)', bloque)
            for i in range(1, int(n) + 1)}


def duracion(fichero):
    return sf.info(str(fichero)).duration


def escribe_indice(cfg, hechas):
    """out/megafonia_index.json: por id, rutas res:// (wet y dry), duración, preset y texto.
    Se mezcla con el índice que ya hubiera y se quitan las entradas sin fichero."""
    out = ruta(cfg, "out")
    fichero = out / "megafonia_index.json"
    base = "res://" + cfg["godot"]["res_dir"].strip("/")
    indice = json.loads(fichero.read_text(encoding="utf-8")) if fichero.exists() else {"frases": {}}
    indice["base"] = base
    indice["frases"].update(hechas)
    indice["frases"] = {k: v for k, v in sorted(indice["frases"].items())
                        if (out / "wet" / f"{k}.ogg").exists() and (out / "dry" / f"{k}.ogg").exists()}
    fichero.write_text(json.dumps(indice, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return fichero


def copia_a_godot(cfg, godot_dir, hechas):
    """Copia las frases de esta ejecución (solo wet) a <proyecto>/<godot.res_dir>/<id>.ogg y
    mezcla su entrada en el megafonia_index.json de allí: {clave: {file, seconds, tags}}."""
    g = cfg["godot"]
    proyecto = Path(godot_dir).expanduser().resolve()
    if not (proyecto / "project.godot").exists():
        raise SystemExit(f"{proyecto} no es un proyecto de Godot (no hay project.godot)")
    dest = proyecto / g["res_dir"]
    dest.mkdir(parents=True, exist_ok=True)
    fichero = dest / "megafonia_index.json"
    indice = json.loads(fichero.read_text(encoding="utf-8")) if fichero.exists() else {}
    base = "res://" + g["res_dir"].strip("/")
    for nombre, h in hechas.items():
        shutil.copy2(ruta(cfg, "out") / "wet" / f"{nombre}.ogg", dest / f"{nombre}.ogg")
        indice[h.get("clave") or nombre] = {"file": f"{base}/{nombre}.ogg", "seconds": h["duracion"],
                                            "tags": h["tags"]}
    indice = {k: v for k, v in sorted(indice.items()) if (proyecto / v["file"][6:]).exists()}
    fichero.write_text(json.dumps(indice, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Copiadas {len(hechas)} frases a {dest} (índice con {len(indice)})")


def build(cfg, args):
    t, e = cfg["tts"], cfg["export"]
    filas = lee_frases_juego(cfg) if args.desde_juego else lee_frases(cfg)
    cola = cfg["juego"].get("tail_silence") if args.desde_juego else None
    if args.only:
        filas = [r for r in filas if r["id"] in args.only]
        if not filas:
            raise SystemExit(f"No hay frases con id {args.only}")
    if args.limit:
        filas = filas[: args.limit]
    filas = aplica_sonidos_por_frase(cfg, filas)
    out = ruta(cfg, "out")
    base = "res://" + cfg["godot"]["res_dir"].strip("/")
    hechas = {}
    for r in filas:
        voz = r.get("voz") or t["default_voice"]
        vel = float(r.get("velocidad") or t["default_speed"])
        preset = args.preset or r.get("preset") or "sala"
        if preset not in cfg["presets"]:
            raise SystemExit(f"{r['id']}: no existe el preset «{preset}»")
        for k in range(args.takes):
            # tomas: Kokoro es determinista, así que cada toma varía un poco la velocidad (±3 %)
            v = vel * (1 + 0.03 * (k - (args.takes - 1) / 2)) if args.takes > 1 else vel
            nombre = r["id"] if args.takes == 1 else f"{r['id']}_t{k + 1}"
            a, sr = locucion(cfg, r["texto"], voz, round(v, 3), preset, args.force)
            for modo in ("dry", "wet"):
                y = procesa(cfg, a, sr, preset, modo == "wet", si(r.get("chime", "")), cola=cola)
                export.guarda_ogg(out / modo / f"{nombre}.ogg", y, e["sample_rate"], e["ogg_compression"])
            hechas[nombre] = {"ruta": f"{base}/wet/{nombre}.ogg", "ruta_dry": f"{base}/dry/{nombre}.ogg",
                              "duracion": round(duracion(out / "wet" / f"{nombre}.ogg"), 3),
                              "preset": preset, "texto": r["texto"], "tags": r["tags"],
                              **({"clave": r["clave"]} if r.get("clave") else {})}
            print(f"  {nombre}: {preset}, {voz}, {v:.2f}" + (f"  {r['tags']}" if r["tags"] else ""), flush=True)
    indice = escribe_indice(cfg, hechas)
    print(f"{len(filas)} frases, {llamadas_tts} llamadas al TTS. Índice: {indice.relative_to(cfg['_raiz'])}")
    if args.godot_dir:
        copia_a_godot(cfg, args.godot_dir, hechas)


def preview(cfg, args):
    ogg = ruta(cfg, "out") / args.modo / f"{args.id}.ogg"
    if not ogg.exists():
        raise SystemExit(f"No existe {ogg}: genera antes con --only {args.id}")
    # afplay no lee ogg: se pasa a wav temporal
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(ogg), tmp.name], check=True)
        subprocess.run(["afplay", tmp.name], check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=str(RAIZ / "config.yaml"))
    ap.add_argument("--only", nargs="+", help="ids a generar")
    ap.add_argument("--preset", help="preset para todas las frases (ignora la columna)")
    ap.add_argument("--force", action="store_true", help="regenera el TTS aunque esté en caché")
    ap.add_argument("--takes", type=int, default=1, help="tomas por frase (<id>_t1, _t2...)")
    ap.add_argument("--desde-juego", action="store_true",
                    help="lee las frases MEGA_* del CSV de textos del juego en vez de frases.csv")
    ap.add_argument("--limit", type=int, help="procesa solo las N primeras frases")
    ap.add_argument("--godot-dir", help="proyecto de Godot (carpeta con project.godot): copia la versión wet "
                                       "de estas frases a <proyecto>/<godot.res_dir>/ y su índice")
    sub = ap.add_subparsers(dest="cmd")
    p = sub.add_parser("preview", help="reproduce una frase ya generada con afplay")
    p.add_argument("id")
    p.add_argument("--modo", choices=["wet", "dry"], default="wet")
    args = ap.parse_args()
    cfg = carga_config(args.config)
    if args.cmd == "preview":
        preview(cfg, args)
    else:
        build(cfg, args)


if __name__ == "__main__":
    main()
