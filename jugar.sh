#!/usr/bin/env bash
# Lanza el juego tal como lo jugaría cualquiera: sin las variables SDL que
# usan los tests y las capturas (ver CLAUDE.md) — con ellas puestas, un
# mando real no se detecta.
#
# Uso:     ./jugar.sh
# Variable: GODOT (ruta de Godot, por defecto la app de macOS)

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "No encuentro Godot en '$GODOT'. Pon la ruta en la variable GODOT." >&2
	exit 2
fi

exec "$GODOT" --path "$ROOT" scenes/main.tscn
