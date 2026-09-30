# Pendiente general del repo

Lista consolidada (2026-09-30), verificada contra el código, de lo que queda vivo en los distintos `docs/pendiente_*.md` y `docs/propuesta_*.md`. Se archivaron aquí los puntos que seguían pendientes; los documentos de origen que ya estaban implementados o decididos (`pendiente_ciudad.md`, `propuesta_navegacion_ciudad.md`, `propuesta_colarse_escondite.md`) se borraron.

## Dojo (`docs/pendiente_dojo_juegos.md`)

- Puertas que cierran juegos (`gates_closed`): `Den` no tiene `dojo_gates()`; los niveles con puerta (6 y 10) degradan a laberinto sin puerta real.
- Si cambia el minijuego ESCONDITE, hay que retocar `DojoTrials.TABLE` y `BenchTrial.steps_for`.

## Estructura y compatibilidad (`docs/pendiente_estructura_y_compatibilidad.md`)

(EST-1 a EST-5, EST-9, EST-10, COMP-1 y COMP-2 ya están hechos; el fichero completo detalla el porqué de cada uno.)

- **EST-6** (prioridad M, tamaño S): helper común de tests. `check()` está duplicado en 21 de 23 tests, en dos variantes distintas; unificar en `tests/support.gd`.
- **EST-7** (prioridad M): política de binarios. `docs/` pesa 18 MB versionados y los `.webp` no comprimen bien en delta; decidir Git LFS o dejar de versionar capturas (regenerarlas al publicar).
- **EST-8**: `git gc`. 216 MB de objetos sueltos frente a 5,6 MB empaquetados; hacerlo cuando no haya otros worktrees escribiendo.
- **COMP-3**: medir FPS en máquina o VM de gama baja con `--rendering-method gl_compatibility` / `--rendering-driver opengl3` y con Forward+ en iGPU, en la noche más cargada de luces, menús 3D con SubViewport y humo. Decide si hace falta COMP-4.
- **COMP-4** (prioridad B, tamaño L): modo Compatibility exportado — solo si COMP-3 lo justifica.

## Documentación (`docs/propuesta_estructura_docs.md`, §5)

Ideas sueltas, sin prioridad marcada:
- Página "Técnico" navegable.
- Enlaces cruzados entre Sonidos/Megafonía y objetos.
- Paginar o agrupar la página de Textos (hoy corta a 600 filas).

## Capturas y hitos de documentación

El trabajo reciente del dojo y de la ciudad no ha rehecho las capturas de documentación ni los hitos (`python3 tools/docs.py build shots`, `python3 tools/docs.py version …`). Según `CLAUDE.md`, esto se hace en lote al cerrar un bloque de trabajo: toca hacerlo si se da ese bloque por cerrado.

## Decisión pendiente del usuario

- **`docs/propuesta_simplificar_dojo.md`**: propone recortes concretos con coste/beneficio (quitar PILLA EL CALCETÍN o fusionarlo con BOLOS, quitar puertas o la variante vigilada, reducir niveles...). Recomienda los puntos 1, 2 y opcionalmente 5. Nada decidido ni aplicado todavía.
