"""06: risa original vs limpia, y 07: un clip definitivo por sonido (frases del juego).

Todo con la configuración de config.yaml tal cual (como saldrá para el juego: sin chime, cola
de juego). Uso: python src/pruebas_risa_definitivos.py
"""
import copy
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402
import export  # noqa: E402

DEFINITIVOS = [  # (clave del juego, sonido)
    ("MEGA_ACT_ROLL_WALL_01", "risa"),
    ("MEGA_START_05", "suspiro"),
    ("MEGA_HIDE_03", "ejem"),
    ("MEGA_ACT_SNEEZE_AGAIN_05", "tos"),
]


def clip_juego(cfg, texto):
    """Igual que build.py --desde-juego: voz por defecto, sala, sin chime, cola de juego."""
    t = cfg["tts"]
    a, sr = build.locucion(cfg, texto, t["default_voice"], t["default_speed"], "sala")
    return build.procesa(cfg, a, sr, "sala", True, False, cola=cfg["juego"]["tail_silence"])


def aviso(cfg, texto):
    """Locutor sin efectos, algo más bajo que los clips."""
    e = cfg["export"]
    a, sr = build.voz_seca(cfg, texto, cfg["tts"]["default_voice"], 1.0)
    return export.normaliza_lufs(build.fx.remuestrea(a, sr, e["sample_rate"]), e["sample_rate"], e["lufs"] - 4, -1.5)


def seguido(cfg, partes):
    sr = cfg["export"]["sample_rate"]
    out = []
    for av, clip in partes:
        out += [av, np.zeros(int(0.6 * sr), np.float32), clip, np.zeros(int(1.0 * sr), np.float32)]
    return np.concatenate(out)


def main():
    cfg = build.carga_config(Path(__file__).resolve().parent.parent / "config.yaml")
    sr = cfg["export"]["sample_rate"]
    dest = build.ruta(cfg, "samples") / "fase2b"
    frase = "Hay quien usa la cabeza para hacer agujeros en la pared. [risa]"

    # 06: la misma frase con la risa original y con la limpia
    orig = copy.deepcopy(cfg)
    m = Path(cfg["vocales"]["tipos"]["risa"]["muestra"])
    orig["vocales"]["tipos"]["risa"]["muestra"] = str(m.with_name(m.stem + "_original.wav"))
    a_orig, a_limpia = clip_juego(orig, frase), clip_juego(cfg, frase)
    export.guarda_wav(dest / "06_risa_limpia_vs_original.wav",
                      seguido(cfg, [(aviso(cfg, "Original."), a_orig), (aviso(cfg, "Limpia."), a_limpia)]), sr)
    print("06_risa_limpia_vs_original.wav")

    # 07: un clip por sonido, tal como irá al juego (con vocales_por_frase.yaml)
    d7 = dest / "07_definitivos"
    filas = {r["clave"]: r for r in build.lee_frases_juego(cfg)}
    elegidas = build.aplica_sonidos_por_frase(cfg, [dict(filas[c]) for c, _ in DEFINITIVOS])
    partes = []
    for i, ((clave, sonido), r) in enumerate(zip(DEFINITIVOS, elegidas), 1):
        assert sonido in r["tags"], f"{clave} no lleva [{sonido}] en vocales_por_frase.yaml"
        y = clip_juego(cfg, r["texto"])
        nombre = f"{i}_{sonido}_{r['id']}.wav"
        export.guarda_wav(d7 / nombre, y, sr)
        partes.append((aviso(cfg, f"{sonido.capitalize()}."), y))
        print(f"07_definitivos/{nombre}: {r['texto']}")
    export.guarda_wav(d7 / "todo_en_orden.wav", seguido(cfg, partes), sr)


if __name__ == "__main__":
    main()
