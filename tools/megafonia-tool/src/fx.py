"""Cadenas de efectos por preset (pedalboard). Todos los valores vienen de config.yaml."""
import numpy as np
from pedalboard import (Compressor, Convolution, Delay, Distortion, HighpassFilter,
                        LowpassFilter, PeakFilter, Pedalboard)
from pedalboard.io import StreamResampler


def _db(x):
    return 10 ** (x / 20)


def remuestrea(audio, sr_in, sr_out):
    """Cambio real de frecuencia de muestreo (ojo: pedalboard.Resample es un efecto lo-fi, no esto)."""
    if sr_in == sr_out:
        return audio.astype(np.float32)
    r = StreamResampler(sr_in, sr_out, 1)
    x = audio.astype(np.float32).reshape(1, -1)
    return np.concatenate([r.process(x), r.process(None)], axis=1)[0]


def _filtros(p):
    # Los filtros de pedalboard son de 1er orden (6 dB/oct): se apilan para cortar más.
    n = p.get("filter_stages", 1)
    return ([HighpassFilter(cutoff_frequency_hz=p["highpass_hz"]) for _ in range(n)] +
            [LowpassFilter(cutoff_frequency_hz=p["lowpass_hz"]) for _ in range(n)])


def _pico(x, db):
    """Lleva el pico a `db` dBFS (así el drive y el ruido no dependen del nivel de la voz)."""
    return (x * (_db(db) / (np.abs(x).max() + 1e-12))).astype(np.float32)


def _ruido(n, sr, p, seed=0):
    """Hiss filtrado + zumbido de red (fundamental y dos armónicos), en dBFS RMS.
    La voz llega aquí con el pico a `level_db`, así que el nivel relativo no depende de la frase."""
    r = p["noise"]
    rng = np.random.default_rng(seed)
    lo, hi = r["hiss_band_hz"]
    hiss = Pedalboard([HighpassFilter(lo), HighpassFilter(lo), LowpassFilter(hi), LowpassFilter(hi)])(
        rng.standard_normal(n).astype(np.float32), sr)
    hiss *= _db(r["hiss_db"]) / (np.sqrt(np.mean(hiss ** 2)) + 1e-12)
    t = np.arange(n) / sr
    f = r["hum_hz"]
    hum = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * 2 * f * t) + 0.25 * np.sin(2 * np.pi * 3 * f * t)
    hum *= _db(r["hum_db"]) / np.sqrt(np.mean(hum ** 2))
    return (hiss + hum).astype(np.float32)


def aplica(audio, sr, p, wet=True, ir=None, cola=0.0):
    """audio mono float32 -> audio procesado. wet=False: sin delay, reverb ni ruido.
    `ir` es la ruta del .wav de la respuesta de impulso."""
    nivel = p.get("level_db", -6.0)
    c = p["compressor"]
    x = np.concatenate([_pico(audio, nivel), np.zeros(int(cola * sr), np.float32)])
    # 1-3: banda de bocina, realce y compresor
    y = Pedalboard(_filtros(p) + [
        PeakFilter(cutoff_frequency_hz=p["peak"]["freq_hz"], gain_db=p["peak"]["gain_db"], q=p["peak"]["q"]),
        Compressor(threshold_db=c["threshold_db"], ratio=c["ratio"],
                   attack_ms=c["attack_ms"], release_ms=c["release_ms"]),
    ])(x, sr)
    # 4: saturación sobre un nivel fijo; luego otra vez la banda (la saturación crea armónicos altos)
    y = Pedalboard([Distortion(drive_db=p["drive_db"]), *_filtros(p)])(_pico(y, nivel), sr)
    y = _pico(y, nivel)
    if wet:
        d, rv = p["delay"], p["reverb"]
        # 5-6: delay y reverb por convolución
        y = Pedalboard([
            Delay(delay_seconds=d["seconds"], feedback=d["feedback"], mix=d["mix"]),
            Convolution(ir or rv["ir"], mix=rv["wet"]),
        ])(y, sr)
        y = _pico(y, nivel)
        # 7: ruido de fondo
        y = y + _ruido(len(y), sr, p)
    # 8: el limitador (-1 dB) va en export.normaliza_lufs, después de la ganancia de LUFS:
    # aquí se desharía al normalizar.
    return y.astype(np.float32)


def limita(x, sr, techo_db=-1.0, ventana_ms=5.0):
    """Limitador de picos con anticipación: la ganancia baja antes del pico y se recupera suave.
    (El Limiter de pedalboard/JUCE añade ganancia de compensación; este solo pone techo.)"""
    from numpy.lib.stride_tricks import sliding_window_view
    techo = _db(techo_db)
    w = max(1, int(ventana_ms * sr / 1000))
    g = np.minimum(1.0, techo / (np.abs(x) + 1e-12))
    g = np.pad(g, (w - 1, w - 1), constant_values=1.0)
    g = sliding_window_view(g, w).min(axis=1)             # anticipación: mínimo de la ventana
    g = np.convolve(g, np.ones(w) / w, mode="valid")      # suavizado (sin clics)
    return np.clip(x * g[: len(x)], -techo, techo).astype(np.float32)
