#!/usr/bin/env python3
"""La versión del juego: 0.1.N, donde N es el número de commits de la rama.

    python3 tools/version.py          # escribe en project.godot la del commit que viene (N + 1)
    python3 tools/version.py --show   # la que hay ahora en project.godot

El hook .githooks/pre-commit la escribe antes de cada commit, así que cada commit
lleva la suya. Para activarlo en un clon: git config core.hooksPath .githooks
Para subir de 0.1 a 0.2, se cambia BASE.
"""
import re
import subprocess
import sys
from pathlib import Path

BASE = "0.1"
ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"


def current() -> str:
    m = re.search(r'^config/version="([^"]*)"', PROJECT.read_text(), re.M)
    return m.group(1) if m else ""


def next_version() -> str:
    count = int(subprocess.run(["git", "rev-list", "--count", "HEAD"], cwd=ROOT,
                               capture_output=True, text=True, check=True).stdout.strip())
    return f"{BASE}.{count + 1}"


def write(version: str) -> None:
    text = PROJECT.read_text()
    line = f'config/version="{version}"'
    if re.search(r'^config/version=', text, re.M):
        text = re.sub(r'^config/version=.*$', line, text, flags=re.M)
    else:
        text = text.replace('config/name=', line + '\nconfig/name=', 1)
    PROJECT.write_text(text)


if __name__ == "__main__":
    if "--show" in sys.argv:
        print(current())
    else:
        v = next_version()
        if v != current():
            write(v)
        print(v)
