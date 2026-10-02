#!/usr/bin/env bash
# Abre la documentación del juego, con los textos editables de verdad
# (tools/docs.py serve escribe en locale/texts.csv al vuelo).
#
# Uso:     ./documentacion.sh
# Variable: PORT (por defecto 8765, como tools/docs.py)

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8765}"

( sleep 1; open "http://localhost:${PORT}/" >/dev/null 2>&1 || true ) &
cd "$ROOT" && exec python3 tools/docs.py serve
