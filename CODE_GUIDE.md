# Guía del código de Ninja Karma

Esta guía explica cómo está construido el juego y dónde cambiar cada cosa. Está
separada de `docs/`, que contiene la web de documentación del contenido del juego.
No hace falta conocer Godot para empezar a orientarse.

## Primeros pasos en Godot

Abre [project.godot](project.godot) desde el gestor de proyectos de Godot. Ese
archivo define la escena inicial, la ventana y las acciones de entrada. Pulsa
**F6** para ejecutar la escena abierta y **F5** para ejecutar el juego completo.
También puedes lanzar el juego desde la terminal con `./jugar.sh`.

En el editor hay tres zonas especialmente útiles:

- **Sistema de archivos:** las carpetas del proyecto. Abre aquí un `.tscn` o un `.gd`.
- **Escena:** el árbol de elementos de la escena abierta.
- **Inspector:** las propiedades del elemento seleccionado. Aquí aparecen las
  variables del script marcadas con `@export`.

| Término | Qué significa aquí |
| --- | --- |
| Escena, archivo `.tscn` | Un conjunto de elementos guardado: por ejemplo, el salón. Una escena puede contener otras escenas. |
| Nodo | Un elemento del árbol: una cámara, una luz, un botón o un personaje. `Node3D` vive en el mundo 3D; `Control` sirve para interfaces. |
| Script, archivo `.gd` | Código GDScript que define datos y acciones. `extends` indica qué tipo amplía; `class_name` permite usar su clase desde otros scripts. |
| Recurso | Datos o materiales que Godot puede cargar: textura, malla, sonido, shader o escena. No es necesariamente un elemento del árbol. |
| `PackedScene` | Una escena guardada. `instantiate()` crea una copia que puede añadirse al árbol con `add_child()`. |
| Señal | Un aviso al que otros objetos se suscriben con `connect()`. Por ejemplo, `BrainClient.decided` avisa de que ha llegado una decisión. |
| `RefCounted` | Un objeto de código sin nodo visual, como muchos controladores y reglas del juego. |
| `res://` | La raíz de este proyecto. `res://scenes/main.gd` es `scenes/main.gd`. |
| `user://` | La carpeta de datos del jugador que administra Godot, fuera del código del proyecto. |

Mucho del mundo se construye **por código al arrancar**, así que abrir una escena
no siempre muestra todos sus objetos en el editor. El árbol **Remoto**, mientras
el juego se ejecuta, muestra los nodos creados durante la partida.

## Por dónde empezar a leer

1. [scenes/main.tscn](scenes/main.tscn) es la entrada del juego: su nodo `Main`
   lleva el script [main.gd](scenes/main.gd), clase `Game`.
2. `Game._ready()` prepara textos, entrada, sonido, interfaz, ambiente y primera
   ronda. `mode` distingue historia, generativo, retos y casa; `phase` distingue
   menú, partida, pausa y final. Son dos decisiones distintas.
3. `Game` conserva el estado compartido y crea controladores como `house`,
   `scenery`, `hands` y `loop`. Cada controlador guarda `host`, una referencia a
   ese mismo `Game`; `host.hud` significa «la interfaz de este juego».
4. [night_loop.gd](scenes/night_loop.gd) aplica las reglas de una partida en
   `tick()`. [scenery.gd](scenes/scenery.gd) construye y actualiza su representación
   3D. Reglas y dibujo se pueden leer por separado.

Los métodos `_ready()`, `_physics_process(dt)`, `_process(dt)` y
`_unhandled_input(event)` son entradas que llama Godot: al entrar el nodo en el
árbol, en pasos de simulación, en fotogramas y al recibir entrada respectivamente.
`dt` es el tiempo transcurrido desde el paso anterior. El resto de funciones las
llama el propio juego. Un prefijo `_` suele indicar un detalle interno, pero
GDScript no lo convierte en privado.

## Mapa de carpetas

