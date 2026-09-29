"""Normalización LUFS, techo de pico y exportación (wav / ogg)."""
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf


def normaliza_lufs(audio, sr, lufs, techo_db=-1.0):
    """Lleva a `lufs` integrados y pone techo de pico con el limitador (paso 8 de la cadena)."""
    import fx
    medidor = pyln.Meter(sr)
    y = audio
    for _ in range(3):  # limitar baja un poco la sonoridad: se reajusta un par de veces
        y = fx.limita(y * 10 ** ((lufs - medidor.integrated_loudness(y)) / 20), sr, techo_db)
    return y


def guarda_wav(ruta, audio, sr):
    Path(ruta).parent.mkdir(parents=True, exist_ok=True)
    sf.write(ruta, audio, sr, subtype="PCM_16")


def guarda_ogg(ruta, audio, sr, compresion):
    """Ogg Vorbis con libsndfile (el ffmpeg de Homebrew viene sin libvorbis).
    compresion: 0 = máxima calidad, 1 = fichero más pequeño."""
    Path(ruta).parent.mkdir(parents=True, exist_ok=True)
    sf.write(ruta, audio, sr, format="OGG", subtype="VORBIS", compression_level=compresion)
