# Ciudad de la historia: lo hecho y lo pendiente

Petición del usuario: casita del dojo más a la derecha y más lejos del primer museo (ahora solapaba con el río); moverse con varias teclas (diagonales); botones ANTERIOR / SIGUIENTE a los lados de la pantalla para el ratón.

> Nota: la navegación por ruta (LB/RB, botones laterales, diagonal con dos teclas y ventana de 0,1 s) se retiró; ver docs/propuesta_navegacion_ciudad.md.

## Hecho y verificado (tests en verde)

- **Casita movida**: `CityStage.HIDEOUT_SPOT = Vector2(24, -16)` (`scenes/city_stage.gd:46`; s a lo largo del río, q hacia arriba desde su centro). Antes `(-21, -8)`. Queda en una manzana libre de la orilla de abajo, en tierra firme, a la derecha y junto al quinto museo, a unas 36 unidades en pantalla del primero (antes ~5). El resto (ruta `_route`, `sight()`, `_keep`, rótulo, altura, anillo, candado) sale de `_hideout_lot` / `hideout_spot`, así que no hubo que tocar nada más. Ningún museo se movió.
  - Por qué ahí: `claim(i, p)` reserva la manzana exacta bajo el punto. Se probaron (8,-10), (6,-16), (12,-15), (14,-13) y (16,-17): caen en el hueco entre barrios pegado a la zona deportiva. (10,-24) y (24,-16) caen en la retícula de casas; se eligió (24,-16) por ser la más a la derecha y la más lejos del primer museo sin salirse de lo que se construye.
  - `tools/city_view.gd` dibuja ahora un cuadrado rojo en la casita (`plan`).
- **Navegación espacial** (`scenes/tour.gd`):
  - `Tour.toward(from, dir, stops)` (estática, l.219): elige la parada según la dirección en coordenadas de pantalla. Una tecla: entre las paradas a `CONE = 60°` la más cercana; si no hay, la más alineada si no pasa de `MAX_OFF = 75°`; si no, nada. Dos teclas (la dirección es la suma): la más alineada (mismo tope de 75°). Teclas opuestas se anulan. Nunca hacia atrás.
  - `Tour.step_dirs(dirs)` (l.250) la aplica a las paradas abiertas (museos abiertos + casita, que siempre está abierta). Posiciones: `CityStage.stop_on_screen(m)` (independiente de dónde esté la cámara).
  - Ventana de agrupación `DIR_WINDOW = 0.1 s`: `input()` → `_push()` (l.530) guarda las direcciones pulsadas y `_process` llama a `_flush()` (l.545), que mueve UNA vez con todas las de la ventana. Cualquier otra pulsación (aceptar...) vacía antes lo pendiente. Con `stage.hurry` (los tests) la ventana es 0 y mueve al instante; `dir_window` la fuerza. Cubre teclas, cruceta y stick (los dos ejes por separado). NO se lee `Input.is_action_pressed`: los eventos de la ventana ya incluyen pulsaciones soltadas antes de vaciarla, y leer el estado mantenido daría falsas diagonales al "rodar" de una tecla a otra.
  - `act("left"/"right"/"up"/"down")` sigue siendo síncrono (una dirección). `act("prev")` / `act("next")` (LB, RB y los botones) recorren la RUTA: casita, museos 1 a 5, saltando los cerrados; en los extremos no hacen nada (`_route_order`, `_step_route`).
- **Botones laterales** (`Tour._side_button` l.746, `_place_sides` l.785): `< ANTERIOR` a la izquierda y `SIGUIENTE >` a la derecha, 210×74 (de 1280×720 virtuales), a media altura, a 22 px del borde; cristal oscuro con borde cálido al pasar el ratón (el mismo aspecto que las píldoras del plano y los botones del menú), fuente arcade, "pop" al pulsar. No toman foco. Solo visibles con `state == "city"`. En los extremos de la ruta se atenúan (alfa 0,4, `disabled`); no dan la vuelta. Suenan como el resto ("nav"). El clic directo sobre un museo (`_on_mouse`) sigue igual.
- Textos nuevos en `locale/texts.csv`: `TOUR_PREV` ("< ANTERIOR"), `TOUR_NEXT` ("SIGUIENTE >"); `locale/texts.es.translation` regenerada con `godot --headless --path . --import`. La ayuda de abajo (`TOUR_HINT_PICK`, etc.) no cambia, para no alargar el texto.
- Tests:
  - `tests/test_ciudad_nav.gd` NUEVO (86 comprobaciones): geometría sintética de `toward`, ruta siguiente/anterior, casita a la derecha y lejos del primero, una tecla y diagonal desde cada parada, cerrados ignorados, casita accesible desde el museo 5 y desde el 1, ventana (dos teclas casi a la vez = un salto, separadas = dos, W+D, cruceta, stick, aceptar tras un empujón), botones dentro de la pantalla en 4:3, 16:9 y 32:9, a media altura, sin tapar el museo elegido, clic real con `root.push_input` que cambia `stage.picked`, atenuado en extremos, ocultos dentro del museo.
  - `tests/test_previa.gd`: 4 líneas de dirección ajustadas a la geometría (arriba, izquierda, abajo, arriba en lugar de derecha/izquierda/derecha).
  - `tests/test_escondite.gd` (del otro agente, EDICIÓN MÍNIMA mía en las líneas ~404-412): la casita está ahora a la derecha del primer museo.
  - Resultado final: previa OK, camara_museo OK (58), menus 178 ok / 0 fallos, controles 0 fallos, transiciones 0, siguiente OK (283), story OK, finales 0, escondite 657 ok / 0 fallos, textos 0 fallos, ciudad_nav OK (86). Los `SCRIPT ERROR ... get_meta ... previously freed` de test_menus ya salían antes (`Hud._bubble_open`, `hud.gd:1536`), no son de este cambio.
