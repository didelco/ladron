# Estilo y decisiones gráficas

Lo que decide cómo se ve el juego y por qué. Es la única página escrita a mano de `docs/`: la paleta completa, las capturas, los assets y los textos se sacan del juego con `python3 tools/docs.py build`. Cuando cambie una decisión, se cambia aquí (en el mismo commit que el código).

> Regla general del proyecto (README): **simplificar**. Se porta la lógica de la web tal cual; las mejoras, después.

## La idea

Un museo de noche visto desde arriba, **cartoon nocturno a lo Luigi's Mansion 3**: sombras azul-violeta, una luna fría, y solo dos cosas cálidas, las lámparas de las salas y las linternas de los guardias. Los menús son **un museo de noche por dentro**: pared berenjena con papel pintado, paneles de nogal con latón y dioramas 3D axonométricos.

## Reglas

1. **La noche es azul, no gris**: «un hotel encantado, no un apagón» (`scenes/main.gd`, `AMBIENT_COLOUR` `#6256aa`). Solo lámparas y linternas son cálidas.
2. **La linterna es la luz protagonista**: `#fff1d8`, más cálida que la luna y más fría que las lámparas, para que no se confunda con ninguna. Se pone roja al verte.
3. **Todo lo que se ve desde arriba, más grande que en la realidad**: objetos ×1,35, el ninja ×1,1, estrellitas de mareo grandes, pocas partículas («un puñado de motas se lee mejor que una nube»).
4. **La fuente arcade solo grita**: títulos, botones, el reloj y el grito. Nunca en párrafos (`scenes/hud.gd`, commit `0c923c2`).
5. **Toda imagen de menú es axonométrica** (commit `6fa48f4`).
6. **Un color fijo por jugador**: dos figuras turquesa serían una figura.
7. **La caja del minijuego va al lado del ladrón, nunca encima**: lo que dobla la esquina sigue a la vista.
8. **Cinco temas de museo y ninguno más** (commit `819e5ef`).
9. **Cada lección tiene su propia escena**; ninguna toma prestada la de otra.
10. **La cámara del juego nunca gira**: por eso los cuadros solo cuelgan en las paredes que la miran (las del sur no) y el muro exterior solo crece donde no tapa.

## Colores que definen el juego

| Qué | Color | Dónde |
|---|---|---|
| Noche (fondo) | `#0f0d14` | `main.gd` COLOURS.night, pantalla de arranque |
| Tinta (contornos) | `#08070c` | `figure.gd` INK |
| Jugador 1 | `#2ec4a6` | turquesa |
| Jugador 2 | `#f0a13a` | naranja |
| Jugador 3 | `#b07cff` | violeta |
| Jugador 4 | `#4dabf7` | azul |
| Guardia | `#9b2c3f` | granate |
| Texto de interfaz | `#eef2ff` | `hud.gd` C.text |
| Texto secundario | `#9aa0c8` | C.dim |
| Oro (destacado) | `#ffe066` | C.gold |
| Alerta | `#ff3d6e` | C.alert |
| Seguro / salida | `#22d3ee` | C.safe |
| Bien (salida, interruptor) | `#4ade80` | C.green |
| Crema de menús y plano | `#e8d6b4` | MenuStage.CREAM, MAP_FLOOR |
| Latón | `#d8ac5c` | Hud.BRASS |
| Nogal | `#35211a` | Hud.WALNUT |
| Linterna | `#fff1d8` | TORCH_COLOUR |
| Lámpara de sala | `#ffc47e` | ROOM_LIGHT_COLOUR |
| Luna | `#8ea2ff` | MOON_COLOUR |

**Escala de sospecha** (marcas sobre el guardia y alarma arriba al centro): `#ffd43b` algo raro (!) → `#ff922b` alerta (!!) → `#ff3048` va a por ti (!!!).

Cada museo de la historia tiene su paleta (suelo, papel pintado, zócalo, remates). Están todas en la página **Paleta**, sacadas de `logic/story.gd`.

## Tipografía

- **Press Start 2P** (`assets/fonts/`, OFL) para títulos (con contorno `#2a150c` y sombra), botones, listas, títulos de tarjeta, HUD de estado, cuenta atrás, grito y letreros 3D (SALIDA, ALARMA).
- **La fuente por defecto de Godot** para párrafos, textos de tarjeta, registro y panel de IA.
- Toda etiqueta lleva sombra negra al 80 % desplazada 2 px.

## Sombreado y contorno

- **Toon** en personajes, piezas y muros (`DIFFUSE_TOON`, sin especular). Los `.glb` se convierten al cargarse (`MuseumView.asset`).
- **Excepción: el suelo no es toon.** Con toon, el círculo de la linterna sobre un suelo brillante era una losa blanca plana; el suelo usa Lambert + GGX (`scenes/floor.gdshader`).
- **Contorno de tinta** por segunda pasada (copia inflada del revés, 1 cm), salvo ojos, oro, lentes y pilotos.
- **Rayos X**: la silueta de una figura tapada se ve a través de lo que la tapa, en el color de su estado.

## Cámara

