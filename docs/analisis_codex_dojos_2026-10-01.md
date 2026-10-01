# Auditoría Codex de jugabilidad y comprensión de los dojos

**Fecha:** 1 de octubre de 2026 · **Versión revisada:** Godot 4.7.2, juego 0.1.351  
**Alcance:** acceso, desbloqueo, inicio y fin de las pruebas, mensajes, lectura visual y diferencias entre bandas de 1 a 4 jugadores. Este documento amplía [la auditoría general de experiencia](analisis_codex_2026-10-01.md). No modifica el juego.

## Veredicto

El dojo base tiene nueve pruebas y tres dificultades por prueba, con nombres y colores coherentes. Se puede entender **dónde** empezar una prueba cuando ya está disponible. Se entiende peor **por qué** unas pruebas no aparecen, **qué acción exacta** se espera en algunas de ellas y **por qué** la misma prueba y su récord parecen reiniciarse al cambiar el tamaño de la banda. La mayor discrepancia entre 1 y 4 jugadores es que las salas exclusivas de 2, 3 y 4 se pueden abrir según el tamaño de la banda, pero solo contienen un cartel de «PRÓXIMAMENTE»: hoy no hay jugabilidad cooperativa en ellas.

## Método y límites

Revisé el código de las pruebas, sus textos y las puertas; ejecuté el juego con perfiles de progreso aislados para 1, 2, 3 y 4 jugadores; inspeccioné visualmente el dojo base, las tres alas, el HUD y un resultado de PILLA EL CALCETÍN. Para llegar a puntos concretos usé instrumentación temporal fuera del repositorio que situó a la banda en la sala y abrió las puertas permitidas. Por tanto, la observación de las alas comprueba su aspecto y contenido, pero **no equivale** a un recorrido manual completo desde el menú. La activación por tecla y por interacción se corroboró en código y pruebas automatizadas, no se completaron manualmente las nueve pruebas con cada número de jugadores.

La matriz de desbloqueos y puertas se ejecutó directamente sobre la lógica del juego. `tests/test_pruebas.gd` y `tests/test_dojo_juegos.gd` terminaron con **0 fallos**. En una ejecución aislada, `tests/test_escondite.gd` falló primero en «con el ratón encima, la casita», produjo fallos en cascada sobre la entrada a la casa y no terminó en 15 segundos; una ejecución anterior también quedó bloqueada tras un error de índice. Esto deja el recorrido automático desde la ciudad **sin validar** y merece una investigación aparte. No demuestra por sí solo que el jugador no pueda entrar en el dojo.

## Qué se puede jugar con cada banda

| Jugadores | Dojo común | Alas que puede abrir | Contenido jugable de las alas | Progreso y marcas |
|---|---|---|---|---|
| 1 | Las mismas 9 pruebas individuales, según avance | Ninguna | — | Historia y récords del slot de 1 |
| 2 | Las mismas 9 pruebas individuales, según avance | Banda de 2 | Ninguno; cartel «PRÓXIMAMENTE» | Historia y récords del slot de 2 |
| 3 | Las mismas 9 pruebas individuales, según avance | Bandas de 2 y 3 | Ninguno; dos carteles | Historia y récords del slot de 3 |
| 4 | Las mismas 9 pruebas individuales, según avance | Bandas de 2, 3 y 4 | Ninguno; tres carteles | Historia y récords del slot de 4 |

Las nueve pruebas están marcadas como `PARTY_SOLO`: participa un ladrón cada vez. No existe todavía ninguna `PARTY_GROUP`. Las puertas de las alas funcionan como una cadena 1→2→3→4 y la matriz comprobó que una banda demasiado pequeña no puede abrir la siguiente. El cambio de número de jugadores no activa una clase especial ni altera el objetivo de las nueve pruebas: selecciona otro avance de historia y otro conjunto de marcas. Esto se deduce de `DojoTrials.TABLE`, `Story.unlocked(players)`, `Practice.open_trials(players)` y la clave de récord por `players`.

### Cuándo aparecen las pruebas

El desbloqueo es automático al alcanzar, **con ese tamaño de banda**, la noche que presenta cada mecánica. No hay interruptor de «activar/desactivar clases» en el dojo.

| Noche alcanzada | Pruebas disponibles en el dojo común | Total |
|---:|---|---:|
| 1 | Ninguna | 0/9 |
| 2 | CIRCUITO | 1/9 |
| 4 | + AGUANTA ESCONDIDO | 2/9 |
| 6 | + PILLA EL CALCETÍN, EQUILIBRIO y GANZÚA | 5/9 |
| 8 | + BOLOS y ESCONDITE | 7/9 |
| 11 | + CABLES | 8/9 |
| 13 | + PULSO | 9/9 |