| Carpeta | Contenido |
| --- | --- |
| [logic/](logic/) | Reglas y datos del juego: mapas, progreso, movimiento, vigilancia y minijuegos. La mayoría no crea nodos visuales. |
| [scenes/](scenes/) | Escenas, interfaz, controladores de la partida y construcción del mundo 3D. |
| [scenes/home/](scenes/home/) | Salón, dojo y museo de casa, en escenas independientes. |
| [scenes/gameplay/](scenes/gameplay/) | Componentes de interacción durante la partida, compartidos por casa y robos. |
| [scenes/museum/](scenes/museum/) | Componentes visuales reutilizables del museo; también sirven para la casa. |
| [scenes/museum/buildings/](scenes/museum/buildings/) | Decoración de los edificios exteriores de la ciudad, por tema. |
| [scenes/editor/](scenes/editor/) | Vista 3D, mando, widgets y panel de guardias del editor. |
| [scenes/ui/maps/](scenes/ui/maps/) | Dibujo de planos e iconos, mapa plegado y leyenda. |
| [scenes/ui/menus/](scenes/ui/menus/) | Elementos de menú, tablas, listas, botones y tarjetas. |
| [scenes/city/town/](scenes/city/town/) | Terreno/río, vegetación y zonas de la ciudad. |
| [assets/](assets/) | Modelos exportados, imágenes, fuentes e iconos que carga el juego. |
| [audio/](audio/) | Audio, incluidas las voces de megafonía. |
| [locale/texts.csv](locale/texts.csv) | Textos que se ven en el juego, buscados por clave con `Text.t()`. |
| [maps/](maps/) | Mapas de contenido, incluidos los de historia cuando están guardados en el proyecto. |
| [art/](art/) | Fuentes de Blender y herramientas de exportación de modelos. |
| [brain/](brain/) | Servicio del cerebro de los guardias. El juego también tiene reglas de reserva cuando no está disponible. |
| [tests/](tests/) | Pruebas automáticas; [tools/](tools/) contiene utilidades de desarrollo. |
| [docs/](docs/) | Documentación del contenido y su web. Esta guía del código vive fuera. |

## Dónde cambiar cada cosa

