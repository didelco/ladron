"""Pruebas A/B de la fase 2b -> samples/fase2b/ (+ LEEME.txt y todo_en_orden.wav/.m4a).

Voz em_santa, preset sala con la IR del hangar; cada bloque cambia solo lo que compara.
Uso: python src/pruebas_fase2b.py
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from num2words import num2words

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402
import export  # noqa: E402

PARED = "Hay quien usa la cabeza para hacer agujeros en la pared."
CIERRE = "Atención, por favor. El museo cerrará sus puertas en quince minutos."
CIERRE_GUASA = "Atención... por favor. El museo... cerrará sus puertas, en quince minutos. Otra vez."

# (fichero, texto, velocidad, ajustes del preset, chime, qué es)
CLIPS = [
    ("01_bocina_A_actual", PARED, 0.9, {}, False,
     "Bocina actual: paso bajo 3500 Hz, drive 5 dB."),
    ("01_bocina_B_suave", PARED, 0.9, {"drive_db": 2.0}, False,
     "Menos saturación: paso bajo 3500 Hz, drive 2 dB."),
    ("01_bocina_C_mas_abierta", PARED, 0.9, {"lowpass_hz": 4000}, False,
     "Más agudos: paso bajo 4000 Hz, drive 5 dB."),
    ("01_bocina_D_abierta_y_suave", PARED, 0.9, {"lowpass_hz": 4500, "drive_db": 2.0}, False,
     "Lo más limpio: paso bajo 4500 Hz, drive 2 dB."),
    ("01_bocina_E_mas_sucia", PARED, 0.9, {"drive_db": 10.0}, False,
     "Contraste: drive 10 dB (paso bajo 3500 Hz), para oír qué hace la saturación; "
     "entre 2 y 5 dB apenas cambia nada."),
    ("02_reverb_A_hangar_030", PARED, 0.9, {"reverb": {"ir": "hangar_museo", "wet": 0.30}}, False,
     "Reverb actual: hangar al 30 %."),
    ("02_reverb_B_hangar_040", PARED, 0.9, {"reverb": {"ir": "hangar_museo", "wet": 0.40}}, False,
     "Hangar al 40 %."),
    ("02_reverb_C_hangar_055", PARED, 0.9, {"reverb": {"ir": "hangar_museo", "wet": 0.55}}, False,
     "Hangar al 55 % (mucha sala)."),
    ("02_reverb_D_vestibulo_040", PARED, 0.9, {"reverb": {"ir": "vestibulo", "wet": 0.40}}, False,
     "Vestíbulo al 40 % (cola más larga y oscura), por comparar."),
]
SONIDOS = [
    ("a_carraspeo", "[carraspeo] Atención, por favor. Se ruega no pisar la moqueta sospechosa."),
    ("b_risa", PARED + " [risa]"),
    ("c_suspiro", "Ese pitido no es un pájaro. [suspiro] Es la alarma."),
    ("d_ejem", "[ejem] Buenas noches. Los cuadros duermen: no los despierten."),
    ("e_tos", "Aviso: el mamut estornuda cuando le tosen. [tos]"),
]
for n, t in SONIDOS:
    CLIPS.append((f"03_sonidos_{n}_1_muestra", t, 0.9, {"_modo": "muestra"}, False,
                  "Sonido grabado (muestra de dominio público) en la misma cadena."))
    CLIPS.append((f"03_sonidos_{n}_2_tts", t, 0.9, {"_modo": "tts"}, False,
                  "El mismo sonido dicho por la voz (TTS)."))
CLIPS += [
    ("04_tono_A_normal_090", CIERRE, 0.9, {}, False, "Frase de cierre normal, velocidad 0.9 (la actual)."),
    ("04_tono_B_guasa_090", CIERRE_GUASA, 0.9, {}, False, "Con puntuación de guasa, velocidad 0.9."),
    ("04_tono_C_guasa_080", CIERRE_GUASA, 0.8, {}, False, "Con guasa, velocidad 0.8 (más cansado)."),
    ("04_tono_D_guasa_100", CIERRE_GUASA, 1.0, {}, False, "Con guasa, velocidad 1.0."),
    ("05_cierre_completo", "Atención, por favor. El museo cerrará sus puertas en 15 minutos.", 0.9, {}, True,
     "Referencia: la frase de cierre tal como saldría hoy del pipeline, con ding-dong."),
]


def main():
    cfg = build.carga_config(Path(__file__).resolve().parent.parent / "config.yaml")
    e = cfg["export"]
    sr = e["sample_rate"]
    voz = cfg["tts"]["default_voice"]
    dest = build.ruta(cfg, "samples") / "fase2b"
    dest.mkdir(parents=True, exist_ok=True)
    sala = cfg["presets"]["sala"]
    leeme = [
        "PRUEBAS DE MEGAFONÍA (fase 2b)",
        "",
        f"Voz {voz}, preset «sala» con la IR del hangar del museo, salvo lo que cambie cada prueba.",
        f"Base del preset: paso alto {sala['highpass_hz']} Hz, paso bajo {sala['lowpass_hz']} Hz, "
        f"realce {sala['peak']['gain_db']:+} dB en {sala['peak']['freq_hz']} Hz, compresor "
        f"{sala['compressor']['ratio']}:1, drive {sala['drive_db']} dB, delay {sala['delay']['seconds']} s "
        f"al {sala['delay']['mix']:.0%}, reverb {sala['reverb']['ir']} al {sala['reverb']['wet']:.0%}.",
        f"Todos normalizados a {e['lufs']} LUFS, pico por debajo de {sala['limiter_db']} dBFS, mono 44.1 kHz.",
        "todo_en_orden.wav (y .m4a) lleva todas seguidas: la voz dice «Prueba N» (sin efectos) y suena el clip.",
        "",
        "Qué comparar:",
        "  01 bocina: ¿cuál suena a megafonía sin sonar a walkie-talkie?",
        "  02 reverb: ¿cuánta sala? (A es lo actual)",
        "  03 sonidos: cada frase dos veces; 1 = sonido grabado, 2 = dicho por la voz. ¿Cuál queda mejor?",
        "  04 tono: ¿cuál suena más a locutor cansado que vacila?",
        "  05 referencia de cómo sale hoy una frase entera.",
        "",
    ]
    todo = []
    for i, (nombre, texto, vel, ajustes, con_chime, que) in enumerate(CLIPS, 1):
        ajustes = dict(ajustes)
        modo = ajustes.pop("_modo", None)
        a, sra = build.locucion(cfg, texto, voz, vel, "sala", modo=modo)
        y = build.procesa(cfg, a, sra, "sala", True, con_chime, ajustes=ajustes)
        fichero = f"{nombre}.wav"
        export.guarda_wav(dest / fichero, y, sr)
        leeme.append(f"Prueba {i:2d}  {fichero}")
        leeme.append(f"           {que}")
        leeme.append(f"           Texto: «{texto}»  velocidad {vel}"
                     + (f"  cambios: {ajustes}" if ajustes else "") + (f"  sonidos: {modo}" if modo else ""))
        # aviso hablado sin efectos, algo más bajo que las pruebas
        av, sav = build.voz_seca(cfg, f"Prueba {num2words(i, lang='es')}.", voz, 1.0)
        av = export.normaliza_lufs(build.fx.remuestrea(av, sav, sr), sr, e["lufs"] - 4, -1.5)
        todo += [av, np.zeros(int(0.6 * sr), np.float32), y, np.zeros(int(1.0 * sr), np.float32)]
        print(f"{i:2d} {fichero}")
    export.guarda_wav(dest / "todo_en_orden.wav", np.concatenate(todo), sr)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(dest / "todo_en_orden.wav"),
                    "-c:a", "aac", "-b:a", "160k", str(dest / "todo_en_orden.m4a")], check=True)
    leeme += ["", f"Generado con: python src/pruebas_fase2b.py ({build.llamadas_tts} llamadas al TTS)."]
    (dest / "LEEME.txt").write_text("\n".join(leeme) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
