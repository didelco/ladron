# Pendiente: estructura del proyecto y compatibilidad

Sacado de dos análisis de solo lectura (2026-09-29, versión 0.1.220, 132 ficheros `.gd`, unas 51.500 líneas).
Cada apartado `### [ID]` está escrito para pasarlo tal cual a una issue: título, prioridad, contexto, qué hacer y cuándo se da por hecho.
Las cifras vienen de leer el repo, no de medirlo en ejecución; lo que es estimación lo dice.

Prioridad: **A** alta, **M** media, **B** baja. Tamaño: **S** menos de una hora, **M** una sesión, **L** varias.

---

## Estructura

### [EST-1] Trocear `scenes/main.gd` y `_tick()` — HECHO
`main.gd` pasa de **4.552 a 1.373 líneas**; `_tick()` de 313 a **36** (ahora `NightLoop.tick`, en fases con nombre: `_read_keys`, `_move_thieves`, `_props_and_actions`, `_smoke`, `_job`, `_guards`, `_light_events`, `_think`, `_sight_and_capture`, `_exits`); `_ready` de 157 a 47, `_build_world` de 150 a 12 (`Scenery.build` y sus fases), `_build_environment` de 84 a 15 y `_build_job` de 89 a 55. Ninguna función de `main.gd` pasa de 50 líneas.

Controladores nuevos en `scenes/` (clase con `host: Game`, `main.gd` los posee como `var`): `LaunchArgs` (`launch`), `HouseRun` (`house`: dojo, espantapájaros, banco, salas a la vista), `PreviewStand` (`podium`), `SettingsScreens` (`options`), `NightEnv` (`nightenv`), `Scenery` (`scenery`), `CameraRig` (`rig`), `Hands` (`hands`: asientos, teclas, mandos, vibración, glifos), `MegaphoneRun` (`loudspeaker`), `NightLoop` (`loop`), `ChallengeScreens` (`challenges`) y `BriefScreens` (`briefing`). `main.gd` toma `class_name Game`. Las pruebas y `tools/capture_docs.gd` se actualizaron a las rutas nuevas (`m.house.dojo_game`, `m.hands.seat_input`, `m.loop.tick`…); `test_textos` lee `SettingsScreens.ASSET_TABS`.

Vigilancia: `python3 tools/tamanos.py [-v] [--estricto]` avisa de ficheros de más de 1.500 líneas y funciones de más de 80 (límite blando), con las excepciones de hoy apuntadas (`museum_building`, `hud`, `town_builder`, `map_editor` y 23 funciones; no deben crecer). Los 30 tests siguen en verde. Quedan fuera de este encargo esas excepciones, empezando por `hud.gd:_ready` y `Sim.step_guard`.

### [EST-2] `megafonia-tool` fuera del repo del juego — HECHO
Se movió a `../megafonia-tool` (repo propio, con sus modelos, cachés y `.venv` fuera de git). `regenerar_juego.sh` usa `GODOT_DIR` (por defecto `../nosy-horesradish`). Si el `.venv` falla tras el traslado, recrearlo con `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`.

### [EST-3] Lanzador común de tests y CI — A · M
**Contexto.** Hay 29 tests `extends SceneTree` (unas 8.400 líneas) que se lanzan a mano uno a uno (README, líneas 90-102). No hay lista única, así que un test nuevo puede quedar sin ejecutarse, y no hay CI (`.github` no existe).
**Qué hacer.**
- `tests/run_all.sh` (o `tools/test.py`): recorrer `tests/test_*.gd`, lanzar `godot --headless --script` con `SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004`, ir en paralelo (4 a la vez va bien), sumar fallos y devolver código de salida.
- Tener en cuenta el ruido conocido en headless: `joy_names.has(p_device)`, «leaked at exit», «Viewport Texture must be set» (`test_previa`). El criterio es el código de salida y la línea de resumen (`FALLOS: 0` / `0 fallos` / `OK:`), no buscar «error» en el log.
- `test_escondite` tarda unos 80 s y su tramo de la ciudad falla a veces por tiempos: reintentar una vez.
- Workflow de GitHub Actions con `barichello/godot-ci`, importación previa y caché de `.godot/`.
**Hecho cuando.** Un comando ejecuta todos los tests y falla si uno falla; el README lo apunta; CI lo corre en cada PR.

