#!/usr/bin/env python3
"""Avisa cuando un .gd pasa de un limite blando de tamano.

Limites blandos (no rompen nada; sirven para no volver a tener un main.gd de 4.500 lineas):

  - 1.500 lineas por fichero
  - 80 lineas por funcion

Se leen los .gd de scenes/, logic/ y tools/ (con --tests, tambien los de tests/). Lo que ya
pasaba del limite cuando se puso el aviso esta en EXCEPCIONES, con el tamano de hoy: un fichero
o una funcion de la lista puede quedarse como esta, pero no crecer; y lo que no esta en la
lista no debe pasar del limite. Al partir uno, se baja o se quita su linea.

Uso:
  python3 tools/tamanos.py             lista lo que pasa del limite y dice que es nuevo
  python3 tools/tamanos.py -v          ademas, los 15 ficheros y las 15 funciones mas grandes
  python3 tools/tamanos.py --estricto  sale con 1 si hay algo nuevo o una excepcion que ha crecido
  python3 tools/tamanos.py --tests     incluye tests/
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CARPETAS = ["scenes", "logic", "tools"]

MAX_FICHERO = 1500
MAX_FUNCION = 80

# Ficheros que ya pasaban de MAX_FICHERO: ruta -> lineas de hoy (no deben crecer).
EXCEPCIONES_FICHERO = {
    "scenes/museum_building.gd": 2899,
    "scenes/hud.gd": 2704,
    "scenes/town_builder.gd": 2490,
    "scenes/map_editor.gd": 2002,
}

# Funciones que ya pasaban de MAX_FUNCION: "ruta:funcion" -> lineas de hoy (no deben crecer).
EXCEPCIONES_FUNCION = {
    "logic/sim.gd:step_guard": 253,
    "tools/capture_docs.gd:_shots": 216,
    "scenes/museum_building.gd:_antiquity": 213,
    "scenes/museum_building.gd:_middle_ages": 184,
    "scenes/map_editor.gd:_build": 171,
    "scenes/museum_building.gd:_nature": 160,
    "scenes/museum_building.gd:_prehistory": 151,
    "logic/museum.gd:_build_zones": 138,
    "scenes/hud.gd:_menu_item": 136,
    "logic/sim.gd:step_thief": 124,
    "logic/mapgen.gd:_open_doors": 122,
    "logic/den.gd:furniture": 120,
    "scenes/hud.gd:_ready": 109,
    "logic/heist.gd:plan_job": 101,
    "logic/heist.gd:step": 93,
    "scenes/end_pages.gd:mugshot": 92,
    "scenes/sfx.gd:_render_music": 90,
    "scenes/museum_building.gd:_hall": 88,
    "scenes/city_stage.gd:build": 88,
    "logic/props.gd:place": 88,
    "scenes/map_editor.gd:_draw_plan": 87,
    "scenes/hud.gd:_card": 85,
    "scenes/museum_building.gd:_contemporary": 81,
}

DECLARACION = re.compile(r"^(static\s+func|func|var|const|signal|class|enum|@\w+|static\s+var)\b")


def funciones(lineas: list[str]) -> list[tuple[str, int, int]]:
    """(nombre, linea de inicio 1-based, largo) de cada func de primer nivel.

    El largo cuenta desde `func` hasta la ultima linea con algo del cuerpo (sin los
    comentarios de documentacion de la siguiente ni las lineas en blanco de detras)."""
    salida = []
    n = len(lineas)
    i = 0
    while i < n:
        m = re.match(r"^(?:static\s+)?func\s+(\w+)", lineas[i])
        if not m:
            i += 1
            continue
        fin = i
        j = i + 1
        while j < n:
            l = lineas[j]
            if l.strip() == "":
                j += 1
                continue
            if l[0] not in " \t" and not l.startswith((")", "]", "}")):
                break
            fin = j
            j += 1
        salida.append((m.group(1), i + 1, fin - i + 1))
        i = max(j, i + 1)
    return salida


def ficheros(con_tests: bool) -> list[Path]:
    carpetas = CARPETAS + (["tests"] if con_tests else [])
    out = []
    for c in carpetas:
        out.extend(sorted((RAIZ / c).rglob("*.gd")))
    return out


def main() -> int:
    args = sys.argv[1:]
    detalle = "-v" in args
    estricto = "--estricto" in args
    rutas = ficheros("--tests" in args)

    grandes = []  # (lineas, ruta)
    largas = []  # (lineas, ruta, nombre, inicio)
    for f in rutas:
        rel = f.relative_to(RAIZ).as_posix()
        lineas = f.read_text(encoding="utf-8").split("\n")
        if lineas and lineas[-1] == "":
            lineas.pop()
        grandes.append((len(lineas), rel))
        for nombre, inicio, largo in funciones(lineas):
            largas.append((largo, rel, nombre, inicio))

    nuevos = []
    crecidos = []
    print("Ficheros de mas de %d lineas:" % MAX_FICHERO)
    for lineas, rel in sorted(grandes, reverse=True):
        if lineas <= MAX_FICHERO:
            break
        tope = EXCEPCIONES_FICHERO.get(rel)
        if tope is None:
            estado = "NUEVO"
            nuevos.append("%s (%d lineas)" % (rel, lineas))
        elif lineas > tope:
            estado = "HA CRECIDO (era %d)" % tope
            crecidos.append("%s (%d > %d)" % (rel, lineas, tope))
        else:
            estado = "excepcion (%d)" % tope
        print("  %5d  %s  %s" % (lineas, rel, estado))
    print("Funciones de mas de %d lineas:" % MAX_FUNCION)
    hubo = False
    for largo, rel, nombre, inicio in sorted(largas, reverse=True):
        if largo <= MAX_FUNCION:
            break
        hubo = True
        clave = "%s:%s" % (rel, nombre)
        tope = EXCEPCIONES_FUNCION.get(clave)
        if tope is None:
            estado = "NUEVA"
            nuevos.append("%s (%d lineas)" % (clave, largo))
        elif largo > tope:
            estado = "HA CRECIDO (era %d)" % tope
            crecidos.append("%s (%d > %d)" % (clave, largo, tope))
        else:
            estado = "excepcion (%d)" % tope
        print("  %5d  %s:%d  %s  %s" % (largo, rel, inicio, nombre, estado))
    if not hubo:
        print("  ninguna")
    # Las excepciones que ya no hacen falta.
    tam = {rel: l for l, rel in grandes}
    for rel, tope in EXCEPCIONES_FICHERO.items():
        if tam.get(rel, 0) <= MAX_FICHERO:
            print("  aviso: %s ya cabe en el limite; quitalo de EXCEPCIONES_FICHERO" % rel)
    vivas = {"%s:%s" % (r, n): l for l, r, n, _ in largas}
    for clave in EXCEPCIONES_FUNCION:
        if vivas.get(clave, 0) <= MAX_FUNCION:
            print("  aviso: %s ya cabe en el limite; quitala de EXCEPCIONES_FUNCION" % clave)
    if detalle:
        print("Los ficheros mas grandes:")
        for lineas, rel in sorted(grandes, reverse=True)[:15]:
            print("  %5d  %s" % (lineas, rel))
        print("Las funciones mas largas:")
        for largo, rel, nombre, inicio in sorted(largas, reverse=True)[:15]:
            print("  %5d  %s:%d  %s" % (largo, rel, inicio, nombre))
    if nuevos or crecidos:
        print()
        for x in nuevos:
            print("Pasa del limite y no esta en la lista: " + x)
        for x in crecidos:
            print("Una excepcion ha crecido: " + x)
        print("Parte el fichero o la funcion (ver docs/pendiente_estructura_y_compatibilidad.md, EST-1).")
    else:
        print("\nTodo dentro del limite, salvo las excepciones apuntadas.")
    return 1 if (estricto and (nuevos or crecidos)) else 0


if __name__ == "__main__":
    sys.exit(main())
