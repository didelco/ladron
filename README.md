# Ninja Karma

Un museo cerrado de noche, vigilantes que piensan con [Laya](https://huggingface.co/convaiinnovations/laya) y tú.

Port a **Godot 4.7** (escritorio: Windows, macOS y Linux) del MVP web, que queda congelado en
[`didelco/ladron-threejs`](https://github.com/didelco/ladron-threejs) (etiqueta `web-ref`).

Regla general: **simplificar**. Se porta la lógica tal cual; las mejoras, después.

```
logic/   lógica pura, sin nodos (GDScript con tipos): se prueba sola
scenes/  lo visual: main (`Game`, el nodo raíz: estado, pantallas hasta la noche y orden del
         fotograma), museum_view (museo), figure (personajes), y lo que habla con fuera
         (brain_client, el cliente HTTP del cerebro). `main.gd` reparte el trabajo en
         controladores hijos, cada uno una clase con una cara corta que guarda la referencia
         a `Game` (`host`): night_loop (el bucle de la noche: `tick` en fases), scenery (el mundo
         3D de la ronda: se construye y se dibuja), night_env (Environment, luna, cámara y oídos),
         camera_rig (seguir, alejar, temblar), hands (asientos, teclas y mandos por jugador,
         vibración, glifos), megaphone_run (la megafonía en juego), house_run (la casa de la
         banda: salas a la vista, espantapájaros, banco de pruebas y juegos del dojo),
         settings_screens (ajustes y assets), challenge_screens (retos y editor), brief_screens
         (prólogo y ficha de la noche), preview_stand (la peana de las piezas) y launch_args
         (las opciones `--menu=…` y compañía). Otros scripts de escena ya eran así: plan_talk,
         tour, end_pages, menu_stage, city_stage.
brain/   el cerebro: FastAPI sobre Laya, igual que en la web
tests/   pruebas sin ventana
art/     el catálogo en Blender (.blend por grupos) y su exportador a assets/models
```

## Piezas modeladas

Lo que tiene forma fija se modela en Blender y el juego carga el `.glb`
de `assets/models/` con su sombreado toon (`MuseumView.asset`): vitrina (una para todas; el código
pone dentro lo que toque), papelera, pedestal y lo que va encima (cuatro bustos, una regadera y un
váter), panel, armadura (por piezas, para que se desmonte al caer), cráneo y cabeza de Lego, ánfora,
globo, tótem, oso de pie, amonite y meteorito. Dos piezas ocupan varias casillas y las reserva el
generador (`MapGen.BIG`): el esqueleto de dinosaurio (2×3) y el sarcófago (3×1).
Lo que depende del mapa o de la semilla sigue en código: muros, suelo, plintos, mariposas,
minerales, dioramas, cuadros (paisaje, retrato, abstracto, pipa, plátano, helado), la lámina de
cada panel y las luces.

### El catálogo en Blender

Las piezas están agrupadas en pocos ficheros; dentro, cada pieza es una colección, en fila y con
su nombre escrito delante, y sale a su propio `.glb`:

| Fichero | Qué hay | Sale a |
|---|---|---|
| `art/museo.blend` | el mobiliario: vitrina, pedestal, panel, papelera | `assets/models/` |
| `art/coleccion.blend` | bustos, regadera, váter, cráneos, ánfora, globo, tótem, amonite, meteorito, oso, armadura, sarcófago, dinosaurio | `assets/models/` |
| `art/tema_antiguo.blend` | las piezas del tema antiguo (Egipto) | `assets/models/temas/antiguo/` |
| `art/tema_edad_media.blend` | las piezas de la Edad Media | `assets/models/temas/edad_media/` |
| `art/tema_moderna.blend` | la edad moderna: tele, tostadora, cubo de Rubik, perro-globo (peana); recreativa, móvil de Calder, semáforo (suelo); cochecito (grande, escondite); nevera y caja (escondites) | `assets/models/temas/moderna/` |
| `art/tema_prehistoria.blend`, `tema_naturaleza.blend` | los escondites de esos temas (huevo y mamut; caparazón y tronco hueco) | `assets/models/temas/<tema>/` |
| `art/botin.blend` | las piezas a robar: dentadura, pato, calcetín, tostada, corona, queso lunar, chicle, máscara, despertador, huevo, diamante, ídolo, bote de ketchup. Los materiales que empiezan por `color` toman el color de la pieza en el juego (`color_claro_N`, `color_oscuro_N`: un N % más claro u oscuro) | `assets/models/botin/` |
| `art/personajes/guardia.blend`, `ninja.blend` | un personaje con esqueleto y acciones cada uno | `assets/models/` |

Para retocar: abre el fichero, cambia la pieza **sin moverla de su sitio en la fila** (la colección
recuerda dónde está su origen) y exporta. Desde Blender, con el panel **Ladrón** de la barra lateral
(tecla `N`): *Exportar pieza* (la del objeto seleccionado), *Exportar fichero*, *Exportar todo*,
*Nueva pieza* y *Ordenar fila*; guarda, exporta y hace que Godot reimporte. Se instala una vez:
Preferencias → Add-ons → Instalar desde disco… → `art/ladron_addon.py`. Desde la terminal:

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P art/export.py                           # todo
$B -b -P art/export.py -- vitrina anubis         # esas piezas
$B -b -P art/export.py -- --godot tema_antiguo   # un fichero entero, y Godot reimporta
```

**Claude dentro de Blender** (`art/claude_addon.py`, se instala igual): pestaña *Claude* de la barra
lateral, un chat que va por Claude Code (la suscripción, sin clave de API). Con cada mensaje le llega
un resumen de la escena (y, si se marca, una captura del visor); si hay que cambiar algo, contesta con
código que se ejecuta ahí mismo como un solo paso (Ctrl+Z lo deshace; antes guarda una copia en la
carpeta temporal). Si falla, *Pedir arreglo* le manda el error.

Una pieza nueva: *Nueva pieza* en el fichero que le toque (o una colección nueva), modelar con el
pie en z = 0 y el frente a -Y sobre el cursor, y exportar. Convenciones y nombres que busca el
juego: `art/catalogo.py`. Los scripts de `art/characters/` y `art/temas/` son cómo se hizo la
primera versión: volver a ejecutarlos pisa los retoques hechos a mano. Los escondites (nevera, caja, legionario, confesionario, baúl, huevo,
caparazón, caballo de Troya, mamut y tronco) salieron de `art/temas/escondites.py`. Las piezas de la edad moderna, de `art/temas/moderna.py`.

## Plan

1. ✅ **Esqueleto y generador**: primero idéntico a la web; después, generador propio: salas
   contiguas con al menos dos puertas, sin espacios cerrados ni pasillos sin salida.
2. ✅ **Jugable sin IA**: museo con cajas, ladrón, guardias, cámara y controles.
3. ✅ **Laya**: cliente HTTP a `brain/` (`POST /decide`, todos los guardias en una llamada);
   sin el servicio, reglas de reserva.
4. 🟡 **Aspecto** (primera versión hecha: figuras animadas con contorno y silueta a través de las
   vitrinas, suelo, muros, vitrinas, linternas, luces de sala y de emergencia; faltan cuadros y piezas
   del museo): figuras como en la web (encapsuladas en una escena `Figure` para cambiarlas por
   modelos con esqueleto más adelante), luces, conos de visión, suelo y muros.
5. ✅ **Juego completo**: atraco por niveles (pieza, alarma, puerta de salida), pantallas de título,
   misión, pausa y final, HUD con flecha al objetivo y el grito en grande, sonido sintetizado.
   La megafonía del museo (Megaphone) también habla: cada frase MEGA_* suena desde `audio/megafonia/<clave en minúsculas>.ogg` (`MegaVoice`, ajuste «Megafonía»: cartel y sonido, solo cartel, solo sonido o no; guardado como `megaphone_mode`, y los ajustes viejos `megaphone` y `megaphone_voice` se migran); los audios se generan con `megafonia-tool` (herramienta aparte del juego, en la carpeta hermana `../megafonia-tool`; ver su README) y, tras copiarlos, `godot --headless --import` los importa. Sin ficheros, el juego calla y sigue.
6. **Exportar** a Windows, macOS y Linux, y decidir cómo va Laya para jugadores.

## Pruebas

Todas de golpe (recorre `tests/test_*.gd`, 4 a la vez, con un log por test; sale con código distinto de 0 si algo falla):

```bash
tests/run_all.sh              # todos
tests/run_all.sh sim heist    # solo algunos
GODOT=/ruta/a/godot tests/run_all.sh   # otra ruta de Godot (por defecto la de macOS)
```

El criterio es el código de salida más la línea de resumen (`FALLOS: 0`, `0 fallos`, `OK:`), no buscar «error» en el log: en headless hay ruido conocido. `test_escondite` se reintenta una vez. Un test nuevo entra solo si se llama `tests/test_*.gd`; en GitHub Actions lo corre `.github/workflows/tests.yml` en cada PR. Uno a uno:

```bash
godot --headless --script tests/test_mapgen.gd   # museos bien formados (306 de todos los tamaños y formas)
godot --headless --script tests/test_sim.gd      # escenarios de la simulación
godot --headless --script tests/test_heist.gd    # el golpe, el cuadro de alarma y los 25 robos de la historia (salas y grandes golpes)
godot --headless --script tests/test_mapfile.gd  # mapas guardados: ida y vuelta, validación y que se juegan
godot --headless --script tests/test_story.gd    # la historia: cinco museos de un tema, cinco robos cada uno, progreso por jugadores (y el de 20 noches)
godot --headless --script tests/test_roll.gd     # rodar: ocho casillas, bajo y callado; limpia o contra la pared (golpe y estrellas)
godot --headless --script tests/test_plinths.gd  # pedestales: subir con la acción, estatua invisible, bajar con una dirección
godot --headless --script tests/test_hideouts.gd # escondites: todo lo que lo parece lo es, pocos y separados; invisible dentro, el guardia que te ve entrar va a por ti
godot --headless --script tests/test_collection.gd # qué hay en cada vitrina: las piezas únicas una vez, cada recreativa un juego distinto, igual siempre
godot --headless --script tests/test_fronts.gd    # piezas con frente (recreativa, trono, Anubis, la nevera...): nunca contra una pared
godot --headless --script tests/test_controles.gd # teclas y botones: partida, menús y elegir sitio
godot --headless --script tests/test_menus.gd     # aceptar (E, ., A) y atrás (Esc, Espacio, Enter, B) iguales en todas las pantallas con menú; SALIR DEL JUEGO en la pausa (última, pide confirmar, cancelar vuelve a la pausa, no está en el dojo)
godot --headless --script tests/test_ciudad_nav.gd # moverse por la ciudad: una sola regla, la dirección pulsada (teclas, cruceta, stick en cualquier ángulo) lleva a la parada que está ahí en la pantalla; ratón por encima y clic; flechas y aros hacia los vecinos
godot --headless --script tests/test_calidad.gd   # calidad Alta/Baja y escala 3D: valores por defecto, validación, Baja apaga SSR, SSIL, SSAO, niebla y humo, Alta lo deja como estaba
godot --headless --script tests/test_siguiente.gd # sobre el plano, solo SIGUIENTE: el encargo, lo nuevo y las reglas de cada noche, cada cosa desde su sitio
godot --headless --script tests/test_megafonia.gd # megafonía del museo (Megaphone): avisos de una frase por suceso y por lo que hace el ladrón (voltereta y pared, papelera, escondite...), muy escasos (calla los primeros 20-60 s, 40 s entre avisos y 15 s los de peligro, tope de 2 a 5 por robo), comentarios pronto pero solo a veces (probabilidad por acción), escalado por repetición y rachas, ninguna frase repetida ni en el robo siguiente, sin guardias en el robo 1, claves del CSV y ajuste
godot --headless --script tests/test_megafonia_voz.gd # voz de la megafonía (MegaVoice): ruta desde la clave, sin fichero calla, modos del ajuste (cartel y sonido, solo cartel, solo sonido, no), migración de los ajustes viejos y práctica, salir la corta, un .ogg por frase (aviso mientras la carpeta esté vacía)
godot --headless --script tests/test_textos.gd # textos: ninguna clave que pide el código (literales, tablas y las armadas con prefijo o número) se queda sin texto en la traducción cargada, filas del CSV bien formadas y sin repetir, y los %s/%d de cada Text.t("…") % … cuadran con lo que se pasa (si falla por la traducción: godot --headless --import)
godot --headless --script tests/test_procedencia.gd # procedencia de los assets: cada fichero de assets/, audio/ y art/ tiene regla en assets/PROCEDENCIA.json y toda licencia declarada está en la lista de permitidas (lo mismo que `python3 tools/procedencia.py`)
godot --headless --script tests/test_dojo_juegos.gd # los cuatro juegos del dojo (lógica y vista): niveles, eventos, récords por banda, panel de fin
godot --headless --script tests/test_escondite.gd # El Escondite del Calcetín: la casa de la banda (orientación de cada mueble auditada, recreativa jugable, dojo grande con zonas, pasillos de dos, espantapájaros y alarma roja solo en el dojo, 12 objetos del banco (cuatro pruebas por tres dificultades, en su sitio y alcanzables) con rearme, sin calcetines fuera de PILLA EL CALCETÍN, cuatro salas alcanzables, puertas que bloquean o dejan pasar y que no se cierran con alguien en el umbral, salas a oscuras según lo visible por puertas abiertas con 1 a 4 ladrones, dojo según lo desbloqueado, 25 puestos de trofeos que se llenan con el botín por tamaño de banda, sin cuenta atrás al entrar, salir por pausa y por la puerta, música; puntos de inicio de los juegos del dojo (calcetín, círculo, pedestal, armadura) que empiezan a su dificultad, no se repiten y abortan (pausa, Tab) sin tocar más que `[dojo]`; sin guardias ni guardado)
godot --headless --script tests/test_smoke.gd     # bomba de humo: dos por ladrón, tapa la vista, despista al que persigue
godot --headless --script tests/test_brain.gd    # decisiones reales de Laya (necesita el cerebro)
python3 tools/ciclos.py -v --estricto            # ciclos de dependencia entre los scripts de logic/ (sale con 1 si hay uno sin permitir)
python3 tools/tamanos.py -v --estricto           # ficheros de más de 1.500 líneas y funciones de más de 80 (límite blando; sale con 1 si hay uno nuevo o una excepción que crece)
```

`tests/visual/figures.tscn` enseña de cerca al ladrón y al guardia con sus animaciones, y
`tests/visual/assets.tscn` todas las piezas modeladas.

En macOS, `godot` es `/Applications/Godot.app/Contents/MacOS/Godot`.

## Documentación

`docs/index.html` enseña el estilo y las decisiones gráficas (`docs/ESTILO.md`, lo único escrito a
mano), la paleta completa, capturas de cada pantalla, todos los assets (piezas, objetos, modelos 3D y
sonidos) y todos los textos, con la historia en orden. Todo sale del propio juego:

```bash
python3 tools/docs.py build          # lo regenera todo (abre una ventana del juego unos minutos)
python3 tools/docs.py build --fast   # solo datos, textos y paleta propuesta
python3 tools/docs.py build city     # solo la ciudad: el mapa entero y cada museo
python3 tools/docs.py serve          # http://localhost:8765: además, los textos se editan ahí
```

Editar un texto en el visor lo cambia en `locale/texts.csv` (solo esa fila) y Godot lo reimporta.

**Referencias**: la página «Referencias» (grupo Referencia) guarda enlaces de inspiración y recursos que se
van encontrando, con buscador y filtros por tipo, etiqueta y estado. Se añaden de dos maneras:

- A mano, en `docs/data/referencias.json`: una lista de `{id, titulo, url, tipo, etiquetas, licencia, nota,
  fecha, estado}`. El `tipo` es `icons`, `modelos`, `audio`, `arte`, `codigo`, `articulo` u `otro`; el
  `estado`, `guardada`, `evaluada`, `usada` o `descartada`; la `fecha`, `AAAA-MM-DD`. Luego
  `python3 tools/docs.py texts` regenera `docs/data/referencias.js`, que es lo que lee el visor.
- Desde el visor con `python3 tools/docs.py serve`: el formulario «Añadir referencia» (enlace, título
  opcional, tipo, etiquetas, licencia y nota) y, en cada referencia, un selector de estado y «Borrar». Solo
  se toca `docs/data/referencias.json`. Sin servidor, la página es de solo lectura.

`python3 tools/procedencia.py` (y `tests/test_procedencia.gd`) comprueba el fichero: campos obligatorios,
URL http(s), ids únicos, tipos y estados válidos. Si una referencia comparte dominio con una colección de
Procedencia o con una de sus alternativas, las dos páginas se enlazan.

Además de pantallas, objetos, sonidos y textos, la web explica la historia (con el paso del progreso
guardado de 20 noches), la ciudad (el mapa entero, que en el juego nunca cabe en la pantalla, con un
marcador por museo, y cada museo en su manzana), lo que sale antes de un robo, los minijuegos, los escondites y la colección:
los valores, listas y textos salen del código (`docs/data/codigo.js`, `juego.js`) y lo que significan
está escrito a mano en `docs/mecanicas.js`. `python3 tools/docs.py build palette` regenera sin Godot
la **paleta propuesta** (`tools/palette.py`): el inventario de colores del código y de los `.glb`, y una
propuesta de 16 colores, **pendiente de aprobar**: no está aplicada al juego.

**Versiones**: la página «Versiones» enseña, por asunto (fondo de los menús, menús, icono, historia,
recreativa…), los hitos de cómo se veía y cómo se ve, con cortina antes/después. Se guardan en
`docs/versiones/<asunto>/<fecha>-<nombre>.webp` y se apuntan en `docs/versiones/versiones.json`. Solo
hitos: un cambio muy visible, o una versión antigua cuando algo ha ido cambiando poco a poco y ya se
parece poco al principio; nada se guarda solo. Mejor el mismo encuadre en todo un asunto.

```bash
python3 tools/docs.py version fondo-menus "La sala del museo" --why "…" --what "…"   # la imagen de siempre del asunto
python3 tools/docs.py version menus "Cristal ahumado" --from menu_titulo             # una captura de docs/capturas
python3 tools/docs.py version icono "Pixel art" --from assets/icon.png --commit ed1b2ac   # de un commit antiguo
python3 tools/docs.py version --list
```

**Alternativas de terceros**: para sustituir lo hecho con IA (modelos, sonidos, voz, ilustraciones…)
por algo de terceros con licencia libre, se apuntan en `docs/data/alternativas/<categoria>.json`
(plantilla en `_ejemplo.json`: `categoria` y `grupos` con `coleccion` de `assets/PROCEDENCIA.json`,
`que_es` y `alternativas` con `id`, `nombre`, `url`, `autor`, `licencia`, `atribucion`, `cubre`,
`encaje` 1-5 y, si quieres, `preview_url` y `notas`; un grupo con `id` propio permite varios por
colección). `python3 tools/procedencia.py` y `tests/test_procedencia.gd` los validan. En la página
«Procedencia» las colecciones con alternativa llevan el distintivo «Tiene alternativa», y con
`python3 tools/docs.py serve` se elige una (o «la nuestra») por grupo; la elección queda en
`docs/data/alternativas_elegidas.json` y arriba se ve lo pendiente de sustituir.

Las capturas lanzan Godot sin el dispositivo HID de Apple que algunos Mac enseñan como mando
(`SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004`, lo pone `docs.py`).

## Controles

En el título se elige el modo:

- **Historia**: robar cinco museos, cinco salas en cada uno: 25 robos fijos, de muy fácil (un
  museo pequeño sin guardias) a difícil (cuatro guardias en uno grande). El Barón Von Bostezo se
  ha quedado con los cinco museos de la ciudad y la Banda del Calcetín rescata sus obras
  (`logic/story.gd`). Cada museo es de un tema (`logic/themes.gd`), con sus colores de pared y
  suelo, y todo lo que enseña y se roba es de ese tema: el Museo de la Prehistoria (prehistoria),
  el Museo de Ciencias Naturales (naturaleza), la Villa de las Antigüedades (mundo antiguo), el
  Museo del Castillo (Edad Media y Renacimiento) y el Museo de Arte Contemporáneo (edad moderna). Las cuatro primeras salas son robos normales;
  la quinta, el **gran golpe** del museo, con algo especial (un guardián que ve lejos, un guardia
  pegado a la pieza, tres guardias, la sala del trono, el gran final); al hacerlo se abre el
  siguiente museo. Primero se elige cuántos ladrones; luego, en el mapa de la ciudad, un museo y
  dentro una de sus salas. En la ciudad hay una sola regla: la flecha, WASD, la cruceta o el stick (en cualquier ángulo) llevan a la parada abierta
  (museos y casita) que queda en esa dirección **de la pantalla** (`Tour.toward`), igual con teclado y mando; con el ratón,
  pasar por encima la elige y el clic entra. Sobre la parada elegida, un aro en cada parada a la que se puede ir y una flecha
  hacia ella. Sin botones de ruta: LB/RB solo cambian de sala dentro del museo. El progreso se guarda aparte para cada número de jugadores y se puede
  rejugar cualquier robo ya alcanzado; una partida de la historia de 20 noches se conserva
  (museo hecho, museo hecho; las noches del museo a medias, salas hechas).
- **Generativo**: un museo nuevo cada vez, con dificultad (fácil, media, difícil) y tamaño a elegir.
  Cada golpe trae su pieza y su historia, inventadas a partir de la semilla (`logic/loot_gen.gd`):
  algo que el Barón le quitó a alguien del pueblo.
- **Retos**: mapas hechos a mano, los de serie (`maps/`) y los tuyos (`user://maps/*.json`,
  `logic/map_file.gd`). Desde ahí se abre el **editor** (`scenes/map_editor.gd`): pintar suelo,
  muro, vitrina o exterior, poner salas hechas (galería, vitrinas, pedestales, columnas,
  dinosaurio...), la entrada, la pieza, la salida, guardias y objetos, o partir de un mapa
  aleatorio del generador; tamaño, dificultad y guardias; vista 3D, probar y guardar. Solo deja
  jugar mapas cerrados, sin espacios a los que no se llega, con pieza y salida alcanzables.
  `-- --menu=challenges` (o `editor`) los abre directamente. La pantalla es una lista (los robos
  de la historia, luego los retos) con el plano del que está elegido a la derecha.
  Los **robos de la historia** también se retocan ahí: se abre el museo tal como lo monta el
  robo (`MapFile.from_museum`), se edita y se guarda en `maps/historia/noche_NN.json` (en
  `user://maps/historia/` si el juego está exportado); desde entonces el robo juega ese museo,
  con su pieza, sus guardias y su dificultad de siempre. *Volver al original* borra el fichero.
  Probar un robo desde el editor no cuenta como partida de la historia.

Antes de cada golpe, el plan: el mapa a la izquierda y, a la derecha, la pieza, su historia y
consejos sacados de cómo es la noche (`logic/briefing.gd`: cuántos guardias, si son rápidos u
oyen bien, qué tiene de especial un gran golpe, la alarma de la vitrina, qué se puede tirar...).

En los dos, uno o dos ladrones. Con dos hay que colaborar: la vitrina solo cede mientras el otro
sujeta el **cuadro de la alarma** (naranja, en una pared lejos de la pieza), y así se abre sin que
suene. Si pillan a uno, el que queda la fuerza solo, con alarma.

Por el museo hay papeleras, bustos en pedestal y paneles informativos (`logic/props.gd`): si
chocas con uno se cae (con física, `scenes/props_view.gd`) y hace ruido, y un guardia que lo vea
tirado sube su alarma y va a mirar.

Durante la partida, `M` (o View en el mando) saca el mapa: el plano, dónde estás, la pieza
y la salida, sin los guardias. Mientras lo miras no te mueves. `N` silencia el sonido. `P` (o Start) pausa. Junto a una papelera, un busto o un panel, `E`
(`.` para el segundo jugador con teclado, A en el mando) lo tira: hace ruido y los guardias van a
ver, lo que sirve para despistarlos. Junto al **interruptor** de una sala, la misma tecla apaga la luz si está encendida o la enciende si está apagada (`Sim.flip_switch`): hace un clic flojo y, si hay un guardia en esa sala, nota el cambio, sube su alarma y va a mirar el interruptor. Un guardia en alerta que vea el interruptor de una sala oscura volverá a encenderla. **Rodar** (`logic/roll.gd`): `Espacio` (`Enter` para el segundo,
B en el mando) te hace una bola y ruedas ocho casillas hacia donde miras (en 1,1 s, más rápido que
corriendo) y sin ruido de pasos; te ven igual que a gatas. No se puede girar ni parar
a medias. Si la rodada acaba libre, te quedas un momento a gatas y te levantas: 1,8 s en el suelo,
algo más que de gatas. Pero si ruedas contra una pared o una vitrina te paras en seco con un golpazo
que se oye por todo el museo (tanto como una armadura que se cae) y te quedas tumbado, mareado y
con estrellitas girando sobre la cabeza: 2,5 s, más 1 s para levantarte. Lo que pilles rodando se cae. Con varios
ladrones, cada uno ocupa su plaza pulsando un botón de su mando o una tecla de su lado del teclado
(WASD o flechas), como en Mario Kart 64; P1 es siempre turquesa y P2 naranja. En el teclado juegan
dos como mucho: el tercero y el cuarto, con mando. En
SETTINGS → CONTROLES: vibración y su fuerza, y zona muerta del stick.

SETTINGS (se guardan en `user://settings.cfg`): sonido (`N`), música, volumen de música y de efectos (0–100 %, `←`/`→`), pantalla completa, v-sync y panel de IA; también se recuerdan la dificultad y el tamaño del modo generativo. La música (sintetizada, de misterio) sube de tensión cuando los guardias están en alerta o te ven. Solo: WASD o flechas, `E` la acción, `Espacio` o `Enter` para rodar, `C` para ponerse a gatas, `Shift` para andar lento y `F` para la bomba de humo. Dos
jugadores: P1 con WASD, `E`, `Espacio`, `C`, el `Shift` izquierdo y `F`; P2 con flechas, `.`, `Enter`, la tecla de después del punto (`/` en un teclado inglés, `-` en uno español), el `Shift` derecho y `,`. `Esc` para la pausa (la última opción, SALIR DEL JUEGO, pregunta «¿SALIR DEL JUEGO?» con NO elegido, cierra sin guardar la noche en curso y no está en la casa de la banda, que sale por su puerta). El objetivo: robar
la pieza (quieto a su lado unos segundos, mires hacia donde mires) y salir por la puerta verde. Sin reloj: se tarda lo que se
quiera.

Con mando, como en la mayoría de juegos: stick izquierdo o cruceta para moverse, A (✕) la acción, B (○) para rodar
y soltar un minijuego, X (□) o clic del stick para ponerse a gatas, View para el mapa y Start para la
pausa; Y (△) suelta una bomba de humo. En los menús A acepta, B vuelve, LB/RB cambian de pestaña y Start
salta la historia y la previa. Así A y B significan lo mismo jugando que en los menús: A hace, B se aparta. Con el
teclado, igual (cada mitad es un mando): `E` y `.` aceptan, como la acción; `Espacio` y `Enter` vuelven, como rodar, y
`Esc` también; ninguna tecla acepta en una pantalla y vuelve en otra (`logic/menu_keys.gd`). Por los menús se mueve cada
uno con lo suyo, como jugando: WASD, flechas, stick o cruceta (`ui_up`… en `project.godot`). Solo, vale cualquier mando; con dos, el mando 1 es P1 y el
2 es P2 (el teclado sigue funcionando, así que un mando y teclado también). Vibra cuando te ven y
cuando tiras algo.

**Andar lento**: mientras mantienes `Shift` andas despacio, 1,2 casillas/s, sin
llegar nunca a correr, y tus pasos se oyen la mitad de lejos que andando a esa velocidad (un guardia
tranquilo lo oye a 1,1 casillas; andando normal, a 2,4–4,4, y corriendo, hasta 7,5). Te ven de pie, pero
no tienes que agacharte ni levantarte. P1 usa el `Shift` izquierdo y P2 el derecho (encima de las
flechas); solo, cualquiera de los dos. `Shift` mantenido para ir despacio es lo habitual en PC; `Ctrl`
no se usa porque en Mac choca con `Ctrl`+`Espacio` (cambiar de idioma del teclado) y `Ctrl`+flechas
(escritorios), ni `Cmd` por `Cmd`+`Q`. Godot no distingue los dos `Shift` al consultar el teclado, así
que `scenes/hands.gd` los sigue por `InputEventKey.location`. En el mando, mantener LB
o inclinar el stick poco (pasada la zona muerta, menos de la mitad de lo que queda hasta el borde).
**A gatas** se va a 1,5 casillas/s, algo más deprisa y sin ningún ruido, pero cuesta 1,5 s agacharse y
otro tanto levantarse.

Para grabar o probar sin pulsar teclas: `godot -- --autostart` salta directamente a la partida
(`-- --autostart --two` con dos ladrones), y `-- --intro` enseña el comienzo de la historia con la
cuenta atrás (`--two` para dos, `--gen` para el modo generativo, `--challenge` para el primer reto). `-- --menu=story` (o `map`, `museum`, `generative`, `settings`) abre ese menú directamente.

**El Escondite del Calcetín**: en la ciudad, en una manzana de la orilla de abajo, a la derecha junto al último museo y lejos del primero, está la casa de la banda (`CityStage.HIDEOUT_SPOT`). Se
elige con las flechas como un museo y se entra sin plano ni briefing. No es un nivel sino un lugar (`Den`, el
plano en datos; `DenView`, su dibujo; `Practice`, el modo "practica") con cuatro salas que se recorren
andando: el **salón** (sofás con cojines, alfombras, tele con altavoz, cocina con nevera y barra con taburetes, estantes de libros, mesitas con lámpara, planta, ventanas con cortinas, pósters, zapatero y perchero junto a la puerta de casa y una **recreativa** —el mismo mueble y el mismo pong de los museos, `Arcades.find_home`— contra la pared norte: delante de ella la acción es `JUGAR` (`HIDEOUT_ARCADE_PLAY`), sin estrellas ni progreso ni efecto en las puertas), la
**sala de trofeos** (un museo pequeño de la banda, `Den.stands`: 25 puestos vacíos desde el principio, cinco por
museo, cada sección con su rótulo y su alfombra en el color del museo; tres nichos en la pared y dos vitrinas en
el suelo por sección, con su placa —número del robo, «?» y, al robarla, sus ★—; un puesto se llena con la pieza
real, con un foco suave, cuando el robo se hizo con la pieza cogida, la estrella «botín», `Den.filled`, por
tamaño de banda; una estrella dorada, no un calcetín, sobre el rótulo del museo completado (y donde el botín de un robo es un calcetín, los puestos enseñan esa estrella); bancos, cuadros, felpudos y una mesita con lámpara), el **dojo** (un
pequeño museo de práctica de 37 × 13 casillas, unas 2,6 veces el de antes, con muros de papel de arroz —zócalo de madera, listones *shoji*, remate,
postes y ventanitas altas— y cinco zonas de fácil a difícil, `Den.DOJO_PLAN` y `Den.DOJO_ZONES`: la **exposición**, con pilares,
vitrinas bajas y el banco de vitrinas; el **pasillo** de dos casillas con un cruce; los **escondites**, una sala con armaduras, caja y taquilla; el
**laberinto** de tres vaivenes de dos casillas; y el **patio** con papeleras y cajas; escondites, patio y laberinto se enlazan en anillo con el pasillo.
Sin guardias: hay **espantapájaros** de guardia con una linterna pegada, que ven con la regla de los guardias y sus propios números
—`Practice.scarecrow_sees`, alcance 5,5 y ±24°—; si ven a un ladrón (no escondido) **todo el dojo se pone rojo con una sirena 3 s**
(`Practice.alert_step`, enfriamiento de 1,5 s) y no pasa nada más. Según el robo al que ha llegado la banda (museo · prueba, `Practice.ITEMS`): el espantapájaros del pasillo —«guard», 1 · 2—, el de los escondites y las tres armaduras de AGUANTA ESCONDIDO —«torch», 1 · 4—, las vitrinas de GANZÚA y los
pedestales de EQUILIBRIO y PILLA EL CALCETÍN —«games», 2 · 1—, papeleras, busto, caja, taquilla, escondites de ESCONDITE y círculos de BOLOS —«props», 2 · 3—, el primer espantapájaros del laberinto y las
cajas de alarma de CABLES —«case_alarm», 3 · 1— y el segundo, con las de PULSO —«two», 3 · 3—. **Nadie elige prueba ni dificultad**: cada cosa tiene **tres puntos de inicio fijos, uno por
dificultad** (fácil, medio, difícil; `HIDEOUT_TIER_*`), y se empieza acercándose y pulsando la acción, sin menús ni atriles.
**Banco de pruebas** (`Practice.bench_*`, en la exposición): cuatro pruebas con **tres objetos cada una**, uno por dificultad (12 en total según lo enseñado, en las casillas de `Practice.BENCH_AT`, cada uno con su rótulo y su dificultad; `Practice.BENCH_OBJECTS` es la tabla de qué objeto lleva cada prueba, y cambiarlo es cambiar una línea; los modelos, primitivas o piezas de la casa, están en `BenchProps`): GANZÚA, una vitrina vacía (sin calcetín: el calcetín es solo de PILLA EL CALCETÍN); ESCONDITE, un mueble de `Hideouts.PIECES` (nevera, caja y baúl, cada vez más justo, `Hideouts.TIGHT`) con el minijuego de colarse; CABLES, una caja de alarma en la pared este con 3, 4 o 6 cables colgando; PULSO, otra en la pared oeste con un cristal y un aro cada vez más pequeño. La acción junto a uno (`PROBAR`, por el mismo punto único `Game._action_for`, así que el filtro de «una prueba a la vez» lo cubre) lo hace con su minijuego al nivel de su fila (el mismo que en un robo); al acabar se enciende una luz verde y sube el cristal / baja la palanca / se suelta la ventosa (con el sonido de éxito de siempre), y se rearma sola a los ~4 s; un cartel cuenta las hechas. Sin QUIETO: no necesita tutorial. **Juegos del dojo** (`DojoGames`): cada juego tiene sus
tres puntos de inicio (`Practice.ITEMS` con `game`, `via` y `starts`); las tres dificultades son tramos de los diez niveles (`DojoGames.TIERS`: fácil 1-3, medio 4-6, difícil 7-10):
se empieza en el primero del tramo y se gana al hacer el último, sin hora extra. PILLA EL CALCETÍN (`atrapa`, escondites, tres pedestales con un calcetín dorado encima: la acción coge el calcetín),
EQUILIBRIO (`pedestal`, tres pedestales de `Plinths`: al subirse empieza; el que subió aguanta todas las rondas encima, y la dificultad del pedestal es la del minijuego del equilibrio),
BOLOS (`bolos`, patio, tres círculos pintados en el suelo: la acción encima; la bola eres tú, hay que rodar contra los bolos) y AGUANTA ESCONDIDO (`aguanta`, escondites, tres armaduras: al
esconderse en una empieza; con una linterna que barre, `Practice.LANTERN_AT`, y la primera ronda deja abierta la armadura de salida). `DojoWatch` vigila quién se sube o se esconde en un punto (solo
avisa al llegar, no mientras sigue ahí). Tab, la pausa o salir por la puerta lo dejan; al acabar, panel con OTRA VEZ (mismo tramo) / SALIR; solo se guarda el mejor nivel por juego, dificultad y tamaño de banda
(`<id>_<dificultad>_best_<n>` en la sección `[dojo]` del progreso). **Una prueba a la vez**: mientras haya una en marcha —un juego del dojo, con su panel de fin hasta aceptar OTRA VEZ o salir, o un objeto del banco con su minijuego— nada más de la casa responde a la acción ni enseña su aviso (`HouseRun.trial_active`, filtro único al principio de `Game._action_for`: ni otros puntos de inicio, ni otras vitrinas, ni papeleras, armaduras, recreativa, interruptores o puertas interiores; lo único que deja pasar es lo que la prueba pide, `HouseRun.trial_action`: los escondites abiertos de la ronda de AGUANTA ESCONDIDO), y los cuerpos de los ladrones no empujan las cosas (`PropsView.move_thieves` los aparta). Al acabar por donde sea vuelve todo, sin nada colgado (el bloqueo se lee del estado real, no de una marca). Sin estrellas, progreso de museo, ruido ni megafonía) y el **aseo** (bañera con cortina, lavabo, váter y una ducha de esquina con la abertura hacia dentro; solo estético, `Den.BATH_GAG`
espera una idea). Cada mueble tiene su frente en datos (`Den.FRONT`, `Den.yaw_for`, `Den.audit`): se dice a qué lado mira y el giro sale del modelo. Las salas se unen por **puertas** (`Den.DOORS`: id, casillas y las dos salas que unen), que se abren y se
cierran con el botón de acción junto a ellas (`ABRIR`/`CERRAR`; unas hojas correderas que se esconden en el muro en
0,3 s, con su ruido): cerrada es muro para los pies (`Den.apply_doors` la pone en `Museum.grid`), y no se puede cerrar con
alguien en el umbral ni tocándolo (`Den.DOOR_CLEAR`). Se aparece en el salón y todas empiezan cerradas, y **solo se ven las
salas abiertas**: una sala se ve si hay alguien de la banda dentro o si se llega a ella desde una sala vista por puertas
abiertas (`Den.visible_rooms`, la unión de lo que ve cada ladrón); las demás se ven a oscuras (un velo casi negro con el
suelo y los muros apenas insinuados, con fundido de 0,3 s) y sin lo que hay dentro (muebles, puestos, luces, carteles,
cosas que tirar y maniquíes: `DenView.set_visible_rooms`, `Main._home_sight`). La cámara no cambia. El estado de las
puertas no se guarda: cada visita empieza igual. Aspecto doméstico y cálido, de luz suave (todas las constantes en
`DenView.LIGHT_*`) (`DenView`, `Main._set_mood`), sin cuenta atrás (al acabar el fundido desde la ciudad
ya se anda) y sin HUD de robo (solo el nombre de la sala al entrar y una ayuda de cómo salir) y con música propia, lo-fi y lenta, sintetizada como la
demás (`Sfx.home`: funde con la del museo en 1,5 s y respeta el ajuste de música). No da estrellas, no abre
robos y no guarda nada. Se sale por la pausa (`< A LA CIUDAD`) o cruzando la puerta del salón (cualquiera de
la banda saca a toda la banda), y se vuelve a la ciudad con la casita elegida. `-- --menu=practica` entra
directamente (`--gang=N` para más ladrones). Muebles: Furniture Kit de Kenney (CC0), en `assets/models/casa/`.

## El cerebro

En desarrollo, el mismo servicio que en la web:

```bash
uv venv --python 3.12 brain/.venv
uv pip install --python brain/.venv/bin/python -r brain/requirements.txt
(cd brain && .venv/bin/python -m uvicorn server:app --port 8000)
```

Sin el cerebro, los guardias deciden con reglas fijas: el juego siempre se puede jugar.

## Versión

`0.1.N`, donde N es el número de commits de la rama: el hook `.githooks/pre-commit` la escribe
en `project.godot` (`config/version`) antes de cada commit con `tools/version.py`, así que
cada commit lleva la suya. Se ve en la esquina del título y las exportaciones la toman de ahí.
En un clon nuevo hay que activar el hook una vez:

```bash
git config core.hooksPath .githooks
python3 tools/version.py --show   # la versión actual
```

Para pasar a 0.2, se cambia `BASE` en `tools/version.py`.

## Exportar

`export_presets.cfg` trae tres configuraciones: **Windows Desktop** (x86_64), **macOS** (universal,
firma ad-hoc y sin notarizar, así que no hace falta certificado) y **Linux** (x86_64). Todo sale en
`build/` (ignorado por git); `tests/` y `brain/` no se incluyen. El icono es `assets/icon.png`.

Primero hay que instalar las plantillas de exportación de 4.7.2 una vez: en el editor,
**Editor → Administrar plantillas de exportación → Descargar e instalar**
(en inglés: *Editor → Manage Export Templates → Download and Install*) (quedan en
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`). Después:

```bash
godot --headless --export-release "Windows Desktop" build/windows/NinjaKarma.exe
godot --headless --export-release "macOS" build/macos/NinjaKarma.zip
godot --headless --export-release "Linux" build/linux/NinjaKarma.x86_64
```

(las carpetas `build/windows`, `build/macos` y `build/linux` tienen que existir: `mkdir -p` antes).

Como no está notarizado, en macOS la primera vez hay que abrirlo con clic derecho → Abrir (o
quitar la cuarentena con `xattr -dr com.apple.quarantine NinjaKarma.app`).

Las versiones exportadas no llevan el cerebro: los guardias usan las reglas fijas, salvo que el
servicio de `brain/` esté corriendo en la misma máquina (puerto 8000).

## Créditos

Recursos de terceros y sus licencias: `CREDITS.md`, que **se genera** (`python3 tools/procedencia.py credits`) desde
`assets/PROCEDENCIA.json`, la fuente única de dónde sale cada asset (pack externo o «propio» y cómo se generó), su autor,
licencia (con su SPDX), URL y si exige atribución. Se edita a mano: colecciones y reglas por carpeta o patrón (gana la
primera; una regla por fichero es la excepción). Un asset nuevo necesita una regla o `python3 tools/procedencia.py` y
`tests/test_procedencia.gd` fallan; lo que no se sabe se marca «origen sin documentar» (`documentado: false`), no se inventa.
La documentación lo enseña en su página «Procedencia» (con filtro por licencia) y en las fichas de objetos y sonidos.