| Quiero cambiar… | Empiezo por… | Qué hace cada parte |
| --- | --- | --- |
| Pegatinas y opciones del menú | [hub.gd](scenes/hub.gd), [assets/ui/hub/](assets/ui/hub/) | `Hub` organiza las tarjetas y su navegación; las imágenes viven en assets. |
| Ajustes y modo desarrollador | [settings_screens.gd](scenes/settings_screens.gd), [settings.gd](logic/settings.gd), [dev_overlay.gd](scenes/dev_overlay.gd) | Pantallas, valores guardados y contador de FPS respectivamente. |
| Teclados, mandos y jugadores | [hands.gd](scenes/hands.gd), [pads.gd](logic/pads.gd), [controls_diagram.gd](scenes/controls_diagram.gd) | Asientos/entrada de jugadores, lectura del mando y dibujo de los controles. |
| Distribución del salón, dojo o museo de casa | [home/README.md](scenes/home/README.md), [salon.tscn](scenes/home/salon.tscn), [dojo.tscn](scenes/home/dojo.tscn), [museo_casa.tscn](scenes/home/museo_casa.tscn) | Cada escena guarda sus habitaciones, muebles, puertas y llegadas. |
| Cambios entre habitaciones de casa | [house_run.gd](scenes/house_run.gd), [home_space.gd](scenes/home/home_space.gd), [den.gd](logic/den.gd) | Transición de la banda, configuración de la escena activa y reglas del plano. |
| Aspecto de la casa | [den_view.gd](scenes/den_view.gd) | Constructor compartido de suelos, muebles, trofeos, dojo, luces y puertas. Reutiliza `MuseumView`. |
| Pruebas del dojo | [dojo_trials.gd](logic/dojo_trials.gd), [dojo_trial.gd](logic/dojo_trial.gd), [practice.gd](logic/practice.gd), [trial_view.gd](scenes/trial_view.gd) | Registro y desbloqueos, ejecución de una prueba, preparación de objetos y presentación visual. Las reglas específicas están en los scripts `*_game.gd` y `*_trial.gd` de `logic/`. |
| Historia, museos y progreso | [story.gd](logic/story.gd), [city_stage.gd](scenes/city_stage.gd), [tour.gd](scenes/tour.gd) | Datos/progreso, selección en la ciudad y recorrido de un museo antes del robo. |
| Exteriores de la ciudad | [town_builder.gd](scenes/town_builder.gd), [museum_building.gd](scenes/museum_building.gd) | Construcción del entorno y de las fachadas temáticas. No son los interiores donde se juega el robo. |
| Jardines y decoración del museo de naturaleza | [nature_decoration.gd](scenes/museum/buildings/nature_decoration.gd) | Jardineras, plantas, cubierta, plaza, cascada, mariquita y caracol. Reutiliza las mallas y reglas de construcción del edificio. |
| Crear o cargar un mapa | [mapgen.gd](logic/mapgen.gd), [map_file.gd](logic/map_file.gd), [museum.gd](logic/museum.gd) | Generador, formato/validación/guardado y plano activo utilizado por las reglas. |
| Editor de mapas y retos | [map_editor.gd](scenes/map_editor.gd), [challenge_screens.gd](scenes/challenge_screens.gd) | Herramientas de edición y pantallas que abren/prueban mapas. |
| Cámara y edición 3D del editor | [preview_3d.gd](scenes/editor/preview_3d.gd) | Cámara orbital, cambio entre plano y 3D, selección de casillas y marcas de cambios antes de reconstruir. |
| Mando dentro del editor | [pad_navigation.gd](scenes/editor/pad_navigation.gd) | Cursor, repetición, catálogo, categorías y trazos; llama a las mismas herramientas que el teclado y ratón. |
| Objetos del museo y sus paredes | [museum_view.gd](scenes/museum_view.gd), [collection.gd](logic/collection.gd), [themes.gd](logic/themes.gd) | Dibujo 3D, asignación de contenido y catálogo por tema. |
| Aspecto de las recreativas | [arcade_appearance.gd](scenes/museum/arcade_appearance.gd) | Colores, materiales y pantalla por juego; sus cachés son compartidas por museo y casa. La partida de la recreativa sigue en `logic/minigames/arcade.gd`. |
| Textura de cuadros clásicos | [painting_canvas.gd](scenes/museum/painting_canvas.gd), [canvases.gd](scenes/canvases.gd) | Generador de las seis familias clásicas y catálogo/selección de imágenes dibujadas y otros temas. |
| Movimiento y acciones del ninja | [sim.gd](logic/sim.gd), [thief.gd](logic/thief.gd), [roll.gd](logic/roll.gd), [night_loop.gd](scenes/night_loop.gd) | Reglas de movimiento, estado del ninja, voltereta y orden de simulación. |
| Robo, alarmas y pieza robada | [heist.gd](logic/heist.gd), [loot_gen.gd](logic/loot_gen.gd), [loot_models.gd](scenes/loot_models.gd) | Estado del golpe, datos de la pieza y su modelo. |
| Comportamiento de guardias | [guard.gd](logic/guard.gd), [watch.gd](logic/watch.gd), [hearing.gd](logic/hearing.gd), [mind.gd](logic/mind.gd), [brain_client.gd](scenes/brain_client.gd) | Estado, vista, oído, decisiones de reserva y conexión HTTP al cerebro. |
| Cámara e iluminación general | [camera_rig.gd](scenes/camera_rig.gd), [night_env.gd](scenes/night_env.gd), [scenery.gd](scenes/scenery.gd) | Seguimiento, ambiente y luces/figuras de la ronda. |
| Personajes y objetos físicos | [figure.gd](scenes/figure.gd), [props.gd](logic/props.gd), [props_view.gd](scenes/props_view.gd) | Animación del personaje, reglas de objetos y cuerpos/modelos físicos. |
| Mensajes sobre el juego | [hud.gd](scenes/hud.gd), [prompt.gd](scenes/prompt.gd), [minigame_box.gd](scenes/minigame_box.gd) | Interfaz general, ayudas sobre cada ninja y panel flotante de minijuego. |
| Dibujar el mapa y su leyenda | [map_painter.gd](scenes/ui/maps/map_painter.gd), [map_overlay.gd](scenes/ui/maps/map_overlay.gd) | Píxeles del plano e iconos; presentación del mapa plegado, leyenda y visibilidad de retratos. |
| Construir menús | [menu_items.gd](scenes/ui/menus/menu_items.gd), [menu_widgets.gd](scenes/ui/menus/menu_widgets.gd) | Elementos/tablas/listas y estilos/botones/tarjetas. Hud conserva estado y navegación de pantalla. |
| Editar capacidades de guardias | [guard_panel.gd](scenes/editor/guard_panel.gd) | Arquetipo, vista/oído/velocidad, puesto, vigilancia y orientación del mismo GuardSpawn del mapa. |
| Estilo e iconos del editor | [widgets.gd](scenes/editor/widgets.gd) | Botones, etiquetas, paletas, miniaturas de salas e indicadores de nivel/dirección. |
| Qué acción se ofrece al jugador | [player_interactions.gd](scenes/gameplay/player_interactions.gd) | Prioridad de objetos cercanos, texto de ayuda y posición de los paneles sobre cada ninja. Guarda los paneles reutilizados y la entrada del fotograma anterior. |
| Minijuegos de vitrinas | [minigame.gd](logic/minigame.gd), [logic/minigames/](logic/minigames/), [scenes/minigame_views/](scenes/minigame_views/) | Contrato común, reglas específicas y vistas específicas. |
| Sonido y megafonía | [sfx.gd](scenes/sfx.gd), [megaphone.gd](logic/megaphone.gd), [megaphone_run.gd](scenes/megaphone_run.gd), [mega_voice.gd](scenes/mega_voice.gd) | Efectos/música, selección de frases, integración con la partida y reproducción de voces. |

