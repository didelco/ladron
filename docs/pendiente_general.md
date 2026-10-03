# Pendiente general del repo

Lista consolidada (2026-09-30), verificada contra el código, de lo que queda vivo en los distintos `docs/pendiente_*.md` y `docs/propuesta_*.md`. Se archivaron aquí los puntos que seguían pendientes; los documentos de origen que ya estaban implementados o decididos (`pendiente_ciudad.md`, `propuesta_navegacion_ciudad.md`, `propuesta_colarse_escondite.md`) se borraron.

## Puertas del editor de retos (`scenes/map_editor.gd`, `logic/museum.gd`, `logic/map_file.gd`)

Añadidas para los mapas de reto (`MapFile.doors`, herramienta "door" en el editor, `Museum.doors`/`toggle_door`/`apply_doors`, acción `"map_door"` en `Game._action_for`/`NightLoop`, hoja en 3D en `MuseumView._map_doors_build`). Queda pendiente:

- **Guardias no abren puertas por sí mismos**: una puerta cerrada es pared para todo lo que ya mira `Museum.grid` (visión, movimiento), así que un guardia la rodea o se queda cortado por ella, nunca la abre. Igual que en `Den`, no se les ha enseñado a abrirlas; dejarlo así a propósito por ahora (complicaría la IA de ronda/patrulla) salvo que se decida lo contrario.
- **Niebla de sala como la de `Den`/`DenView`/`hud.gd`**: en un reto, la cámara ya no ve a través de una puerta cerrada (es una hoja 3D real, no solo lógica: `MuseumView._walls()` nunca pone un macizo sólido en la celda de la puerta, y la hoja cerrada ocupa el hueco) y el plano 2D la pinta como muro mientras está cerrada. Pero un museo de reto no tiene el concepto de "salas que se oscurecen" que sí tiene `Den` (`Den.visible_rooms`, `DenView._veil_rooms`, `Hud.dark_rooms`): una sala ya visitada y luego separada por una puerta cerrada sigue completamente iluminada e insinuada en el plano (los guardias sin visión directa, pero el techo/paredes de esa sala, si ya se construyeron, no se ocultan). Portar el oscurecimiento de salas completas de `Den` a un museo de reto (que no tiene "salas" fijas con nombre, sino `Museum.rooms` dinámicas) es una generalización mayor, no barata; queda para otra sesión si se quiere ese nivel de niebla de guerra.

## Columnas del editor de retos (`scenes/map_editor.gd`, `logic/museum.gd`, `logic/map_file.gd`, `scenes/museum_view.gd`, `logic/themes.gd`)

Añadidas para los mapas de reto (`MapFile.columns`, herramienta "column" en el editor, `Museum.columns`, cuatro looks en `MuseumView._column`/`_map_columns_build` elegidos por `Themes.column_style` según el tema de la sala). Queda pendiente:

- **Colisión y visión circulares, ya reales (ya no aplica lo de "toda la casilla")**: `Museum.grid` sigue guardando la columna como un `Tiles.WALL` normal y corriente (`Museum.load_grid` no lo cambia, y cualquier comprobación que solo mire "¿esto es un muro?", `is_wall`, la sigue viendo sólida entera — el vuelo de un objeto lanzado, el lado de fuera de una salida, la memoria de "aquí hay pared" de un guardia). Pero `Museum.blocks_move` ya no cuenta la casilla de una columna como cuadrado sólido, y `Sim._resolve` empuja en su lugar un cuerpo (radio `r`) fuera de un círculo pequeño en el centro de la columna (`Museum.COLUMN_R`, 0.4 tiles) con la misma fórmula que ya usaba para círculo contra círculo — así que un ladrón o guardia puede pasar pegado a la columna, rodeándola por la casilla, en vez de chocar contra toda ella. `Museum.has_line_of_sight` tiene la misma estrechez: una mirada que pasa por la casilla de la columna pero fuera de ese círculo no se corta; solo se corta si de verdad cruza la piedra. Queda tal cual lo simple (columna = muro entero) en los sitios que solo preguntan "¿es esto un muro?" sin pasar por `blocks_move`/`has_line_of_sight` — no hacía falta tocarlos para lo que pedía el encargo.
- **Solo la edad moderna (y lo sin tema) usa el pilar de hormigón por defecto**: de los cinco temas de museo (`Themes.ALL`), antiguo (dórica), edad media (gótica compuesta), naturaleza (madera) y prehistoria (megalito de piedra, "piedra") tienen ya cada uno su propio estilo de columna; solo moderna y "" (un pasillo, o el dojo si algún día pone columnas) caen en el hormigón desnudo ("moderno"), por no tener un motivo visual más propio que "sin estilo, a lo Ando".
- **El dojo (`Den`) no llega a usar columnas**: `DenView` construye sus propios muros a mano (no reutiliza `MuseumView._walls()` tal cual) y su plano no viene de `MapFile`, así que `Museum.columns` siempre está vacío en una partida de dojo; el estilo de madera está listo en `Themes.column_style`/`MuseumView._column` por si algún día el dojo quiere plantarlas, pero no hay ningún sitio que las coloque todavía.
- **Detección automática de muros exentos** (`MapFile.exempt_walls`, llamada desde `Museum.load_grid`): un `Tiles.WALL` sin ningún `Tiles.WALL` pegado en las 4 direcciones cardinales pasa a tratarse como columna sin que nadie lo marque a mano — cubre de una vez los museos generados, los del editor de retos (p. ej. las celdas `#` sueltas de `EDITOR_T_COLUMNS`, que ya no hacía falta tocar) y las noches de la historia, porque todos pasan por `Museum.load_grid`. El borde exterior del edificio nunca cuenta (fuera de la rejilla, o lo que `MapFile.outside` marca como "no es el edificio", se trata como "no hay muro" para esta detección). Tiene la misma colisión y visión que una columna marcada a mano (el círculo en `Museum.COLUMN_R`, ver el punto de arriba), porque entra igual en `Museum.columns`. El editor (`scenes/map_editor.gd`, `_draw_plan`) también las pinta como columna mientras se edita, aunque nadie las haya marcado, para no mentir sobre cómo se van a ver jugadas; pero sus otras herramientas ("column"/"door"/borrar) siguen mirando solo `MapFile.columns` (las marcadas a mano) — una detectada sola no aparece como "column" en `_pick_up` ni bloquea la herramienta "door" sobre esa celda; no hacía falta para el encargo, pero si algún día se quiere que el editor las trate como ya "column" a todos los efectos (por ejemplo, para que "door" no pueda pisarlas), es donde tocaría mirar.

