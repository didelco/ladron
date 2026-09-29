"""Descarga las respuestas de impulso de config.yaml (ir_sources) y las deja listas en ir/.

Preparación: un canal (en B-format, W = omni), 44.1 kHz, sin silencio antes del directo,
fundido al final y pico a -1 dBFS. Uso: python src/descarga_ir.py [nombre ...]
"""
import io
import subprocess
import sys
import zipfile
from pathlib import Path

import numpy as np
import soundfile as sf
import yaml

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "src"))


def _baja(url, destino):
    if destino.exists():
        return
    destino.parent.mkdir(parents=True, exist_ok=True)
    print(f"  bajando {url}")
    # curl reanuda (-C -): el servidor de OpenAIR va muy lento a ratos
    for _ in range(40):
        r = subprocess.run(["curl", "-sL", "-C", "-", "--speed-limit", "200", "--speed-time", "30",
                            "-o", str(destino) + ".part", url])
        if r.returncode == 0:
            Path(str(destino) + ".part").rename(destino)
            return
    raise SystemExit(f"No se pudo bajar {url}")


def prepara(datos, sr_in, canal, sr_out, max_s, fade_s):
    x = datos[:, canal] if datos.ndim == 2 else datos
    x = x.astype(np.float32)
    if sr_in != sr_out:
        from fx import remuestrea
        x = remuestrea(x, sr_in, sr_out)
    ini = max(0, int(np.argmax(np.abs(x) > 0.1 * np.abs(x).max())) - int(0.002 * sr_out))
    x = x[ini: ini + int(max_s * sr_out)]
    n = min(len(x), int(fade_s * sr_out))
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x * (10 ** (-1 / 20) / np.abs(x).max())


def main(nombres):
    cfg = yaml.safe_load(open(RAIZ / "config.yaml"))
    ajustes = cfg["ir_prep"]
    descargas = RAIZ / "models" / "ir_descargas"
    for nombre, s in cfg["ir_sources"].items():
        if nombres and nombre not in nombres:
            continue
        print(nombre)
        bruto = descargas / Path(s["url"]).name
        _baja(s["url"], bruto)
        if "member" in s:
            with zipfile.ZipFile(bruto) as z:
                datos, sr = sf.read(io.BytesIO(z.read(s["member"])), always_2d=True)
        else:
            datos, sr = sf.read(bruto, always_2d=True)
        x = prepara(datos, sr, s.get("channel", 0), ajustes["sample_rate"],
                    s.get("max_seconds", ajustes["max_seconds"]), ajustes["fade_seconds"])
        sf.write(RAIZ / cfg["paths"]["ir"] / f"{nombre}.wav", x, ajustes["sample_rate"], subtype="PCM_24")
        print(f"  -> ir/{nombre}.wav ({len(x) / ajustes['sample_rate']:.2f} s)")


if __name__ == "__main__":
    main(sys.argv[1:])