## Tres recorridos para entender las llamadas

**Entrar en la guarida:** `Hub` atiende la tarjeta → `Game._dojo_start()` elige el
salón → `Game._new_round()` pide a `HouseRun` preparar su `HomeSpace` →
`Practice.map()` construye el plano jugable → `Scenery.build()` añade la escena
al mundo. Al cruzar un portal, `HouseRun.enter_space()` hace el mismo recorrido
con la escena de destino. Las tres zonas reutilizan el dibujo de `DenView`.

**Preparar un robo:** las pantallas de historia/generativo/retos seleccionan los
datos → `Game._new_round()` prepara mapa y personajes → `Scenery` crea lo visual
→ al empezar, `NightLoop` actualiza reglas y `Game` coordina el dibujo y la interfaz.
`Museum` guarda el plano activo, incluso cuando ese plano es una zona de casa.

**Pulsar una acción:** `Hands` interpreta el dispositivo del jugador → la
simulación recibe sus controles → se resuelve qué acción hay disponible junto
al ninja → `NightLoop` aplica el resultado. El mensaje de `Prompt` debe anunciar
la misma acción que se ejecuta, no una segunda versión independiente de la regla.

## Datos que se guardan

- [Settings](logic/settings.gd): `user://settings.cfg`; en pruebas sin ventana
  usa `user://headless_settings.cfg`.
- [Story](logic/story.gd): `user://progress.cfg`, con progreso por tamaño de banda.
- [MapFile](logic/map_file.gd): mapas del jugador en `user://maps`; los mapas de
  historia del proyecto se distinguen de las copias del jugador.

Desde Godot puedes abrir la carpeta real de `user://` mediante **Proyecto →
Abrir carpeta de datos de usuario**. Para pruebas aisladas existen argumentos
como `--save=...` y `--settings=...`, gestionados por
[launch_args.gd](scenes/launch_args.gd) y `Settings`.

## Cambiar algo y comprobarlo

Empieza por el archivo que posee la responsabilidad, no por una función parecida
en otra pantalla. Conserva la separación entre regla (`logic/`) y dibujo
(`scenes/`). Si varias pantallas necesitan la misma regla, llama a esa regla
compartida; si solo comparten apariencia, comparte el componente visual.

