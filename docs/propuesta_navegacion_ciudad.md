# Navegación de la ciudad: diagnóstico y propuesta

## Diagnóstico

Disposición real en pantalla (unidades del plano de pantalla, x a la derecha, y abajo):

| Parada | x | y | Dónde queda |
|---|---|---|---|
| Casita | 31 | 5 | a la derecha del todo |
| Museo 1 | -7 | 8 | abajo, centro-izquierda |
| Museo 2 | -12 | -13 | arriba del 1 |
| Museo 3 | -33 | -19 | arriba a la izquierda |
| Museo 4 | 7 | -20 | arriba, centro |
| Museo 5 | 22 | 0 | a la derecha |

La ruta (casita, 1, 2, 3, 4, 5) va a saltos: casita→1 **izquierda**, 1→2 **arriba**, 2→3 **izquierda**, 3→4 **derecha** (lejos), 4→5 **abajo-derecha**.

Había tres mecanismos a la vez:

1. Dirección de pantalla (flechas, WASD, cruceta, stick): lleva a la parada que está en esa dirección. Coherente con lo que se ve.
2. SIGUIENTE / ANTERIOR por la ruta (LB/RB, botones): ignora la posición. Con el botón SIGUIENTE (a la derecha de la pantalla) se va a la izquierda o arriba en 3 de cada 5 pasos; con el ANTERIOR (a la izquierda), desde el museo 4 se va a la derecha (a la izquierda, al 3, solo en el sentido contrario: 4→3 es izquierda, 3→2 es derecha).
3. Ventana de 0,1 s para juntar dos teclas en una diagonal.

| Dispositivo | Antes | Contradicción |
|---|---|---|
| Teclado flechas/WASD | dirección de pantalla | ninguna, pero la diagonal exige dos teclas casi a la vez |
| Mando cruceta | dirección de pantalla | igual |
| Mando stick | cada eje por separado, dos saltos en diagonal salvo por la ventana | diagonal poco fiable |
| Mando LB/RB | ruta | RB «siguiente» va a la izquierda (casita→1, 1→2) o arriba (1→2) en 3 de sus 5 pasos |
| Ratón, botón lateral derecho | ruta | idem; el botón de la derecha lleva a la izquierda |
| Ratón, hover/clic | parada bajo el ratón | ninguna |
| Tab | no hace nada en la ciudad | (solo salta en otras pantallas) |

Ejemplo del dueño: desde la casita, «siguiente» es el museo 1, que queda a la izquierda. Con RB se pulsa «siguiente», pero con la cruceta hay que pulsar izquierda; con el botón del ratón de la derecha se va a la izquierda. La misma acción cambia de dirección según el dispositivo.

## Qué hacen otros juegos

Lo verificado en búsqueda (ver fuentes) y lo conocido de memoria (marcado):

- Foco espacial en UI: el D-pad o el stick mueven el foco a lo más cercano en esa dirección, con un cono de unos 60º, repetición al mantener y zona muerta de 0,5 en el stick (guías y librerías de navegación espacial: [standarnav](https://github.com/StandarX-miralabs-tech/standarnav), [Turian #69](https://github.com/MASS4ORG/Turian/issues/69), [PartyBeam #94](https://github.com/PawelWielga/PartyBeam.UI.Playground/issues/94)). Es lo que ya hacía `Tour.toward`.
- Slay the Spire (con mando): izquierda/derecha eligen entre los nodos alcanzables, arriba avanza por el camino ([Say the Spire](https://bradjrenshaw.github.io/say-the-spire/mod/map.html)). El mapa es un árbol que siempre va hacia arriba, así que la dirección física y la lógica coinciden.
- Super Mario World / SMB3 / 3D World, Cuphead, Kirby (de memoria, no verificado en línea): el jugador mueve un cursor por caminos dibujados; cada dirección lleva por el camino que sale en esa dirección, y donde el camino es una línea izquierda/derecha significan atrás/adelante. Nunca hay un botón «siguiente» que ignore el dibujo.
- Pokémon / Zelda (mapa de viaje rápido) e Into the Breach (de memoria): cursor libre o foco que salta al más cercano en la dirección pulsada.
- Civilization y juegos de rejilla (de memoria): cada dirección mueve a la casilla vecina en esa dirección.
- Principios que se repiten: una sola semántica igual en mando, teclado y ratón; la dirección pulsada siempre coincide con lo que se ve; un indicador claro de lo elegido y de a dónde lleva cada dirección; los sitios inaccesibles se saltan o se atenúan.

## Opciones para este juego (5 museos + casita, con cerrados)

**A. Solo dirección de pantalla, con vecinos marcados.** Cualquier dirección lleva al sitio abierto que esté en ella; el stick vale para cualquier ángulo. Sin SIGUIENTE/ANTERIOR ni botones laterales; el ratón por hover y clic. Sobre el sitio elegido, flechas hacia los vecinos alcanzables.
- Pros: una sola regla, igual en todos los dispositivos, ya casi hecha (`toward`); cerrados se saltan solos; cero botones extra.
- Contras: no hay «avanzar por la ruta» explícito (aunque la ruta se ve dibujada); con pocos sitios y disposición irregular alguna dirección puede no llevar a nada.

**B. Lista lineal por la ruta.** Izquierda/derecha (y LB/RB) = anterior/siguiente por la ruta; arriba/abajo, nada.
- Pros: nunca se «pierde» ninguna parada; muy simple de programar.
- Contras: contradice el mapa (la ruta zigzaguea: «derecha» iría arriba o a la izquierda); justo el problema actual.

**C. Híbrido: dirección de pantalla + botones SIGUIENTE/ANTERIOR reetiquetados con flecha.** Las direcciones como A; los botones laterales solo llevan al siguiente/anterior y su flecha apunta a donde se va en pantalla.
- Pros: cubre al que quiere «solo avanzar».
- Contras: el botón del lado izquierdo/derecho ya no puede coincidir con la dirección real (siempre hay pasos que van al lado contrario), así que hay que colocarlo cerca del destino o quitar el lado; más piezas para explicar. Es la mezcla que confunde.

## Recomendación: A

Una sola semántica: la dirección pulsada lleva a lo que está en esa dirección en pantalla, con cualquier dispositivo. Se eliminan los botones laterales, LB/RB en la ciudad (siguen para cambiar de sala dentro del museo) y la ventana de 0,1 s (las diagonales las da el stick de forma natural; con teclas basta una flecha por salto). Las flechas sobre la parada elegida dicen a dónde lleva cada dirección.
