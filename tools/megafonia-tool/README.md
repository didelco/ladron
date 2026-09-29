# Megafonía de museo

Convierte frases en avisos de megafonía de museo para Ninja Karma, todo en local:
TTS (Kokoro-82M con mlx-audio; Piper como plan B) → cadena de «bocina en sala grande»
(pedalboard) → -16 LUFS → `.ogg` mono a 44.1 kHz, en versión `dry` y `wet`.

Estado: fases 1–5 hechas. Decidido a oído: voz `em_santa`, preset `sala` con la IR del hangar al 30 %,
bocina actual (paso bajo 3500 Hz, drive 5 dB), velocidad 0.9 sin guasa forzada, y sonidos grabados
(risa, suspiro, ejem, tos; el carraspeo no se usa). Las frases del juego están en `audio/megafonia/`
del proyecto (se regeneran con `./regenerar_juego.sh`).

La carpeta lleva un `.gdignore`: vive dentro del proyecto de Godot y, sin él, el editor
importaría los wav, la caché, el venv y hasta `frases.csv` (como traducción).

## Instalación (macOS, Apple Silicon)

```sh
brew install ffmpeg sox espeak-ng     # espeak-ng: G2P del español de Kokoro
cd tools/megafonia-tool
uv venv --python 3.12 .venv           # o: python3.12 -m venv .venv (mlx-audio pide 3.10+)
uv pip install --python .venv/bin/python -r requirements.txt
.venv/bin/python src/descarga_ir.py   # baja y prepara las respuestas de impulso en ir/
.venv/bin/python src/prepara_vocales.py  # (re)hace assets/vocales/ desde Commons (ya van en el repo)
```

El modelo de Kokoro (`mlx-community/Kokoro-82M-bf16`) se descarga solo la primera vez
(caché de Hugging Face). Para Piper, los modelos van en `models/piper/`:

```sh
mkdir -p models/piper && cd models/piper
B=https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES
curl -LO $B/davefx/medium/es_ES-davefx-medium.onnx -LO $B/davefx/medium/es_ES-davefx-medium.onnx.json
```

## Uso

```sh
.venv/bin/python src/build.py                    # todas las frases de frases.csv
.venv/bin/python src/build.py --only cierre_15   # solo esas ids
.venv/bin/python src/build.py --preset pasillo   # un preset para todas
.venv/bin/python src/build.py --force            # regenera también el TTS
.venv/bin/python src/build.py --takes 3          # 3 tomas (velocidad ±3 %: Kokoro es determinista)
.venv/bin/python src/build.py preview cierre_15  # escucha out/wet/cierre_15.ogg (afplay)
.venv/bin/python src/build.py --desde-juego --limit 5   # frases MEGA_* del juego (ver abajo)
.venv/bin/python src/analiza.py out/wet/*.ogg    # duración, LUFS, pico, banda...
.venv/bin/python src/pruebas_fase2b.py           # pruebas A/B en samples/fase2b/ (+ todo_en_orden)
.venv/bin/python src/pruebas_risa_definitivos.py # risa original/limpia y un clip por sonido
```

Salida: `out/dry/<id>.ogg` (EQ + compresión + saturación; para añadir la reverb en Godot)
y `out/wet/<id>.ogg` (cadena completa), más `out/megafonia_index.json` (por id: rutas, duración,
preset, texto y sonidos). La caché (`cache/<hash>.wav`) guarda el audio seco del TTS
por hash de texto normalizado + voz + velocidad + modelo: tocar efectos no vuelve a llamar al TTS
(la última línea dice cuántas llamadas hubo).

## Frases (`frases.csv`)

```csv
id,texto,preset,voz,velocidad,chime
cierre_15,"Atención, por favor. El museo cerrará sus puertas en 15 minutos.",sala,em_santa,0.9,true
```

- `voz`: `ef_dora`, `em_alex`, `em_santa` (Kokoro) o `piper:es_ES-davefx-medium` (Piper).
- `velocidad`: 0.9 por defecto (más pausado). Las comas y los puntos hacen pausa.
- Los números y horas se pasan a letra antes del TTS: `15` → «quince», `21:30` → «nueve y media».
- `chime`: `true` pone un ding-dong antes (sintetizado en `assets/chime.wav`); el preset `alarma` nunca lo lleva.

## Sonidos: risa, suspiro, ejem, tos

Etiquetas en el texto (`[risa]`, `[suspiro]`, `[ejem]`, `[tos]`, y `[carraspeo]`, que no está aprobado).
Se insertan en ese punto con pausa antes y después (`vocales.pausa_antes/pausa_despues`), al nivel de
la voz (+ `gain_db`), y pasan por la misma cadena, así que suenan en la misma sala. Solo suenan si
`vocales.activas: true` y el sonido está en `vocales.permitidas`; las demás etiquetas se quitan sin sonar.
Son muestras grabadas (`assets/vocales/*.wav`, dominio público: ver `assets/LICENCIAS_vocales.md`;
`prepara_vocales.py` las recorta y a la risa además le quita barro y ruido de fondo).

