# Juegos del dojo: estado y pendiente

## Hecho y verificado (tests en verde)
- Carteles: `Practice.ITEMS` (`game_atrapa` (22,12), `game_pedestal` (24,2), `game_bolos` (52,13), `game_aguanta` (44,5) con su caja (47,5)); `Practice.map` los añade a `cover`; `Practice.game_signs/game_at/hide_tiles/plinth_tiles`, `SIGN_REACH`, `LANTERN_AT/DIR`.
- Vista de carteles y linterna: `DenView._game_signs`, `refresh_signs`, `set_lantern`, `_scarecrow_post` (refactor de `_scarecrows`).
- Enganche: `scenes/house_run.gd` (`HouseRun`: `dojo_start`, `dojo_end`, `dojo_input`, `dojo_tick`, `lantern_show`), y en `scenes/main.gd` `_action_for` (`do:"game"`), `_prompt_rows`, `_pause` y `_leave_game` (abortan), `_unhandled_input`; en `scenes/night_loop.gd` la llamada en `tick` y `sneeze_coming` (salta con juego); en `scenes/scenery.gd` `build` (crea `DojoGamesView`).
- Textos: `HIDEOUT_GAME_LEAVE_KEY` (tras tocar el CSV hay que reimportar: `Godot --headless --import`, si no sale la clave cruda).
- Tests: `tests/test_escondite.gd` ampliado (carteles por lección, bloquean, acción a <1,3, empezar/abortar no escribe, pausa y Tab abortan, bot de `atrapa` hasta perder guarda el mejor por banda, aceptar = OTRA VEZ).
- README y `docs/pantallas.js` al día (sin capturas ni hitos).

## Hecho pero solo visto a medias
- Vistos con ventana (frames en el scratchpad): carteles, ATRAPA (calcetín con anillo, HUD, panel de fin con récord), BOLOS (el bot rueda y tira bolos, sube de nivel), EQUILIBRIO (subido con barra de inclinación), AGUANTA (escondido con cajas iluminadas).
- Sin ver bien: flecha fuera de pantalla de ATRAPA, cono de la linterna y barra de estornudo de AGUANTA (niveles 5+), panel de «ganaste» y SEGUIR (hora extra), juegos con 2-4 ladrones, mando.

## Pendiente (en orden)
1. Ver con ventana AGUANTA en nivel 5+ (barra de estornudo, pulsar acción) y la linterna 3D: `scenes/den_view.gd` `set_lantern` (no dibuja el cono del suelo; solo lo dibuja el overlay 2D de `DojoGamesView`).
2. Comprobar que el aviso «TAB: DEJAR EL JUEGO» (burbuja sobre el ladrón, `main.gd` `_prompt_rows`) no tapa el «¿LISTOS?»; si molesta, sacarlo del ladrón y ponerlo en el HUD del juego (`scenes/dojo_games_view.gd` `_draw_hud`).
3. Mando: no hay tecla de dejar el juego salvo Start (pausa). Decidir si vale B larga o un botón.
4. Puertas que cierran los juegos (`view.gates_closed`): `Den` no tiene `dojo_gates()`, así que `DojoField.from_den` no ve puertas y los niveles «con puerta» degradan a laberinto. Añadir `Den.dojo_gates()` y ver que `Den.set_open` + `DenView.set_door` bastan.
5. Test de la vista de fin con teclas (`main._dojo_input` con flechas/WASD) y de BOLOS con un bot que rueda de verdad (`Roll.start` tras orientar `p.dir`).
6. Al cerrar el bloque: capturas de documentación e hitos (`python3 tools/docs.py build shots`), no antes.

Comandos: `godot --headless --script tests/test_escondite.gd` (tarda ~80 s; el tramo de la ciudad falla a veces por tiempos: repetir), `test_dojo_juegos.gd`. Captura con ventana: `godot --path . --script <script> -- <dir>` con `SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004`.

## Decisiones y dudas para el usuario
- Dejar un juego: **Tab o la pausa** (Esc/P/Start), no la tecla de acción, para que un E suelto no aborte una partida (además E es el golpe de estornudo en AGUANTA). ¿Vale?
- AGUANTA sale con la lección `torch` (noche 4) pero las cajas/taquilla del dojo vienen con `props` (noche 8): el cartel trae **su propia caja** (47,5) para que se pueda jugar desde la noche 4. ¿Mejor subir el juego a `props`?
- La linterna es un espantapájaros propio en (52,3), que solo existe mientras dura el juego (con figura de guardia), distinto de los espantapájaros fijos.
- EQUILIBRIO usa el minijuego «balance» del modo (`fell`/`lean` en los cuerpos), no la simulación propia del juego.
- Tras salir de un juego hay 0,5 s en los que el cartel no arranca otro (`_dojo_lock`), por la tecla E aún pulsada.

## Prompt para otro agente
Proyecto Ninja Karma (Godot 4.7), directorio del worktree. Lee CLAUDE.md y `docs/pendiente_dojo_juegos.md`. Continúa el enganche de los 4 juegos del dojo siguiendo la sección «Pendiente» en orden, sin capturas de documentación ni hitos. No hagas commit ni git stash. Ejecuta Godot con `SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004`. Al acabar corre test_escondite, test_dojo_juegos, test_menus, test_controles, test_previa, test_megafonia y test_megafonia_voz y informa en español.
