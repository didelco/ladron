# Ladrón

Un museo cerrado de noche, vigilantes que piensan con [Laya](https://huggingface.co/convaiinnovations/laya) y tú.

Port a **Godot 4.7** (escritorio: Windows, macOS y Linux) del MVP web, que queda congelado en
[`didelco/ladron-threejs`](https://github.com/didelco/ladron-threejs) (etiqueta `web-ref`).

Regla general: **simplificar**. Se porta la lógica tal cual; las mejoras, después.

```
logic/   lógica pura, sin nodos (GDScript con tipos): se prueba sola
scenes/  lo visual: main (bucle y HUD), museum_view (museo), figure (personajes)
brain/   el cerebro: FastAPI sobre Laya, igual que en la web
tests/   pruebas sin ventana
art/     fuentes en Blender (.blend) de las piezas del museo; se exportan a assets/models
```

## Piezas modeladas

Lo que tiene forma fija se modela en Blender (`art/<nombre>.blend`) y el juego carga el `.glb`
de `assets/models/` con su sombreado toon (`MuseumView.asset`): vitrina (una para todas; el código
pone dentro lo que toque), papelera, pedestal y lo que va encima (cuatro bustos, una regadera y un
váter), panel, armadura (por piezas, para que se desmonte al caer), cráneo y cabeza de Lego, ánfora,
globo, tótem, oso de pie, amonite y meteorito. Dos piezas ocupan varias casillas y las reserva el
generador (`MapGen.BIG`): el esqueleto de dinosaurio (2×3) y el sarcófago (3×1).
Lo que depende del mapa o de la semilla sigue en código: muros, suelo, plintos, mariposas,
minerales, dioramas, cuadros (paisaje, retrato, abstracto, pipa, plátano, helado), la lámina de
cada panel y las luces.

Tras retocar una pieza, guarda el `.blend` y reexporta (las convenciones están en `art/export.py`):

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P art/export.py -- vitrina   # sin nombres: todas
godot --headless --import
```

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
godot --headless --script tests/test_heist.gd    # el golpe, el cuadro de alarma y las diez noches
godot --headless --script tests/test_mapfile.gd  # mapas guardados: ida y vuelta, validación y que se juegan
godot --headless --script tests/test_story.gd    # la historia: noches por museo, progreso por jugadores
godot --headless --script tests/test_brain.gd    # decisiones reales de Laya (necesita el cerebro)
```

`tests/visual/figures.tscn` enseña de cerca al ladrón y al guardia con sus animaciones, y
`tests/visual/assets.tscn` todas las piezas modeladas.

En macOS, `godot` es `/Applications/Godot.app/Contents/MacOS/Godot`.

## Controles

En el título se elige el modo:

- **Historia**: diez noches fijas, de muy fácil (un guardia medio dormido en un museo pequeño) a
  difícil (cinco guardias en uno grande). La Banda del Calcetín recupera las cosas que el Barón Von
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
  `-- --menu=challenges` (o `editor`) los abre directamente.

Antes de cada golpe, el plan: el mapa a la izquierda y, a la derecha, la pieza, su historia y
consejos sacados de cómo es la noche (`logic/briefing.gd`: cuántos guardias, si son rápidos u
oyen bien, la alarma de la vitrina, qué se puede tirar...).

En los dos, uno o dos ladrones. Con dos hay que colaborar: la vitrina solo cede mientras el otro
sujeta el **cuadro de la alarma** (naranja, en una pared lejos de la pieza), y así se abre sin que
suene. Si pillan a uno, el que queda la fuerza solo, con alarma.

Por el museo hay papeleras, bustos en pedestal y paneles informativos (`logic/props.gd`): si
chocas con uno se cae (con física, `scenes/props_view.gd`) y hace ruido, y un guardia que lo vea
tirado sube su alarma y va a mirar.

Durante la partida, `M` (o Y / Select en el mando) saca el mapa: el plano, dónde estás, la pieza
y la salida, sin los guardias. Mientras lo miras no te mueves. `N` silencia el sonido. `P` (o Start) pausa. Junto a una papelera, un busto o un panel, `E`
(`.` para el segundo jugador con teclado, X en el mando) lo tira: hace ruido y los guardias van a
ver, lo que sirve para despistarlos. Con dos
ladrones, cada uno ocupa su plaza pulsando un botón de su mando o una tecla de su lado del teclado
(WASD o flechas), como en Mario Kart 64; P1 es siempre turquesa y P2 naranja. En
SETTINGS → CONTROLES: vibración y su fuerza, y zona muerta del stick.

SETTINGS (se guardan en `user://settings.cfg`): sonido (`N`), música, volumen de música y de efectos (0–100 %, `←`/`→`), pantalla completa, v-sync y panel de IA; también se recuerdan la dificultad y el tamaño del modo generativo. La música (sintetizada, de misterio) sube de tensión cuando los guardias están en alerta o te ven. Solo: WASD o flechas, `C` o `Shift` para ponerse a gatas. Dos
jugadores: P1 con WASD y `C`, P2 con flechas y `-` o `/`. `Esc` para la pausa. El objetivo: robar
la pieza (quieto a su lado unos segundos, mires hacia donde mires) y salir por la puerta verde. Sin reloj: se tarda lo que se
quiera.

Con mando: stick izquierdo o cruceta para moverse, A/B (✕/○) para ponerse a gatas y Start para la
pausa; en los menús A acepta y B vuelve. Solo, vale cualquier mando; con dos, el mando 1 es P1 y el
2 es P2 (el teclado sigue funcionando, así que un mando y teclado también). Vibra cuando te ven y
cuando tiras algo.

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

## Exportar

`export_presets.cfg` trae tres configuraciones: **Windows Desktop** (x86_64), **macOS** (universal,
firma ad-hoc y sin notarizar, así que no hace falta certificado) y **Linux** (x86_64). Todo sale en
`build/` (ignorado por git); `tests/` y `brain/` no se incluyen. El icono es `assets/icon.png`.

Primero hay que instalar las plantillas de exportación de 4.7.2 una vez: en el editor,
**Editor → Administrar plantillas de exportación → Descargar e instalar**
(en inglés: *Editor → Manage Export Templates → Download and Install*) (quedan en
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`). Después:

```bash
godot --headless --export-release "Windows Desktop" build/windows/Ladron.exe
godot --headless --export-release "macOS" build/macos/Ladron.zip
godot --headless --export-release "Linux" build/linux/Ladron.x86_64
```

(las carpetas `build/windows`, `build/macos` y `build/linux` tienen que existir: `mkdir -p` antes).

Como no está notarizado, en macOS la primera vez hay que abrirlo con clic derecho → Abrir (o
quitar la cuarentena con `xattr -dr com.apple.quarantine Ladron.app`).

Las versiones exportadas no llevan el cerebro: los guardias usan las reglas fijas, salvo que el
servicio de `brain/` esté corriendo en la misma máquina (puerto 8000).

## Créditos

Recursos de terceros y sus licencias: `CREDITS.md`.