- **En juego**: perspectiva con FOV 50, casi cenital (unos 17 m), con correa floja y muelle amortiguado. Con varios ladrones se aleja hasta que caben todos.
- **Sensación de impacto** (commit `2bd0aff`): temblor por «trauma» que desplaza la imagen (no la cámara, para que las luces no parpadeen), acercamiento de golpe al robar y fundidos de 0,2 s.
- **Menús**: dioramas con teleobjetivo (FOV 22, isométrico) y desenfoque tilt-shift; la pieza, en ortográfica.

## Iluminación

- Tonemap ACES (exposición 1,25, saturación 1,12, contraste 1,08) y glow solo por encima de 1,0.
- Niebla volumétrica fina (0,012) para no velar el plano desde arriba; las linternas la iluminan ×12 y las salas ×4.
- Luna fría con sombras: tumba muros y vitrinas en azul, y eso da la profundidad.
- Salas encendidas en ámbar, con un lavado de solo 0,07 (uno fuerte quema a crema). Hasta 6 apliques en la pared norte.
- El polvo del aire solo lo ven las linternas.
- **El cono del guardia** tiene dos bandas: el círculo brillante te ve aunque vayas agachado; la proyección tenue, solo si vas de pie. Bordes difuminados: luz en el suelo, no un recorte.

## Personajes

- **Ninja y guardia** modelados en Blender (`art/personajes/`) con esqueleto común y ciclos de reposo, andar, correr y gatear; la animación va al ritmo de los pies para que no patinen.
- Traje del ladrón en el color del jugador, solapa un 30 % más oscura y cinta, cinturón y puños negros.
- Los bocetos «jelly-bean» (`scenes/bean.gd`) **se descartaron**; solo quedan en `tests/visual/`.

## Museo, piezas y cuadros

- **Lo de forma fija se modela en Blender** (`art/*.blend` → `assets/models/`). **Lo que depende del mapa o de la semilla sigue en código**: muros, suelo, plintos, cuadros y luces.
- Piezas a robar hechas de primitivas, con carácter; todas brillan un poco para leerse en la oscuridad.
- **Cuadros**: pixel art de 48×36 salido de una semilla, así que no hay dos iguales. Nunca en una pared con algo delante; grandes de dos módulos, trípticos de tres o dos o tres pequeños por módulo (commit `5896060`).
- **Suelo**: mármol con vetas, hormigón o tablas. **Paredes**: friso de paneles y papel pintado (yeso, damasco o rayas), en espacio de mundo para que no haya costuras.

## Interfaz

- **Fondo de menús**: la pared de un museo de noche (shader), con papel de rayas, friso y la luz de una lámpara que respira.
- **Botones**: píldoras de nogal con borde de latón. Con foco, latón pulido y borde crema, con un salto elástico a ×1,07 y un aplastamiento al pulsar.
- **Tarjetas**: cara de madera con su diorama 3D, que solo se anima con el foco.
- El ratón toma el foco, para que ratón y flechas nunca señalen dos cosas distintas. La navegación va al vecino más cercano en pantalla.
- **Mapa en juego**: un pergamino plegado en acordeón que se despliega, respira en las manos y se inclina con los controles.
- **Plano**: suelo crema, vitrinas tostadas y lo que se puede tirar en una casilla de un tono algo más cálido que las vitrinas, sin icono, para que no llame la atención. La salida se marca con el mismo kunai verde que señala el camino en el juego. La ruta va en puntos de media casilla.
- **Antes de una noche**: en la historia, «la historia» (rango y robo: «Ladronzuelo · tu quinto robo», nunca «noche n de 20») → «lo nuevo» (si hay algo) → «el plan»; en el generativo y los retos, solo el plan. Sin pestañas: abajo, VOLVER a la izquierda, la siguiente sección en el centro y SALTAR Y JUGAR a la derecha.
- **Reglas del plan**: salen de la propia noche (`logic/briefing.gd`, con sus normas en la cabecera): tres si se puede y cinco como mucho, de catorce palabras como máximo; lo normal no se dice, y una mecánica se cuenta en «lo nuevo» la noche que se enseña y en el plan la siguiente, luego ya no.
- **Mapa de la historia**: la ciudad de noche vista desde arriba, con cada museo en sus colores. Las calles se iluminan hasta el último museo abierto.
- **Pantalla final**: SIGUIENTE en grande, VOLVER en pequeño.

## Cómo llegó hasta aquí (y lo que se descartó)

| Qué | Cambio | Commit |
|---|---|---|
| Menús | como en la web → pixel → juguete caramelo → **museo nocturno** → más compacto | `fb66ac7`, `10420c7`, `b313d94`, `248839b`, `dc3e588` |
| Tarjetas | ilustraciones pixel → **dioramas 3D axonométricos** | `6fa48f4` |
| Personajes | bocetos jelly-bean → **ninja y guardia de Blender** | `bf8a9de` |
| Suelo | toon → **Lambert + GGX** (la linterna no se lee en toon) | — |
| Quitado | cordones rojos del suelo, podio de las tarjetas de jugadores, reloj de ronda | `4454327`, `c81c6d9`, `8437fa4` |

## Pendiente de ordenar

- El humo por capas (`scenes/smoke_fx.gd`) es el de la bomba de humo (`logic/smoke.gd`).
- Hay textos fuera de `locale/texts.csv`: el nombre de los retos de `maps/*.json` y el nombre, la descripción y la historia de las piezas que se escriben en el editor.