Esta secuencia es idéntica para las cuatro bandas **si tienen el mismo avance**. Si una persona llega a la noche 13 en solitario y cambia a cuatro jugadores sin haber progresado con esa banda, vuelve a ver 0/9. Es coherente con la historia por banda, pero la interfaz no explica la relación ni que los récords de pruebas individuales también se separen.

### Cómo se inicia y termina una prueba

Hay tres puntos por prueba, verde/fácil, naranja/medio y rojo/difícil. PILLA EL CALCETÍN, BOLOS, GANZÚA, ESCONDITE, CABLES, PULSO y CIRCUITO muestran una acción contextual para empezar. EQUILIBRIO empieza al subirse al pedestal; AGUANTA ESCONDIDO, al entrar en la armadura. Estas dos excepciones son importantes porque no ofrecen el mismo verbo explícito de «empezar» que las otras siete. Durante la prueba, Tab sale y descarta la tentativa; al acabar aparece un panel con repetir, salir y, si se ha ganado y existe dificultad siguiente, seguir. El panel tiene una protección de 0,4 s para evitar que la tecla que acaba la prueba elija por accidente.

## Hallazgos priorizados

### P0 — Alas abiertas sin actividad para 2–4 jugadores

**Evidencia.** En 2 jugadores se entra en un cuarto vacío con «PRÓXIMAMENTE · BANDA DE 2»; en 3 se recorren dos cuartos equivalentes; en 4, tres. La tabla de pruebas confirma cero pruebas de grupo. La puerta da la impresión de que el tamaño de banda habilita jugabilidad nueva, pero solo habilita espacio. **Impacto:** exploración sin recompensa y expectativa de cooperación incumplida, especialmente en 3–4 jugadores. **Corrección:** hasta que haya una prueba cooperativa, presentar esas puertas como contenido futuro antes de hacer recorrer los cuartos, o mantenerlas cerradas; cuando se publiquen, explicar cuántas personas exige cada reto y qué deben hacer simultáneamente. **Criterio:** al elegir una banda de N, ninguna sala accesible parece prometer una prueba que no existe.

### P0 — Progreso y récords de pruebas individuales separados por número de jugadores

**Evidencia.** Las nueve pruebas tienen la misma lógica y un único participante, pero `best` y `won` usan una clave con 1, 2, 3 o 4. Un récord de EQUILIBRIO conseguido a solas no se muestra con una banda de dos, incluso cuando hace exactamente lo mismo un solo jugador. El documento de diseño [propuesta_progreso_por_banda.md](propuesta_progreso_por_banda.md) ya identifica esta confusión; parte de su clasificación y las alas se implementaron, pero la separación de marcas sigue vigente. **Impacto:** sensación de pérdida de progreso o de que la prueba ha cambiado sin explicación. **Corrección recomendada:** compartir marcas de pruebas `PARTY_SOLO` entre tamaños de banda, conservando un desglose opcional si interesa comparar modos; reservar récord por banda para futuras pruebas `PARTY_GROUP`. Si se decide mantener la separación, explicarla en la ficha y en el marcador antes de que el usuario cambie de banda. **Criterio:** repetir una prueba individual con otra banda no hace desaparecer el récord sin un motivo visible.

### P1 — Dojo vacío al principio sin orientación de desbloqueo

**Evidencia.** En la noche 1 hay 0/9 pruebas y la primera aparece al alcanzar la 2; la pizarra comunica el conteo, pero no el requisito. Al entrar en la casa se aparece en el salón, con ayuda de salida/mapa pero sin objetivo ni ruta clara hacia el dojo. **Impacto:** alguien puede concluir que el dojo está roto o que no ha sabido activar sus clases. **Corrección:** en el dojo vacío mostrar un mensaje situado: «Las pruebas aparecen al avanzar en la historia de esta banda. Primera prueba: CIRCUITO, al llegar a la noche 2», además de señalizar la puerta del dojo desde el salón. En estados posteriores, mostrar pistas de la siguiente prueba bloqueada. **Criterio:** en 1P y 4P de noche 1 se entiende por qué hay 0/9 y cuál es el siguiente paso.

### P1 — El mensaje de récord contradice la derrota

**Evidencia visual.** Al agotarse el tiempo en PILLA EL CALCETÍN fácil sin capturas, el HUD mostraba 0/3, el panel decía «¡SE FUE EL CALCETÍN!», «Se acabó el tiempo», «Tu marca: NIVEL 1» y «¡NUEVO RÉCORD!». La lógica guarda el nivel alcanzado en los juegos incluso si se pierden; las pruebas de banco/circuito solo guardan tiempo al ganar. **Impacto:** «récord» suena a éxito mientras el objetivo no se ha completado; además, 0/3 y «NIVEL 1» parecen métricas incompatibles. **Corrección:** separar «mejor intento» de «prueba superada», mostrar el progreso concreto de capturas y reservar una felicitación fuerte para una mejora significativa o victoria. Explicar si NIVEL 1 significa nivel iniciado. **Criterio:** tras perder con 0/3, el panel no induce a creer que se superó la prueba.

