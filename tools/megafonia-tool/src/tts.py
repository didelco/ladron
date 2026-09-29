"""Wrapper del TTS (Kokoro-82M vía mlx-audio) y normalizador de números a letra."""
import hashlib
import re
import sys

import numpy as np
from num2words import num2words

_models = {}


# --- Texto -----------------------------------------------------------------

def _hora(m):
    h, mi = int(m.group(1)), int(m.group(2))
    h = h % 12 or 12  # como se dice en voz alta: «las nueve y media», no «veintiuna»
    horas = "una" if h == 1 else num2words(h, lang="es")
    if mi == 0:
        return f"{horas} en punto"
    if mi == 15:
        return f"{horas} y cuarto"
    if mi == 30:
        return f"{horas} y media"
    return f"{horas} y {num2words(mi, lang='es')}"


def normaliza(texto):
    """Pasa horas (21:30) y números (15, 3,5) a letra en español."""
    texto = re.sub(r"\b(\d{1,2}):(\d{2})\b", _hora, texto)
    texto = re.sub(r"\b(\d+),(\d+)\b",
                   lambda m: f"{num2words(int(m.group(1)), lang='es')} coma "
                             f"{num2words(int(m.group(2)), lang='es')}", texto)
    texto = re.sub(r"\d+", lambda m: num2words(int(m.group(0)), lang="es"), texto)
    return texto


def clave(texto, voz, velocidad, modelo):
    """Hash de la caché: si no cambia, el wav seco se reutiliza."""
    s = f"{normaliza(texto)}|{voz}|{float(velocidad):.3f}|{modelo}"
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]


# --- Síntesis --------------------------------------------------------------

def _modelo(repo):
    if repo not in _models:
        from mlx_audio.tts.utils import load_model
        _models[repo] = load_model(repo)
    return _models[repo]


def _piper(texto, voz, velocidad, cfg):
    """Plan B: Piper. voz = "piper:es_ES-davefx-medium" (modelo .onnx en tts.piper_dir)."""
    import subprocess
    import tempfile
    from pathlib import Path

    import soundfile as sf
    nombre = voz.split(":", 1)[1]
    modelo = Path(cfg["_raiz"]) / cfg["piper_dir"] / f"{nombre}.onnx"
    piper = Path(sys.executable).parent / "piper"
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        subprocess.run([str(piper), "-m", str(modelo), "-f", tmp.name,
                        "--length-scale", f"{1 / float(velocidad):.3f}"],
                       input=normaliza(texto).encode("utf-8"), check=True, capture_output=True)
        a, sr = sf.read(tmp.name, dtype="float32")
    return a, sr


def sintetiza(texto, voz, velocidad, cfg):
    """Devuelve (audio float32 mono, sample_rate). Voces de Kokoro (ef_dora...) o "piper:<modelo>"."""
    if voz.startswith("piper:"):
        return _piper(texto, voz, velocidad, cfg)
    model = _modelo(cfg["model"])
    # El G2P español (espeak) no trocea: una frase por línea para no truncar.
    lineas = re.sub(r"([.!?…])\s+", r"\1\n", normaliza(texto).strip())
    trozos = []
    for r in model.generate(text=lineas, voice=voz, speed=float(velocidad),
                            lang_code=cfg["lang_code"]):
        trozos.append(np.asarray(r.audio, dtype=np.float32).reshape(-1))
    return np.concatenate(trozos), model.sample_rate
