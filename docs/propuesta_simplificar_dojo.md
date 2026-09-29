# Propuesta: simplificar más el dojo

Estado tras el trabajo hecho (rama del worktree, sobre 835c59f). Las líneas son las de los ficheros del dojo:
`dojo_game`, `dojo_games`, `catch_game`, `pedestal_game`, `bowling_game`, `hide_game`, `dojo_field`, `dojo_watch`, `practice`,
`dojo_games_view`, `house_run`.

## Cifras

| Diez ficheros del dojo (`dojo_game`, `dojo_games`, `catch_game`, `pedestal_game`, `bowling_game`, `hide_game`, `dojo_field`, `dojo_watch`, `practice`, `dojo_games_view`) | Líneas |
|---|---|
| Antes (5bb82ef) | 2 750 |
| Tras la parte 1, limpieza segura (7bbee8d) | 2 786 (sube: funciones grandes partidas en pasos con nombre y comentarios; se fue el código repetido y muerto) |
| Ahora, con la mecánica común de tres dificultades | 2 650 (incluye `dojo_watch`, nuevo, y las 15 vitrinas) |

`pedestal_game.gd` pasa de 211 a 87 líneas (fuera su simulación propia del equilibrio, que en el juego real nunca se usaba).
Además, en `house_run.gd` el banco pierde lecterns, panel y `need_panel`. Salieron 26 claves de texto. Los tests suben (~1 800 líneas
entre `test_dojo_juegos` y `test_escondite`, antes 1 699) porque cubren 3 dificultades, los puntos de inicio y las 15 vitrinas.

## Qué se hizo (resumen)

- Parte 1: niveles, `params`, pérdida con datos (`_lose(why, more)`), partida en pasos con nombre, vista sin código muerto,
  `DojoField.from_den` directo, comentarios al día.
- Parte 2 (encargo del dueño): sin menús. Tres puntos de inicio fijos por juego (fácil 1-3, medio 4-6, difícil 7-10), sin hora extra;
  récord por juego, dificultad y banda; banco de 5 pruebas x 3 vitrinas; sin atriles, sin vitrina de alarma ni panel.

## Recortes posibles todavía (por prioridad)

1. **Quitar PILLA EL CALCETÍN o fusionarlo con BOLOS** (la mecánica de «algo aparece, llega antes de que se acabe» es la misma:
   `CatchGame` y `BowlingGame` comparten `pick`, `_wander`, tiempos por camino y puertas). Ahorro: ~180 líneas y sus tests (~120),
   más 3 pedestales y 2 textos. El jugador pierde el juego más «arcade» y sencillo. **Coste/beneficio: el mejor.**
2. **Quitar las puertas que cierran los juegos y la variante «vigilado» de PILLA/BOLOS** (`gate`, `watch`, `maze`, `forced`,
   `relaxed`, `prefer_not`, `watched_min`): hoy `Den` no tiene `dojo_gates`, así que las puertas nunca se usan en el dojo real y los
   niveles 6 y 10 degradan a laberinto. Ahorro: ~150 líneas en `DojoField` (`candidates`, `pick`, `crossed`, `dist` con `dodge`),
   `CatchGame` y tests (~200). El jugador no pierde nada visible hoy; los niveles «vigilados» (cono de espantapájaros) sí desaparecen.
3. **Reducir de 10 a 3 niveles por juego** (uno por dificultad, con más salto entre ellos): fuera `LEVELS` de 10 filas, la barra
   «n/3», el `between`. Ahorro: ~60 líneas de tablas y ~80 de tests; se pierde la sensación de progreso dentro de un tramo.
4. **Quitar EQUILIBRIO** (ya es solo un temporizador sobre el minijuego «balance», que también existe en los robos): ~90 líneas más
   3 pedestales, el enganche del nivel del minijuego y sus tests (~100). Se pierde la única prueba de «quedarse quieto y aguantar»
   fuera de un robo.
5. **Quitar el estornudo de AGUANTA** (`rise`, `burst`, barras, `tickle`, `TAP`, `WARN`): ~60 líneas y la barra de la vista. El juego
   queda en «esconderse mientras barre la linterna»; se pierde el único uso de la tecla de acción en los juegos.
6. **Banco: dejar solo tres pruebas** (QUIETO, GANZÚA, CABLES; fuera APRETAR y PULSO): 6 vitrinas menos, menos texto y menos lecciones
   del dojo que mirar. Ahorro pequeño (~10 líneas) pero libera la mitad de la exposición.
7. **Unir zonas**: laberinto y patio en una (y sus espantapájaros). Toca `Den.DOJO_PLAN`, `DenView._dojo_walls` y varios tests
   (`test_escondite`: zonas, anchos); ~80 líneas. Riesgo alto para poco beneficio: no recomendado.
8. **Juego para varios ladrones**: quitar `mvp`, `credits`, `names` (~40 líneas y un texto); se pierde «el calcetinero de la banda».

## Recomendación

Hacer 1 y 2 (≈330 líneas menos, tests incluidos) y, si se quiere más, 5. El resto quita variedad sin ahorrar mucho.

## Notas para quien lo aplique

- Cada punto de inicio es un dato de `Practice.ITEMS` (`game`, `via`, `starts`); quitar un juego es quitar su fila, su clase en
  `DojoGames.GAMES`, sus textos `HIDEOUT_GAME_*` y sus tests.
- `docs/data/*.js` se regenera con `python3 tools/docs.py texts` (rápido, sin capturas). Las capturas de la documentación siguen
  sin rehacer (hay que hacerlo al cerrar el bloque).
