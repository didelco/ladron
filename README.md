# Ninja Karma

Un museo cerrado de noche, vigilantes que piensan con [Laya](https://huggingface.co/convaiinnovations/laya) y tú.

Port a **Godot 4.7** (escritorio: Windows, macOS y Linux) del MVP web, que queda congelado en
[`didelco/ladron-threejs`](https://github.com/didelco/ladron-threejs) (etiqueta `web-ref`).

Regla general: **simplificar**. Se porta la lógica tal cual; las mejoras, después.

```
logic/   lógica pura, sin nodos (GDScript con tipos): se prueba sola
scenes/  lo visual: main (bucle y HUD), museum_view (museo), figure (personajes)
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
| `art/botin.blend` | las piezas a robar: dentadura, pato, calcetín, tostada, corona, queso lunar, chicle, máscara, despertador, huevo, diamante, ídolo. Los materiales que empiezan por `color` toman el color de la pieza en el juego (`color_claro_N`, `color_oscuro_N`: un N % más claro u oscuro) | `assets/models/botin/` |
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
6. **Exportar** a Windows, macOS y Linux, y decidir cómo va Laya para jugadores.

## Pruebas

```bash
godot --headless --script tests/test_mapgen.gd   # museos bien formados (306 de todos los tamaños y formas)
godot --headless --script tests/test_sim.gd      # escenarios de la simulación
godot --headless --script tests/test_heist.gd    # el golpe, el cuadro de alarma y las noches de la historia
godot --headless --script tests/test_mapfile.gd  # mapas guardados: ida y vuelta, validación y que se juegan
godot --headless --script tests/test_story.gd    # la historia: noches por museo, progreso por jugadores
godot --headless --script tests/test_roll.gd     # rodar: ocho casillas, bajo y callado; limpia o contra la pared (golpe y estrellas)
godot --headless --script tests/test_plinths.gd  # pedestales: subir con la acción, estatua invisible, bajar con una dirección
godot --headless --script tests/test_hideouts.gd # escondites: muebles y piezas grandes por tema, invisible dentro, el guardia que te ve entrar va a por ti
godot --headless --script tests/test_fronts.gd    # piezas con frente (recreativa, trono, Anubis, la nevera...): nunca contra una pared
godot --headless --script tests/test_controles.gd # teclas y botones: partida, menús y elegir sitio
godot --headless --script tests/test_smoke.gd     # bomba de humo: dos por ladrón, tapa la vista, despista al que persigue
godot --headless --script tests/test_brain.gd    # decisiones reales de Laya (necesita el cerebro)
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
python3 tools/docs.py build --fast   # solo datos y textos
python3 tools/docs.py serve          # http://localhost:8765: además, los textos se editan ahí
```

Editar un texto en el visor lo cambia en `locale/texts.csv` (solo esa fila) y Godot lo reimporta.

## Controles

En el título se elige el modo:

- **Historia**: veinte noches fijas, de muy fácil (un museo pequeño sin guardias) a
  difícil (cuatro guardias en uno grande). La Banda del Calcetín recupera las cosas que el Barón Von
  Bostezo se llevó del pueblo (`logic/story.gd`). Primero se elige cuántos ladrones; luego, en el
  mapa de la ciudad, uno de los cinco museos (cada uno con sus colores de pared y suelo) y dentro,
  una de sus cuatro noches. El progreso se guarda aparte para cada número de jugadores y se puede
  rejugar cualquier noche ya alcanzada.
- **Generativo**: un museo nuevo cada vez, con dificultad (fácil, media, difícil) y tamaño a elegir.
  Cada golpe trae su pieza y su historia, inventadas a partir de la semilla (`logic/loot_gen.gd`):
  algo que el Barón le quitó a alguien del pueblo.
- **Retos**: mapas hechos a mano, los de serie (`maps/`) y los tuyos (`user://maps/*.json`,
  `logic/map_file.gd`). Desde ahí se abre el **editor** (`scenes/map_editor.gd`): pintar suelo,
  muro, vitrina o exterior, poner salas hechas (galería, vitrinas, pedestales, columnas,
  dinosaurio...), la entrada, la pieza, la salida, guardias y objetos, o partir de un mapa
  aleatorio del generador; tamaño, dificultad y guardias; vista 3D, probar y guardar. Solo deja
  jugar mapas cerrados, sin espacios a los que no se llega, con pieza y salida alcanzables.
  `-- --menu=challenges` (o `editor`) los abre directamente. La pantalla es una lista (las noches
  de la historia, luego los retos) con el plano del que está elegido a la derecha.
  Las **noches de la historia** también se retocan ahí: se abre el museo tal como lo monta la
  noche (`MapFile.from_museum`), se edita y se guarda en `maps/historia/noche_NN.json` (en
  `user://maps/historia/` si el juego está exportado); desde entonces la noche juega ese museo,
  con su pieza, sus guardias y su dificultad de siempre. *Volver al original* borra el fichero.
  Probar una noche desde el editor no cuenta como partida de la historia.

Antes de cada golpe, el plan: el mapa a la izquierda y, a la derecha, la pieza, su historia y
consejos sacados de cómo es la noche (`logic/briefing.gd`: cuántos guardias, si son rápidos u
oyen bien, la alarma de la vitrina, qué se puede tirar...).

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
jugadores: P1 con WASD, `E`, `Espacio`, `C`, el `Shift` izquierdo y `F`; P2 con flechas, `.`, `Enter`, la tecla de después del punto (`/` en un teclado inglés, `-` en uno español), el `Shift` derecho y `,`. `Esc` para la pausa. El objetivo: robar
la pieza (quieto a su lado unos segundos, mires hacia donde mires) y salir por la puerta verde. Sin reloj: se tarda lo que se
quiera.

Con mando, como en la mayoría de juegos: stick izquierdo o cruceta para moverse, A (✕) la acción, B (○) para rodar
y soltar un minijuego, X (□) o clic del stick para ponerse a gatas, View para el mapa y Start para la
pausa; Y (△) suelta una bomba de humo. En los menús A acepta, B vuelve, LB/RB cambian de pestaña y Start
salta la historia y la previa. Así A y B significan lo mismo jugando que en los menús: A hace, B se aparta. Solo, vale cualquier mando; con dos, el mando 1 es P1 y el
2 es P2 (el teclado sigue funcionando, así que un mando y teclado también). Vibra cuando te ven y
cuando tiras algo.

**Andar lento**: mientras mantienes `Shift` andas despacio, 1,2 casillas/s, sin
llegar nunca a correr, y tus pasos se oyen la mitad de lejos que andando a esa velocidad (un guardia
tranquilo lo oye a 1,1 casillas; andando normal, a 2,4–4,4, y corriendo, hasta 7,5). Te ven de pie, pero
no tienes que agacharte ni levantarte. P1 usa el `Shift` izquierdo y P2 el derecho (encima de las
flechas); solo, cualquiera de los dos. `Shift` mantenido para ir despacio es lo habitual en PC; `Ctrl`
no se usa porque en Mac choca con `Ctrl`+`Espacio` (cambiar de idioma del teclado) y `Ctrl`+flechas
(escritorios), ni `Cmd` por `Cmd`+`Q`. Godot no distingue los dos `Shift` al consultar el teclado, así
que `scenes/main.gd` los sigue por `InputEventKey.location`. En el mando, mantener LB
o inclinar el stick poco (pasada la zona muerta, menos de la mitad de lo que queda hasta el borde).
**A gatas** se va a 1,5 casillas/s, algo más deprisa y sin ningún ruido, pero cuesta 1,5 s agacharse y
otro tanto levantarse.

Para grabar o probar sin pulsar teclas: `godot -- --autostart` salta directamente a la partida
(`-- --autostart --two` con dos ladrones), y `-- --intro` enseña el comienzo de la historia con la
cuenta atrás (`--two` para dos, `--gen` para el modo generativo, `--challenge` para el primer reto). `-- --menu=story` (o `map`, `museum`, `generative`, `settings`) abre ese menú directamente.

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

Recursos de terceros y sus licencias: `CREDITS.md`.