### [EST-4] Ciclos de dependencia en `logic/` — HECHO (quedan 7 pares reales anotados)

`python3 tools/ciclos.py [-v] [--estricto]` los vigila: lee los `.gd` de `logic/`, quita comentarios y
cadenas, y dice qué `class_name` nombra cada uno en su código; saca los pares circulares y las
componentes circulares más largas. `--estricto` sale con 1 si hay un par que no esté en `PERMITIDOS`
(dentro del script), que son los de la lista de abajo.

Análisis real (no solo nombres) de los 14 pares que se señalaron:

| Par | ¿Real? | Qué se hizo |
|---|---|---|
| Sim ↔ Hearing | Sí: `Hearing.heard_at` leía `Sim.tuning("hearing")` | Resuelto: `heard_at(g, noise, ear)`, lo pasa `Sim` |
| Sim ↔ Roll | Sí: `Roll.step` usaba `Sim.move_with_collision` y `Sim.CROUCH_SECONDS` | Resuelto: `Roll.step(p, dt, move, crouch_seconds)`, los pasa `Sim.step_thief` |
| Hearing ↔ SoundEvent | Sí: `SoundEvent.make` leía `Hearing.LOUDNESS` | Resuelto: la tabla vive en `SoundEvent.LOUDNESS`; `Hearing.LOUDNESS` es la misma |
| MapGen ↔ Themes | Sí: `Themes` recorría `MapGen.BIG` | Resuelto: tabla en `BigPieces.SIZES` (solo datos); `MapGen.BIG` es la misma |
| Museum ↔ Plinths | Sí, pero solo por el borrado de `Museum.load_grid` | Resuelto: `Placed` (solo datos) guarda las listas; `Plinths.list` es la misma y `Museum` limpia `Placed` |
| Hideouts ↔ Museum | Igual que el anterior (`Hideouts.reset()` desde `load_grid`) | Resuelto: `Hideouts.pieces` es `Placed.furniture` |
| Arcades ↔ Den | **No existe**: no hay ningún `Den` en el proyecto, y `Arcades` solo nombra `Collection`, `Thief`, `Heist` y `ArcadeGame` (que no vuelven a él) | Nada |
| Sim ↔ Heist | Sí: `Heist` usa `Sim.tuning`/`Sim.feature`; `Sim` usa la ruta y el golpe de `Heist` | Se deja |
| Sim ↔ Props | Sí: `Props.spotted_by` usa `Sim.in_view`; `Sim` usa `Props.list` | Se deja |
| Sim ↔ Smoke | Sí: `Smoke` usa `Sim.in_view`; `Sim.in_view` y `_mark_seen` usan `Smoke.blocks/covers` | Se deja |
| Sim ↔ Hideouts, Sim ↔ Plinths | Sí: `witnesses` y `learn` de `Sim` al subirse/esconderse; `Sim` llama a `get_out`, `step_down`, `grabbed` | Se deja |
| Hideouts ↔ Props | Sí: `Props.place` pide a `Hideouts` dónde hay sitios y cuántas armaduras caben; `Hideouts.all` lee `Props.list` (la armadura es a la vez prop y escondite) | Se deja |
| Hideouts ↔ Thief | Solo de tipos: `Thief.hideout: Hideouts.Spot`; `Hideouts` usa `Thief` de verdad | Se deja |

Por qué se dejan los que se dejan:

- **`Sim` es el centro de la simulación** (vista, ruido, cazar, mover) y los satélites (`Heist`, `Props`,
  `Smoke`, `Plinths`, `Hideouts`) necesitan de él la vista (`in_view`, `witnesses`, `learn`) y los dados
  de la noche (`tuning`, `feature`, que leen `Sim.custom`, `difficulty` y `gang`, variables que
  escriben `main.gd` y muchas pruebas). Romperlos de verdad pide sacar la visión y los dados de `Sim`
  a un módulo de más abajo (p. ej. `Senses` y `Tuning`) y mover ahí esas variables, tocando `main.gd` y las
  pruebas. Son muchos cambios por poca cosa; se hará si algún día hace falta probar un satélite solo.