## Dojo (`docs/pendiente_dojo_juegos.md`)

- Puertas que cierran juegos (`gates_closed`): `Den` no tiene `dojo_gates()`; los niveles con puerta (6 y 10) degradan a laberinto sin puerta real.
- El minijuego ESCONDITE es ya el código de colores (`ColourCode`, `SqueezeGame`), el mismo en la ciudad y en el dojo; su fila de `DojoTrials.TABLE` solo pone muebles y reloj.

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

## Cuadros dibujados a mano (`assets/ui/cuadros/`)

El sistema ya está montado (`Canvases.paint`/`MuseumView._canvas` buscan un PNG dibujado antes de generar uno; tamaños documentados en `ESTILO.md`, sección «Museo, piezas y cuadros»). Admite variantes numeradas por tipo, con el nombre del fichero llevando toda la información: **`<kind>_<ratio>_<n>.png`** (p. ej. `wildlife_43_1.png` = naturaleza, 4:3, variante 1). `ratio` es uno de `Canvases.RATIOS`: `43` (4:3, el único enganchado al juego hoy), `11` (cuadrado) o `34` (póster). `Canvases.drawn_variants(kind, ratio)` prueba `_1`, `_2`... hasta el primer hueco, y `Canvases.drawn(kind, seed, ratio)` elige una de forma determinista (`posmod(seed, nº variantes)`) — la misma pared siempre saca el mismo dibujo. `ratio` tiene por defecto `"43"`, así que se puede crear de más sin tocar código: basta con seguir la numeración y, cuando se enganchen `11`/`34` a algo, ya estará el nombre listo. Un tipo sin ningún fichero sigue cayendo en el procedural de siempre, sin fallos.

**Prehistoria y naturaleza ya no comparten cuadros**: `naturaleza` pasa de `landscape` a su propio tipo, `wildlife` (`logic/themes.gd`). Antes se justificaban 6 imágenes de `landscape` porque las repartían dos museos; separados, cada uno puede repetir su único tipo hasta ~15 veces por su cuenta (`MuseumView._paintings`: `most := 6 + ancho×alto/120`), así que cada uno necesita sus 6 propias — la cuenta del par sube de 6 a 12.

**Nota importante — `ResourceLoader.exists()` no ve un PNG recién creado hasta que Godot reimporta.** Por eso los 28 lienzos en blanco (480×360, blanco liso, nombrados ya `<kind>_43_<n>.png`) se han creado en `assets/ui/cuadros_pendientes/`, no en `assets/ui/cuadros/`: así no hay riesgo de que una reimportación futura (al abrir el editor, por ejemplo) los recoja como "ya dibujados" y sustituyan el procedural con cuadros en blanco por error. Al terminar cada dibujo, mover el fichero correspondiente a `assets/ui/cuadros/` (sin el `_pendientes`) — el nombre no cambia, ya lleva el `ratio` correcto.

