#!/usr/bin/env python3
"""Vigila los ciclos de dependencia entre los scripts de logic/.

Un script depende de otro si, en su codigo (sin comentarios ni cadenas), nombra
su class_name. Se leen los .gd de logic/ (y de sus subcarpetas) y se buscan:

  - los pares circulares (A usa B y B usa A);
  - los ciclos mas largos (componentes fuertemente conexas de mas de un script).

Uso:
  python3 tools/ciclos.py             lista los ciclos y dice cuales son nuevos
  python3 tools/ciclos.py -v          ademas, la linea que crea cada arista
  python3 tools/ciclos.py --estricto  sale con 1 si hay un ciclo que no este en PERMITIDOS

PERMITIDOS son los pares que se dejan a proposito, cada uno con su razon en
docs/pendiente_estructura_y_compatibilidad.md.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CARPETA = RAIZ / "logic"

# Pares circulares que se dejan a proposito (ver el documento de pendientes).
PERMITIDOS = {
    frozenset(p)
    for p in [
        ("Sim", "Heist"),
        ("Sim", "Props"),
        ("Sim", "Hideouts"),
        ("Sim", "Plinths"),
        ("Sim", "Smoke"),
        ("Hideouts", "Props"),
        ("Hideouts", "Thief"),
    ]
}


def limpiar(texto: str) -> str:
    """Quita comentarios (# ...) y el contenido de las cadenas, linea a linea.

    Las cadenas de varias lineas (triples comillas) tambien se vacian.
    """
    salida = []
    en_triple = None
    for linea in texto.split("\n"):
        i, n, out = 0, len(linea), []
        while i < n:
            if en_triple:
                fin = linea.find(en_triple, i)
                if fin < 0:
                    i = n
                else:
                    i = fin + 3
                    en_triple = None
                continue
            c = linea[i]
            if c == "#":
                break
            if linea.startswith('"""', i) or linea.startswith("'''", i):
                en_triple = linea[i : i + 3]
                i += 3
                continue
            if c in "\"'":
                j = i + 1
                while j < n and linea[j] != c:
                    j += 2 if linea[j] == "\\" else 1
                out.append(c + c)
                i = j + 1
                continue
            out.append(c)
            i += 1
        salida.append("".join(out))
    return "\n".join(salida)


def leer():
    archivos = sorted(CARPETA.rglob("*.gd"))
    nombres = {}
    for f in archivos:
        m = re.search(r"^class_name\s+(\w+)", f.read_text(encoding="utf-8"), re.M)
        if m:
            nombres[m.group(1)] = f
    aristas = {}  # (a, b) -> [(linea, texto)]
    for a, f in nombres.items():
        limpio = limpiar(f.read_text(encoding="utf-8"))
        for num, linea in enumerate(limpio.split("\n"), 1):
            if linea.startswith("class_name"):
                continue
            for b in nombres:
                if b != a and re.search(r"\b" + b + r"\b", linea):
                    aristas.setdefault((a, b), []).append((num, linea.strip()))
    return nombres, aristas


def componentes(nombres, aristas):
    """Tarjan: componentes fuertemente conexas con mas de un nodo."""
    vecinos = {n: [] for n in nombres}
    for a, b in aristas:
        vecinos[a].append(b)
    indice, bajo, pila, en_pila, res, cont = {}, {}, [], set(), [], [0]

    def visita(v):
        indice[v] = bajo[v] = cont[0]
        cont[0] += 1
        pila.append(v)
        en_pila.add(v)
        for w in vecinos[v]:
            if w not in indice:
                visita(w)
                bajo[v] = min(bajo[v], bajo[w])
            elif w in en_pila:
                bajo[v] = min(bajo[v], indice[w])
        if bajo[v] == indice[v]:
            comp = []
            while True:
                w = pila.pop()
                en_pila.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                res.append(sorted(comp))

    sys.setrecursionlimit(10000)
    for n in nombres:
        if n not in indice:
            visita(n)
    return sorted(res)


def main():
    verboso = "-v" in sys.argv
    estricto = "--estricto" in sys.argv
    nombres, aristas = leer()
    pares = sorted({tuple(sorted(p)) for p in aristas if (p[1], p[0]) in aristas})
    nuevos = [p for p in pares if frozenset(p) not in PERMITIDOS]
    print(f"{len(nombres)} scripts en logic/, {len(aristas)} dependencias")
    print(f"{len(pares)} pares circulares ({len(pares) - len(nuevos)} permitidos, {len(nuevos)} sin permitir)")
    for a, b in pares:
        marca = "permitido" if frozenset((a, b)) in PERMITIDOS else "NUEVO"
        print(f"  {a} <-> {b}  [{marca}]")
        if verboso:
            for x, y in ((a, b), (b, a)):
                for num, txt in aristas[(x, y)][:3]:
                    print(f"      {x}->{y} {nombres[x].name}:{num}: {txt[:100]}")
    for comp in componentes(nombres, aristas):
        print("componente circular: " + ", ".join(comp))
    if estricto and nuevos:
        sys.exit(1)


if __name__ == "__main__":
    main()
