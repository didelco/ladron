"""Análisis objetivo de audios: duración, LUFS, pico, clipping, silencio y ancho de banda.

Uso: python src/analiza.py fichero.wav|.ogg [...]
"""
import subprocess
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf


def carga(ruta):
    try:
        a, sr = sf.read(ruta, dtype="float32", always_2d=True)
    except Exception:  # ogg que libsndfile no lea: pasar por ffmpeg
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", ruta, "-f", "f32le", "-ac", "1", "-"],
                             capture_output=True, check=True).stdout
        sr = int(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=sample_rate",
                                 "-of", "csv=p=0", ruta], capture_output=True, text=True).stdout.split()[0])
        return np.frombuffer(raw, np.float32), sr
    return a.mean(axis=1), sr


def banda(a, sr, fraccion=0.99):
    """Frecuencias entre las que cae el 1 %–99 % de la energía del espectro."""
    spec = np.abs(np.fft.rfft(a)) ** 2
    f = np.fft.rfftfreq(len(a), 1 / sr)
    c = np.cumsum(spec) / spec.sum()
    lo = f[np.searchsorted(c, (1 - fraccion))]
    hi = f[np.searchsorted(c, fraccion)]
    return lo, hi


def informe(ruta):
    a, sr = carga(ruta)
    dur = len(a) / sr
    pico = 20 * np.log10(np.abs(a).max() + 1e-12)
    clip = int((np.abs(a) >= 0.999).sum())
    lufs = pyln.Meter(sr).integrated_loudness(a) if dur > 0.5 else float("nan")
    # silencio: fracción de ventanas de 50 ms por debajo de -50 dBFS
    w = int(0.05 * sr)
    rms = np.sqrt(np.mean(a[: len(a) // w * w].reshape(-1, w) ** 2, axis=1) + 1e-12)
    voz = float((20 * np.log10(rms) > -50).mean())
    lo, hi = banda(a, sr)
    return (f"{ruta}\n  {dur:5.2f} s  {sr} Hz  {lufs:6.1f} LUFS  pico {pico:5.1f} dBFS  "
            f"muestras≥0dB {clip}  con señal {voz:4.0%}  banda 1–99 % {lo:.0f}–{hi:.0f} Hz")


if __name__ == "__main__":
    for r in sys.argv[1:]:
        print(informe(r))