### P1 — Los objetivos de inicio describen el tema, no la acción

**Evidencia.** El texto de preparación de PILLA EL CALCETÍN es «¡PILLA EL CALCETÍN!»; EQUILIBRIO dice «¡AGUANTA!», BOLOS «¡RUEDA!». El objeto y el haz amarillo ayudan a orientarse, pero la instrucción no concreta controles, condición de éxito ni causa de fallo. Las dos pruebas que se activan automáticamente al posar/esconderse cambian además la convención de inicio. **Impacto:** se depende de ensayo y error, particularmente al volver a una mecánica mucho después de su lección. **Corrección:** añadir una instrucción breve específica de cada prueba antes de empezar y una pista durante los primeros segundos: acción, meta y límite. Para EQUILIBRIO y AGUANTA ESCONDIDO, indicar junto al punto «Sube al pedestal para empezar» / «Entra en la armadura para empezar». **Criterio:** alguien que llega directamente desde la casa puede explicar cómo arrancar y ganar cada prueba sin recordar la noche de historia.

### P2 — Textos de mundo y HUD compiten por espacio

**Evidencia visual.** El prompt «COGER EL CALCETÍN (FÁCIL)» se parte en varias líneas y se superpone a la rotulación del objeto. Durante la prueba, «TAB: SALIR» queda sobre la tarjeta de retrato inferior; con más tarjetas de jugadores hay menos espacio libre. Las señales de suelo de las alas son pequeñas respecto a la vista de juego. **Impacto:** peor lectura del botón, dificultad y salida justo cuando hay que actuar deprisa. **Corrección:** reservar zonas de interfaz que no coincidan con retratos, limitar anchura de prompts y separar la etiqueta del objeto del verbo de interacción. Verificar a resolución mínima y con 1–4 retratos. **Criterio:** botón, dificultad, temporizador y objetivo siguen legibles en capturas de los cuatro tamaños.

### P2 — El mapa no resuelve la orientación

**Evidencia visual.** El mapa de la casa representa el plano, pero no nombra las salas ni indica el destino «dojo»; la leyenda inferior puede quedar tapada por el retrato. **Impacto:** la ruta desde el salón hasta la práctica sigue siendo ensayo y error, y abrir alas nuevas no aclara qué contenido hay en ellas. **Corrección:** rotular salas, marcar «estás aquí», puertas restringidas y pruebas disponibles; colocar la leyenda fuera del área de tarjetas. **Criterio:** una banda de 1 y otra de 4 pueden localizar su sala de pruebas y saber qué alas son accesibles mirando el mapa.

## Qué funciona

- Los tres niveles tienen el mismo código de color en los puntos de inicio y el resultado; los nombres de pruebas son reconocibles.
- El acceso a las alas respeta el mínimo de jugadores; la secuencia 1→2→3→4 es consistente.
- El panel final ofrece repetir o salir y evita selecciones accidentales por doble pulsación.
- Las pruebas de lógica del dojo y de sus juegos pasan; los hallazgos principales son de expectativa, comprensión y comunicación, además de la prueba de integración bloqueada.

## Orden sugerido de trabajo

1. Resolver la promesa de las alas vacías y decidir el modelo de récord de las nueve pruebas individuales.
2. Explicar desde noche 1 por qué hay 0/9 y cómo llegan nuevas pruebas al avanzar **con esa banda**.
3. Reescribir las instrucciones de inicio y el mensaje de récord/derrota; añadir pistas a las dos activaciones automáticas.
4. Ajustar prompts, HUD y mapa con capturas de 1, 2, 3 y 4 jugadores.
5. Reparar `tests/test_escondite.gd` o el flujo de casita que revela; después repetir el recorrido desde ciudad hasta dojo con teclado, mando y ratón para cerrar la validación de navegación completa.

## Referencias de implementación

`logic/dojo_trials.gd` (clasificación, desbloqueos y récords); `logic/practice.gd` (puntos de inicio); `logic/dojo_watch.gd` (inicio automático); `logic/den.gd` (puertas); `scenes/den_view.gd` (alas y carteles); `scenes/house_run.gd` (inicio/salida); `scenes/trial_view.gd` y `logic/trial_menu.gd` (HUD y panel); `locale/texts.csv` (mensajes).
