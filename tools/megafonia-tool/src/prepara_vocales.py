"""Baja y recorta las muestras de sonidos vocales (config.yaml: vocales_fuentes) en assets/vocales/.

Mono, 44.1 kHz, sin silencio en los bordes, fundidos cortos y pico a -1 dBFS.
Uso: python src/prepara_vocales.py [nombre ...]
"""
import subprocess
import sys
import urllib.parse
from pathlib import Path

import numpy as np
import soundfile as sf
import yaml

RAIZ = Path(__file__).resolve().parent.parent
UA = "megafonia-tool/0.1 (Ninja Karma; uso local)"  # Wikimedia pide un User-Agent propio
SR = 44100


def recorta_silencio(x, sr, umbral_db=-40, margen=0.03):
    """Quita el silencio de los bordes (umbral relativo al pico)."""
    w = int(0.01 * sr)
    r = np.sqrt(np.mean(x[: len(x) // w * w].reshape(-1, w) ** 2, axis=1))
    on = np.nonzero(20 * np.log10(r / (np.abs(x).max() + 1e-12) + 1e-12) > umbral_db)[0]
    if not len(on):
        return x
    m = int(margen * sr)
    return x[max(0, on[0] * w - m): min(len(x), (on[-1] + 1) * w + m)]


def limpia(x, sr, l):
    """Limpieza suave (config: vocales_fuentes.<nombre>.limpieza): quita barro y ruido de fondo."""
    from pedalboard import (HighpassFilter, HighShelfFilter, NoiseGate, PeakFilter, Pedalboard)
    cadena = [HighpassFilter(l["highpass_hz"]) for _ in range(l.get("highpass_etapas", 2))]
    cadena += [PeakFilter(cutoff_frequency_hz=f, gain_db=g, q=q) for f, g, q in l.get("peaks", [])]
    if "deesser" in l:  # de-esser sencillo: estante agudo hacia abajo
        cadena.append(HighShelfFilter(cutoff_frequency_hz=l["deesser"]["hz"], gain_db=l["deesser"]["gain_db"]))
    if "gate" in l:  # puerta de ruido: baja el fondo entre carcajadas
        g = l["gate"]
        pico = 20 * np.log10(np.abs(x).max() + 1e-12)
        cadena.append(NoiseGate(threshold_db=pico + g["umbral_rel_db"], ratio=g["ratio"],
                                attack_ms=g.get("attack_ms", 1.0), release_ms=g.get("release_ms", 80.0)))
    return Pedalboard(cadena)(x.astype(np.float32), sr)


def main(nombres):
    cfg = yaml.safe_load(open(RAIZ / "config.yaml", encoding="utf-8"))
    bajadas = RAIZ / "models" / "vocales_descargas"
    bajadas.mkdir(parents=True, exist_ok=True)
    for nombre, f in cfg["vocales_fuentes"].items():
        if nombres and nombre not in nombres:
            continue
        orig = bajadas / urllib.parse.unquote(Path(urllib.parse.urlparse(f["url"]).path).name)
        if not orig.exists():
            subprocess.run(["curl", "-sfL", "-A", UA, "-o", str(orig), f["url"]], check=True)
        # libsndfile no lee todos los ogg de Commons: se decodifica con ffmpeg
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(orig), "-ac", "1", "-ar", str(SR),
                              "-f", "f32le", "-"], capture_output=True, check=True).stdout
        x = np.frombuffer(raw, np.float32)[int(f["ini"] * SR): int(f["fin"] * SR)].copy()
        x = recorta_silencio(x, SR)
        dest = RAIZ / cfg["vocales"]["tipos"][nombre]["muestra"]
        if "limpieza" in f:  # se guarda también el recorte sin limpiar, para comparar
            orig_wav = dest.with_name(dest.stem + "_original.wav")
            o_ini, o_fin = (f.get("original") or {}).get("ini", f["ini"]), (f.get("original") or {}).get("fin", f["fin"])
            o = recorta_silencio(np.frombuffer(raw, np.float32)[int(o_ini * SR): int(o_fin * SR)].copy(), SR)
            o *= 10 ** (-1 / 20) / np.abs(o).max()
            orig_wav.parent.mkdir(parents=True, exist_ok=True)
            sf.write(orig_wav, o, SR, subtype="PCM_16")
            x = limpia(x, SR, f["limpieza"])
        n = int(0.01 * SR)
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
        x *= 10 ** (-1 / 20) / np.abs(x).max()
        dest.parent.mkdir(parents=True, exist_ok=True)
        sf.write(dest, x, SR, subtype="PCM_16")
        print(f"{nombre}: {len(x) / SR:.2f} s -> {dest.relative_to(RAIZ)}")


if __name__ == "__main__":
    main(sys.argv[1:])