Qué frase lleva qué sonido va en **`vocales_por_frase.yaml`**, por id (`mega_start_05: {suspiro: 1}`:
`inicio`, `final` o N = tras la frase N), así no se toca `locale/texts.csv`. También se pueden escribir
las etiquetas directamente en el texto de `frases.csv`.

Cuándo usar cada uno:
- **risa**: solo como remate de un chiste muy vacilón, al final. Como mucho 1 de cada 10 frases
  (`vocales.max_por_lote.risa` avisa si un lote se pasa). Es la más cargante: mejor quedarse corto.
- **suspiro**: cansancio del locutor ante lo de siempre («Como siempre.», «Otra vez.»), entre dos frases.
- **ejem**: arranque formal falso, o para disimular un desliz («Muy buen escondite. [ejem] Digo, decoración.»).
- **tos**: después de algo incómodo, o de polvo y humo.
## Presets (`config.yaml`)

Todos los valores están en `config.yaml`. Cadena (`src/fx.py`), en este orden:

1. paso alto / paso bajo (filtros de 6 dB/oct apilados `filter_stages` veces)
2. realce (`peak`) hacia 1.8 kHz
3. compresor
4. saturación (`drive_db`, sobre un nivel de trabajo fijo `level_db`), y otra vez la banda
5. delay · 6. reverb por convolución (`reverb.ir` = nombre en `ir/`, `wet`) · 7. ruido (hiss + 50 Hz)
8. limitador con techo `limiter_db` (se aplica tras la normalización LUFS, en `export.py`)

`dry` hace 1–4 y 8. Para un preset nuevo, copia uno en `presets:` y cambia lo que haga falta.

## Respuestas de impulso (`ir/`)

`src/descarga_ir.py` las baja (listadas en `ir_sources` de `config.yaml`) y las prepara:
canal omni, 44.1 kHz, sin silencio inicial, fundido final, pico a -1 dBFS. Los `.wav` no se suben al repo.

| ir | origen | licencia |
|---|---|---|
| `vestibulo` | EchoThief, *Littlefield Lobby* (T20 ≈ 3.0 s) | EchoThief: uso libre para obra derivada (convolucionar para hacer reverb); otros usos, preguntar al autor (Chris Warren). No redistribuir la IR suelta. |
| `pabellon` | EchoThief, *Pabellón Cultural de la República* (T20 ≈ 2.4 s) | ídem |
| `pasillo` | EchoThief, *Graffiti Hallway* (T20 ≈ 2.2 s) | ídem |
| `hangar_museo` | OpenAIR, *Yorkshire Air Museum*, hangar T2 (B-format, canal W) | CC BY 4.0 según el catálogo de OpenAIR (York Research Database); la ficha de la IR no lo repite, confirmar antes de publicar. Citar «OpenAIR, University of York». |
| `central_hall` | OpenAIR, *Central Hall, University of York* | ídem |

El servidor de OpenAIR va muy lento (KB/s); el script reanuda la descarga.

## Frases del juego e integración con Godot

```sh
./regenerar_juego.sh      # = .venv/bin/python src/build.py --desde-juego --godot-dir ../..
```

- `--desde-juego` lee las claves que usa el juego (los `POOLS` de `logic/megaphone.gd`) con su texto de
  `locale/texts.csv` (columna `es`). El id es la clave en minúsculas (`MEGA_ACT_ROLL_WALL_10` →
  `mega_act_roll_wall_10`). Preset `sala` (las `MEGA_ALARM_*` usan `alarma`), sin chime y con cola de
  0.9 s (sección `juego:` de `config.yaml`). Las frases con `%s` (el nombre de la pieza se pone al jugar)
  se saltan: hoy son MEGA_PIECE_01, 02, 04 y 06. Avisa si el juego usa claves que no están en el CSV.
- `--godot-dir <proyecto>` copia la versión wet de las frases de esa ejecución a
  `<proyecto>/audio/megafonia/<id>.ogg` (no copia la dry) y mezcla su entrada en
  `audio/megafonia/megafonia_index.json`: `{"MEGA_...": {"file": "res://audio/megafonia/<id>.ogg",
  "seconds": 3.4, "tags": ["risa"]}}`.
- Si cambian las frases, basta con volver a lanzar `./regenerar_juego.sh`: solo se llama al TTS para
  las nuevas o cambiadas.
- `godot_example/megafonia_player.gd` es un ejemplo de reproductor por id (cola de avisos, versión wet
  o dry con un bus «Megafonia» con `AudioEffectReverb` y delay creados en `_ready`). Lee tanto el índice
  del juego (`file`, solo wet) como el de `out/` (`ruta`/`ruta_dry`). No se ha probado en Godot.