- README (controles de la ciudad, casita, línea del test) y `docs/pantallas.js` (nodo ciudad: teclas, botones, casita) al día.

## Hecho pero SIN verificar visualmente

No se han sacado las capturas de comprobación (se pidió cerrar antes). Solo se ha mirado el plano (`tools/city_view.gd plan`) con las candidatas a la casita, no el resultado final ni las vistas de juego.

## Pendiente (en orden)

1. Plano con la casita final:
   `SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004 /Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/city_view.gd -- /tmp/c plan`
   y mirar `plan.png` (cuadrado rojo): ¿en tierra firme, sin río, sin carreteras/puentes, sin cortarse por el borde del aspecto ancho?
2. Vista del juego (con ventana) en 4:3, 16:9 y 32:9, la casita elegida, un museo intermedio y el último. Hay un guion a medio camino en el scratchpad de la sesión (`cap_nav.gd`, uso: `-- <salida> <forma 4:3|16:9|32:9> <paradas, p. ej. 5,0,2>`; 5 es la casita). Comprobar: botones laterales legibles y sin tapar cartel ni museo; con la casita elegida no se corta por la derecha (sobre todo 4:3: la casita queda cerca del borde derecho de lo que se construye, `WIDEST`/`SAFE`); el cartel de la casita no choca con el del museo 5.
3. Comprobar a mano con teclado: mantener Arriba y pulsar Derecha (¿se siente bien la espera de 0,1 s? si molesta, bajar `Tour.DIR_WINDOW` a 0,07) y con stick diagonal.
4. Si la casita queda demasiado pegada al museo 5 o a los bordes, probar otras `HIDEOUT_SPOT` y repetir el paso 1 (la reclamación de manzana es automática).
5. Cuando se cierre el bloque: rehacer las capturas de la documentación (`python3 tools/docs.py build shots`; `docs/data/` cambia) — no hecho aquí.

Tests para confirmar todo (ninguno debe dar FALLO):
`for t in ciudad_nav previa camara_museo menus controles transiciones siguiente story finales escondite textos; do godot --headless --path . --script tests/test_$t.gd 2>&1 | grep -E "^FALLO|^OK|^FALLOS"; done`

## Decisiones y dudas para el usuario

- La ruta empieza por la casita (como antes), ahora en el extremo derecho: `< ANTERIOR` desde el museo 1 va a la casita, que queda al otro lado de la ciudad. ¿Mejor que la casita quede fuera de la ruta de los botones, o que la ruta de los botones ordene por proximidad?
- En los extremos los botones se atenúan (no dan la vuelta). ¿Se prefiere dar la vuelta?
- Una diagonal sin nadie exacto a ese lado elige lo más alineado dentro de 75° (p. ej. arriba+derecha desde el museo 1 con el cuarto cerrado va a la casita, a ~40°). ¿Se prefiere que no haga nada?
- Ayuda de abajo sin cambios (el icono WASD ya sugiere las diagonales); ¿se quiere mencionar las dos teclas?

## Prompt para otro agente

> Proyecto Ninja Karma (Godot 4.7), `/Users/chema/Code/Ninja Karma/nosy-horesradish`. Lee `CLAUDE.md` (capturas solo para comprobar, nada de docs ni hitos) y `docs/pendiente_ciudad.md`. No hagas commit ni git stash; hay cambios sin commit de otras sesiones; no uses pkill genérico (guarda el PID de lo que lances). Ejecuta Godot con `SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004`. Tarea: verificar visualmente la ciudad de la historia tras mover la casita (`CityStage.HIDEOUT_SPOT`) y añadir la navegación espacial y los botones laterales (`Tour.toward`, `step_dirs`, `_side_button`; ya implementados y con test en `tests/test_ciudad_nav.gd`). Sigue los pasos 1 a 4 de "Pendiente" (plano con `tools/city_view.gd`, capturas en 4:3, 16:9 y 32:9 con la casita, un museo intermedio y el último elegidos; máximo 3 rondas). Corrige solo lo que se vea mal (posición de la casita, tamaño o posición de los botones, `DIR_WINDOW`), repite `tests/test_ciudad_nav.gd`, `test_previa`, `test_escondite`, `test_menus` y `test_controles`, y informa en español, conciso, de lo visto.