- **`Hideouts ↔ Props`**: pasar por parámetro lo que `Props.place` pide a `Hideouts` cambiaría su firma,
  que llaman `scenes/main.gd` (que no se toca en este encargo) y varias pruebas.
- **`Hideouts ↔ Thief`**: solo tipos en la declaración de un campo; GDScript los resuelve sin problema. Se
  arreglaría sacando `Spot` a su propia clase, pero cambia el nombre `Hideouts.Spot`, que se usa fuera.

Quedan 7 pares circulares (los de la lista `PERMITIDOS` del script) y una componente circular mayor que
los une por caminos más largos (`Sim`, sus satélites, `Museum`, `MapGen`, `Themes`, `Thief`, `Minigame`,
`Watch`, `Hearing`, `Roll`); el script la enseña para vigilar que no crezca.

### [EST-5] Aislar lo que no es lógica pura en `logic/` — HECHO

- `logic/brain_client.gd` (un `Node` con un `HTTPRequest`, así que no era «lógica pura, sin nodos») pasa
  a `scenes/brain_client.gd`, con su `.uid`. Se usa por su `class_name` (`BrainClient`, en `scenes/main.gd`
  y `tests/test_brain.gd`), así que no cambia ninguna referencia en código; sí las rutas del índice de
  `docs/data` y la descripción de `scenes/` en el README.
- `Pads` (`logic/pads.gd`) ya no llama a `Input` directamente: lo hace a través de `Pads.source`, un
  `Pads.Source` con tres métodos (`connected`, `info`, `joy_name`) que por defecto pregunta a `Input`. Una
  prueba pone la suya (`Pads.source = MiFuente.new()`) y prueba `connected`, `real`, `describe` y
  `owner_back` sin mandos. `tests/test_controles.gd` lo hace con un Xbox y el falso de Apple (05ac:0004).
  Con la fuente por defecto, el comportamiento es el de antes.

### [EST-6] Helper común de tests — M · S
**Contexto.** `test_dojo_juegos.gd` (915 líneas), `test_escondite.gd` (784) y `test_megafonia.gd` (632) ya son grandes; no se ha medido si repiten código.
**Qué hacer.** Comprobar duplicación y, si la hay, un `tests/support.gd` con `check`, contadores y salida de resumen.

### [EST-7] Política de binarios y peso del repo — M · M
**Contexto.** `docs/` pesa 18 MB versionados (82 capturas `.webp` = 9,9 MB, 46 hitos = 2,9 MB, `docs/assets` 3,4 MB). Los `.webp` no se comprimen en delta: cada regeneración suma su peso entero al historial. Además, `assets/models` 33 MB (199 `.glb`), `assets/ui` 14 MB (PNG de fondo de 1,5–2,2 MB), `art/` 17 MB (`.blend`), `audio/megafonia` 22 MB.
**Qué hacer.** Decidir entre Git LFS para `docs/capturas`, `docs/versiones`, `.blend`, `.glb`, `.ogg`; o no versionar las capturas y regenerarlas al publicar. Valorar WebP/VRAM comprimido para los PNG de UI. Revisar si hace falta conservar los 46 hitos.
**Hecho cuando.** Hay una decisión escrita (README o CLAUDE.md) y el peso del historial deja de crecer con cada lote de capturas.

### [EST-8] `git gc` — M · S
**Contexto.** 216 MB de objetos sueltos frente a 5,6 MB empaquetados, y aviso de «garbage» en `.git/worktrees/.../refs`.
**Qué hacer.** `git gc` cuando no haya otros agentes ni sesiones escribiendo (hay varios worktrees).

### [EST-9] Filtro de exportación — B · S
**Contexto.** `export_presets.cfg` (Windows, Linux, macOS) excluye `tests/*, brain/*, build/*`. Godot ya ignora las carpetas con `.gdignore`, pero no todas lo tienen.
**Qué hacer.** Añadir `art/*, docs/*, tools/*, locale/*.csv`. Comprobar que el build sigue arrancando.

### [EST-10] Cadena de versión sin traducir — B · S
`scenes/hud.gd:288` construye la cadena de versión sin pasar por `Text.t`. Cosmético.

---

## Compatibilidad con ordenadores antiguos

