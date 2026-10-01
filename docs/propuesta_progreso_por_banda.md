# Propuesta: progreso del dojo y el museo por tamaño de banda

Decisión de diseño acordada con el usuario, **sin implementar todavía**. Sirve de referencia para
cuando se aborde. No toca código ni capturas.

## El problema

El progreso se guarda en slots separados por tamaño de banda (`players`, 1 a 4, clamp en todos
los sitios): `DojoTrials.best` (`logic/dojo_trials.gd`, clave `_key(id, tier, what, players)`) y
`Den.is_filled` / `Story.star_mask` (`logic/den.gd`, `logic/story.gd`). Así, la vitrina del museo
cambia según con cuántos juegues: un robo hecho en solitario no «cuenta» si luego se juega en
pareja, lo cual resulta confuso.

## Museo: vitrina vs. ficha de la pieza

- **Vitrina general**: una pieza se ve conseguida si se robó con **cualquier** tamaño de banda.
  Estado compartido/global, ya no depende de `players` (`Den.is_filled`/`filled` dejan de mirar
  un solo slot y pasan a mirar el OR de los cuatro).
- **Ficha de la pieza** (al acercarse, con la historia): ahí sí se desglosa modo por modo. Para
  cada tamaño de banda (1/2/3/4) se indica si está pasado, con cuántas estrellas y el mejor
  tiempo de ese modo. La granularidad por banda se mueve del resumen al detalle: no se pierde
  información, solo cambia dónde se muestra.

## Dojo: pruebas individuales vs. pruebas de varios

No todas las pruebas de habilidad dependen igual del número de jugadores. Antes de crear
contenido nuevo hay que clasificar cada prueba (actual o futura) en uno de estos dos tipos:

- **Individuales**: las hace una sola persona; el resto de la banda no participa. Da igual el
  tamaño de banda — es la misma prueba, sin contenido exclusivo ni marcas que fusionar. Las
  nueve pruebas actuales de `DojoTrials.TABLE` (PILLA EL CALCETÍN, EQUILIBRIO, BOLOS, AGUANTA
  ESCONDIDO, GANZÚA, ESCONDITE, CABLES, PULSO, CIRCUITO) probablemente caen aquí.
- **De varios**: requieren cooperación real de N personas simultáneamente (sujetar, relevos,
  activar dos puntos a la vez...). Su puntuación depende de cuántos participan, y puede haber
  pruebas exclusivas de un tamaño de banda concreto (p. ej. solo existen jugando de a 2).
  Para cada una hay que decidir si acepta un rango (2-4) o un número exacto de participantes.

Esta clasificación es un paso previo obligatorio antes de añadir pruebas nuevas: primero
etiquetar individual/de varios, luego (si es «de varios») fijar el rango o número de
participantes.

## Salas del dojo por tamaño de banda

Las pruebas «de varios» de cada tamaño de banda viven en salas específicas, con acceso por
umbral y en cadena física (no independiente):

- La sala de 1 jugador es la sala base: la actual sala común de pruebas de habilidad
  (`Den.DOJO_PLAN`, croquis de 41 × 28 casillas; ver `scenes/den_view.gd` `_trial_starts()`).
- Solo se llega a la sala de 2 atravesando la sala de 1; a la de 3 atravesando la de 2; y así
  hasta la de 4. Puertas en cadena (1→2→3→4), no accesos independientes.
- Acceso acumulativo: con banda de N se puede entrar en las salas hasta N, nunca en una que pida
  más gente de la que hay en la banda.
- Estas salas de tránsito deben ser pequeñas (poco footprint de mapa): son huecos de progresión,
  no el contenido principal. El peso visual y de espacio del dojo sigue estando en las pruebas de
  habilidad en sí, y en general el dojo y el museo siguen siendo zonas importantes del juego.

## Estado

Acordado, no implementado. No hay tarea en curso ni cambios de código asociados a este
documento.
