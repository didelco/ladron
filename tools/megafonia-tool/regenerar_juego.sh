#!/bin/sh
# Regenera la megafonía del juego: todas las frases MEGA_* que usa logic/megaphone.gd (POOLS),
# leídas de locale/texts.csv, con los sonidos de vocales_por_frase.yaml, y las copia (versión wet)
# a audio/megafonia/ del proyecto con su megafonia_index.json.
# Solo se llama al TTS para las frases nuevas o cambiadas (caché en cache/).
# Uso: tools/megafonia-tool/regenerar_juego.sh   (desde cualquier sitio)
set -e
cd "$(dirname "$0")"
.venv/bin/python src/build.py --desde-juego --godot-dir ../.. "$@"