**Estado (hechos leídos del repo).** `project.godot` no define `rendering_method`, así que Godot 4.7 usa **Forward+** (exige Vulkan 1.2 o Metal). El look nocturno (`scenes/main.gd:3550-3620`) usa niebla volumétrica, SSAO, SSIL, SSR (48 pasos), glow HDR, tonemapper ACES y una luz direccional con sombras en 2 splits a 35 m; hay 2 shaders propios (`scenes/floor.gdshader`, `scenes/wall.gdshader`), MSAA 4x en los SubViewports 3D de menús, mapa de ciudad y HUD, y `GPUParticles3D` (humo, `fx.gd` con `GPUParticlesCollisionBox3D`, que no existe en Compatibility). `logic/settings.gd` no tiene ningún ajuste de calidad gráfica.
**Estimación (sin medir).** Mínimo razonable: GPU con Vulkan 1.2 o Metal (Intel UHD 620/Iris Xe justos, AMD GCN, NVIDIA GTX 900+), Windows 10, macOS 10.13+/11+, 4 GB de RAM. No arranca en Intel HD 4000/4400/5500 (2012–2015) ni en Macs sin Metal; en Macs 2012–2015 con Metal iría justo. CPU y memoria no son el problema.

### [COMP-1] Ajuste de calidad Alta/Baja — A · M — HECHO
**Hecho.** `logic/quality.gd` (`Quality`), claves `quality` y `render_scale` en `Settings`, página de ajustes de pantalla, `tests/test_calidad.gd`. Baja apaga SSR, SSIL, SSAO y niebla volumétrica, MSAA 2x, sombras de la luna en un corte a 20 m y sin partículas de humo (la nube sigue ocultando). Alta es lo de siempre y es el valor por defecto. Falta medir los FPS en una máquina justa (COMP-3).
**Qué hacer.** Añadir la opción a `Settings.DEFAULTS` y al menú de pantalla. En Baja: apagar SSR, SSIL, niebla volumétrica y SSAO; MSAA a 2x o 0; acortar la distancia de sombras; quitar las partículas de humo. Tocar `main.gd:3550-3620` y los `_setup` de los viewports (`menu_stage.gd`, `city_stage.gd`, HUD).
**Se pierde en Baja.** Brillos del suelo pulido, luz rebotada, haces de linterna visibles, contacto en las esquinas.
**Hecho cuando.** Existe la opción, se guarda, y una noche grande a 2 jugadores gana FPS medibles.

### [COMP-2] Escala de render 3D — A · S — HECHO
**Hecho.** Ajuste ESCALA 3D (100, 85, 70 %) en la página de pantalla: `scaling_3d_scale` en la ventana y en los SubViewports 3D (menús, ciudad, plano, minijuegos, retratos del HUD, previa).
`scaling_3d_scale` al 0,67–0,75 como opción. Casi gratis; el suelo queda algo más blando.

### [COMP-3] Medir en una máquina o VM de gama baja — M · S
Arranque con `godot --rendering-method gl_compatibility` (o `--rendering-driver opengl3`) y con Forward+ en una máquina con iGPU. Medir FPS en la noche más cargada de luces (banda de 2), los menús 3D con SubViewport y el humo. Es lo que decide si COMP-4 hace falta.

### [COMP-4] Modo Compatibility (OpenGL 3.3) como variante exportada — B · L
**Es un port, no un interruptor.** `rendering_method="gl_compatibility"` (GPUs de 2010 en adelante). Se pierden SSAO, SSIL, SSR, niebla volumétrica y la colisión de partículas; glow existe desde 4.3 con menos control. Revisar `floor.gdshader` y `wall.gdshader` (asumen `specular_schlick_ggx` y luces con sombras); compensar niebla y contacto con luces falsas o sprites. Probar las 25 noches, el editor y los minijuegos. Exportar ambas variantes (`--rendering-method` por preset), Forward+ como principal y Compatibility como «modo clásico».
**Solo si** COMP-3 y el público objetivo lo justifican.

---

## Orden sugerido
1. EST-2, EST-3, EST-9 (barato, evita accidentes y regresiones).
2. COMP-1 y COMP-2 (evitan que el juego sea injugable en máquinas justas).
3. EST-1 (trocear `main.gd`).
4. EST-7 (decidir política de binarios) y EST-8.
5. EST-4, EST-5, EST-6.
6. COMP-3 y, si procede, COMP-4.