Antes de dar un cambio por terminado, ejecuta las pruebas relacionadas desde la
raíz del proyecto:

```bash
tests/run_all.sh home_spaces dojo_card pruebas  # casa y dojo
tests/run_all.sh menus controles menu_clarity  # interfaz y entrada
tests/run_all.sh collection fronts             # objetos del museo
tests/run_all.sh editor_components             # vista 3D y mando del editor
tests/run_all.sh nature_decoration             # geometría y semilla de naturaleza
tests/run_all.sh mapfile mapgen                 # datos de mapas
tests/run_all.sh map_controls                  # plano HUD y controles del juego
tests/run_all.sh                               # suite completa
```

[tests/run_all.sh](tests/run_all.sh) elige Godot, ejecuta pruebas sin ventana y
deja un log por prueba. Si Godot está en otra ruta, usa
`GODOT=/ruta/al/ejecutable tests/run_all.sh ...`. Se comprueba el código de salida
y el resumen del test; puede haber avisos del motor en un log correcto.

Un refactor debe conservar entradas, resultados, orden de llamadas, recursos y
cachés. Dividir un archivo no obliga a crear más nodos ni a añadir trabajo en cada
fotograma. Las fachadas pequeñas permiten mover una responsabilidad sin cambiar
a todos sus consumidores de golpe.

## Cómo se están separando los archivos grandes

La primera fase separó seis responsabilidades; la segunda añade trece archivos
por dominio, reduciendo todos los scripts que superaban 2.000 líneas. `Game._action_for()` y `_prompt_rows()` delegan en `PlayerInteractions`;
`NightLoop` puede seguir llamando a las mismas funciones. Los paneles de ayuda,
paneles de minijuego y memoria de controles pasan al componente. Este no crea un
nodo controlador nuevo: recibe `Game` y reutiliza los mismos nodos visuales.

`MuseumView.arcade_game()` y `_canvas()` también quedan como entradas cortas que
delegan en `ArcadeAppearance.apply()` y `PaintingCanvas.texture()`. Así `DenView`,
`Canvases` y las pruebas conservan sus llamadas. El catálogo de recreativas solo
existe una vez: `MuseumView.ARCADE_GAMES` referencia al del componente. Los
materiales y texturas permanecen en una caché compartida; no se recalculan por
cada copia de una máquina. El generador de cuadros mantiene la semilla y el hash
visual originales.

`MapEditor` delega la vista 3D en `EditorPreview3D` y el mando en
`EditorPadNavigation`. Conserva el mapa, las herramientas y el estado de entrada
y cámara para que sus paneles y ambos componentes lean los mismos valores.
`_process()` mantiene el orden: comprobar foco, mover cursor y actualizar cámara.
Las entradas de Godot y las funciones públicas del editor quedan como llamadas
cortas a los componentes. No hay una segunda implementación de pintar o deshacer.

La prueba [editor_components](tests/test_editor_components.gd) pasó antes y
después de mover ese código con las mismas comprobaciones: cámara restaurada,
transición 2D/3D, copia del mapa al reconstruir, rechazo del mapa inválido y
acciones de mando en el catálogo y trazos. No requiere un mando conectado; los
ejes físicos sostenidos aún necesitan comprobación manual con un dispositivo.

`MuseumBuilding` conserva la estructura del edificio y delega la decoración de
naturaleza en `NatureDecoration`. Las jardineras y la cubierta reciben la misma
instancia de `RandomNumberGenerator`, en el mismo orden: no se crea otro
generador ni se cambia su semilla. Las plantas siguen agrupándose en los mismos
`MultiMesh`, que dibujan muchas copias con pocas llamadas; las cachés de mallas
y materiales tienen un solo propietario en el componente. Los ayudantes de
geometría del edificio se reutilizan mediante sus entradas existentes.