| Formato | prehistoria (`landscape`) | naturaleza (`wildlife`) | antiguo | edad_media | moderna | **Necesitamos** | **Tenemos** |
|---|---|---|---|---|---|---|---|
| 4:3 (painting, big, tríptico, pequeños) | 6 | 6 | 6 (3 tipos × 2) | 5 (5 tipos × 1) | 5 (5 tipos × 1) | **28** | **0** (28 lienzos en blanco en `cuadros_pendientes/`) |
| 1:1 (cuadrado, vinilo) | — | — | — | — | 3-4 (provisional) | **3-4** | **0** |
| 3:4 (póster, vertical) | — | — | — | — | 3-4 (provisional) | **3-4** | **0** |
| **Total por tema** | **6** | **6** | **6** | **5** | **11-12** | **34-36** | **0** |

Cada tipo es ahora la prioridad real en su tema: con 1 sola imagen todos sus cuadros saldrían idénticos; con 3-5 tipos (temas con varios) la repetición se diluye sola y 1-2 por tipo basta. `gioconda` a propósito se queda en 1 — es un icono concreto, no debería variar.

**Tríptico, aparte**: sus 3 paneles comparten `kind` pero no imagen (en procedural cada panel sale con semilla distinta; con un PNG fijo, un tríptico dibujado a mano mostraría el mismo dibujo 3 veces en un marco). Es el tamaño menos frecuente con diferencia (~10% de los cuadros, `_paintings()`), así que no bloquea nada: arreglarlo pediría una imagen panorámica dedicada por tipo (3× de ancho, cortada en 3 al mostrarla) o dejar que el tríptico tire siempre del procedural aunque el resto del tipo ya esté dibujado. Sin decidir, no urge.

Los dos formatos nuevos (cuadrado, póster) aún no están enganchados a `_paintings()` — sin frecuencia real en juego, la cifra de 3-4 es una estimación provisional, no un cálculo como el resto de la tabla.

**Sin decidir todavía**: el asset nuevo de "panel informativo grande" (usa el formato póster, pero es una pieza 3D nueva, no solo una textura — distinto del prop pequeño `"panel"` de `logic/props.gd`) — falta diseñar dónde vive físicamente en el museo y cuántas variantes de contenido necesita.

## Cuadros a mano en el editor de retos

Pedido: colocar cuadros a mano en `map_editor.gd` (con guardado de posición en `MapFile`, como ya hacen `doors`/`columns`), y opciones de "rellenar" (correr el algoritmo automático de `_paintings()` y fijar el resultado) o "vaciar" (quitarlos todos).

**Hecho y probado, la base de datos y construcción** (funciona ya en el juego, aunque todavía no se pueda editar a mano):
- `MapFile.paintings`: `Array[Dictionary]` de `{"at": Vector2i, "span": 1|2|3}`, serializa/deserializa igual que `doors`/`columns`.
- `Museum.paintings`, cargado en `load_grid` (mismo patrón, parámetro nuevo al final).
- `MuseumView._paintings()`: si `Museum.paintings` no está vacío, cuelga solo esos (nada automático encima); vacío, sigue exactamente como siempre. `_hang_painting()` nueva, extraída de la lógica que ya había, la usan los dos caminos. Verificado con un museo real de `Sim.new_map`: automático sin cambios, uno a mano se respeta, uno puesto sobre columna se ignora sin romper nada.
- De paso, un fallo real corregido: `_free_wall()` no excluía las columnas (`Museum.columns`), así que podían salir cuadros colgados sobre una exenta.

**Pendiente, la herramienta del editor** (`scenes/map_editor.gd`): la interfaz para hacer clic y colocar, más los botones de rellenar/vaciar. Mismo patrón que puertas/columnas, sin inventar mecanismo nuevo. Pausado a propósito: ese fichero tenía 342 líneas sin commitear de otra sesión trabajando en paralelo (puertas de museo en retos) cuando se llegó a este punto — se decidió esperar a que termine para no arriesgar un conflicto en un fichero tan grande y denso. Retomar cuando esos cambios estén commiteados.

## Capturas y hitos de documentación

El trabajo reciente del dojo y de la ciudad no ha rehecho las capturas de documentación ni los hitos (`python3 tools/docs.py build shots`, `python3 tools/docs.py version …`). Según `CLAUDE.md`, esto se hace en lote al cerrar un bloque de trabajo: toca hacerlo si se da ese bloque por cerrado.

## Decisión pendiente del usuario

- **`docs/propuesta_simplificar_dojo.md`**: propone recortes concretos con coste/beneficio (quitar PILLA EL CALCETÍN o fusionarlo con BOLOS, quitar puertas o la variante vigilada, reducir niveles...). Recomienda los puntos 1, 2 y opcionalmente 5. Nada decidido ni aplicado todavía.
