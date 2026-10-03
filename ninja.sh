#!/bin/sh
# Lanza Ninja Karma para jugar. Sin las variables SDL_JOYSTICK_IGNORE_DEVICES
# / SDL_GAMECONTROLLER_IGNORE_DEVICES: esas son solo para tests y capturas
# (ver CLAUDE.md); aquí haría falta el mando de verdad.
cd "$(dirname "$0")"
exec /Applications/Godot.app/Contents/MacOS/Godot --path . "$@"