[nature_decoration](tests/test_nature_decoration.gd) compara con un registro
capturado antes de la extracción: edificio abierto/cerrado, tres semillas para
las decoraciones, mallas, transformaciones, colores e instancias de plantas.
También compara el estado final del generador aleatorio compartido. Esta prueba
comprueba la equivalencia de la construcción, sin necesitar capturas.

La segunda fase divide el HUD en dibujo de mapas (`MapPainter`), presentación y
leyenda (`MapOverlay`), elementos compuestos de menú (`MenuItems`) y botones/
tarjetas (`MenuWidgets`). La paleta y el estado de pantalla siguen en `Hud`; el
caché de glifos tiene un único propietario en `MenuWidgets`. Las mismas funciones
públicas de `Hud` delegan sin cambiar a sus consumidores.

En el editor, `EditorWidgets` construye la interfaz y sus iconos;
`EditorGuardPanel` construye el panel y aplica sus acciones sobre el guardia
seleccionado. El mapa, el historial y la selección permanecen en `MapEditor`.
No hay otro guardia ni otra copia de reglas de edición en estos componentes.

Las fachadas de los museos se construyen ahora en
[prehistory_building.gd](scenes/museum/buildings/prehistory_building.gd),
[antiquity_building.gd](scenes/museum/buildings/antiquity_building.gd),
[contemporary_building.gd](scenes/museum/buildings/contemporary_building.gd) y
[middle_ages_building.gd](scenes/museum/buildings/middle_ages_building.gd).
`MuseumBuilding` sigue coordinando ventanas, selección, cámaras y animación; los
constructores comparten sus ayudantes, materiales y generadores aleatorios.
La torre de naturaleza conserva su estructura allí y su jardín en `NatureDecoration`.

`TownBuilder` conserva el plano, los distritos y el estado de construcción.
[terrain.gd](scenes/city/town/terrain.gd) se ocupa del terreno, río y rocas;
[vegetation.gd](scenes/city/town/vegetation.gd), de plantas y sus mallas;
[places.gd](scenes/city/town/places.gd), de casas dispersas, paseo, deporte,
centro comercial y parque. Reciben el mismo constructor como `host`, sin otro
estado aleatorio ni cachés duplicadas.

[hud_map_components](tests/test_hud_map_components.gd) comprueba píxeles de planos
y leyendas contra la versión anterior;
[hud_menu_components](tests/test_hud_menu_components.gd) comprueba estados,
enlaces, callbacks y cachés;
[editor_guard_panel](tests/test_editor_guard_panel.gd), la edición del guardia y
sus controles. Las pruebas de edificios y ciudad están en
[building_components](tests/test_building_components.gd) y
[town_components](tests/test_town_components.gd), con registros anteriores a la
extracción para comprobar geometría y comportamiento determinista.

### Tamaño de las dos fases

Se cuentan exclusivamente scripts `.gd` activos de `logic/` y `scenes/`, de forma
recursiva. Se excluyen pruebas, herramientas, assets, archivos `.uid`, importados
y código archivado. Las líneas incluyen comentarios y líneas vacías. «Antes» es
el estado tras separar las escenas de casa y antes de esta reorganización.

| Métrica | Antes de reorganizar | Tras fase 1 | Tras fase 2 |
| --- | ---: | ---: | ---: |
| Archivos de código | 119 | 125 | 138 |
| Líneas de código en total | 45.571 | 45.786 | 46.440 |
| Mayor archivo | `museum_building.gd`: 2.946 | `hud.gd`: 2.683 | `map_editor.gd`: 1.951 |
| `museum_building.gd` | 2.946 | 2.638 | 1.193 |
| `hud.gd` | 2.683 | 2.683 | 1.824 |
| `town_builder.gd` | 2.505 | 2.505 | 1.726 |
| `map_editor.gd` | 2.630 | 2.282 | 1.951 |
| `museum_view.gd` | 1.637 | 1.368 | 1.368 |
| `main.gd` | 1.584 | 1.450 | 1.450 |

El total aumenta por los comentarios, entradas compatibles y definición de los
componentes. Las funciones se han trasladado, no duplicado. La siguiente división
de los archivos que siguen siendo grandes debe hacerse por partes que
se puedan comprender y comprobar de forma independiente:

| Archivo | Responsabilidades que conviene separar después | Comprobación relevante |
| --- | --- | --- |
| [hud.gd](scenes/hud.gd) | Megafonía visual, monitor de pausa y mensajes de partida; mapas y construcción de menús ya separados. | `hud_menu_components`, `hud_map_components`, `menus`, `map_controls` y revisión visual puntual. |
| [map_editor.gd](scenes/map_editor.gd) | Catálogo, panel de guardado y herramientas del plano. Widgets, guardias, vista 3D y mando ya separados. | `editor_guard_panel`, `editor_components`; `mapfile` y `mapgen` para datos. |
| [museum_building.gd](scenes/museum_building.gd) | Estructura de la torre de naturaleza y ayudantes comunes. Cuatro estilos y decoración de naturaleza ya separados. | `building_components`, `nature_decoration`; `ciudad_nav`/`camara_museo` para navegación. |
| [town_builder.gd](scenes/town_builder.gd) | Plano de distritos, calles y edificios de barrio. Terreno, vegetación y zonas dispersas ya separados. | `town_components`, `ciudad_nav`, `camara_museo` y comparación de una misma semilla. |
| [den_view.gd](scenes/den_view.gd) | Trofeos, mobiliario, decoración del dojo y puertas/visibilidad. Mantener el constructor común para las escenas de casa. | `home_spaces`, `escondite`, `pruebas`, `dojo_card`. |
| [main.gd](scenes/main.gd) | Navegación de pantallas, preparación de rondas y finales. Reducir el coordinador sin repartir copias del estado de partida. | `menus`, `transiciones`, `finales`, `heist`, `home_spaces`. |

Son pasos futuros, no componentes que ya existan. Una carpeta nueva debe agrupar
un tema claro (`scenes/editor/`, `scenes/city/`, `scenes/ui/`, por ejemplo), y cada
archivo debe tener una responsabilidad reconocible. No hace falta crear una
clase por cada función de dos líneas. Al completar una división, actualiza esta
guía y los comentarios de los consumidores para que indiquen su nuevo propietario.

### Los 20 scripts más grandes: recuento final

El recuento final incluye también el módulo `logic/missions.gd` y sus
consumidores: 139 scripts y 46.551 líneas. La tabla de fases anterior mide
la reorganización por separado. El mayor archivo sigue teniendo 1.951 líneas.

| Archivo | Líneas |
| --- | ---: |
| [scenes/map_editor.gd](scenes/map_editor.gd) | 1.951 |
| [scenes/hud.gd](scenes/hud.gd) | 1.824 |
| [scenes/town_builder.gd](scenes/town_builder.gd) | 1.726 |
| [scenes/den_view.gd](scenes/den_view.gd) | 1.694 |
| [logic/sim.gd](logic/sim.gd) | 1.502 |
| [scenes/main.gd](scenes/main.gd) | 1.457 |
| [scenes/museum_view.gd](scenes/museum_view.gd) | 1.368 |
| [scenes/city_stage.gd](scenes/city_stage.gd) | 1.351 |
| [scenes/museum_building.gd](scenes/museum_building.gd) | 1.193 |
| [logic/mapgen.gd](logic/mapgen.gd) | 1.150 |
| [logic/map_file.gd](logic/map_file.gd) | 918 |
| [scenes/plan_talk.gd](scenes/plan_talk.gd) | 887 |
| [scenes/sfx.gd](scenes/sfx.gd) | 862 |
| [scenes/lesson_stage.gd](scenes/lesson_stage.gd) | 823 |
| [logic/museum.gd](logic/museum.gd) | 817 |
| [scenes/tour.gd](scenes/tour.gd) | 812 |
| [logic/den.gd](logic/den.gd) | 757 |
| [scenes/scenery.gd](scenes/scenery.gd) | 741 |
| [scenes/museum/buildings/middle_ages_building.gd](scenes/museum/buildings/middle_ages_building.gd) | 667 |
| [scenes/end_pages.gd](scenes/end_pages.gd) | 589 |
