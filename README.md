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
```

## Plan

1. ✅ **Esqueleto y generador**: mismo museo que la web con la misma semilla.
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
godot --headless --script tests/test_mapgen.gd   # generador = web
godot --headless --script tests/test_museum.gd   # museo (salas, zonas, ronda) = web
godot --headless --script tests/test_sim.gd      # escenarios de la simulación
godot --headless --script tests/test_brain.gd    # decisiones reales de Laya (necesita el cerebro)
```

`tests/visual/figures.tscn` enseña de cerca al ladrón y al guardia con sus animaciones.

En macOS, `godot` es `/Applications/Godot.app/Contents/MacOS/Godot`.

## Controles

En el título se elige uno o dos ladrones (o `1`/`2`), y en SETTINGS el sonido (`M`), el panel de IA y
el tamaño del museo. Solo: WASD o flechas, `C` o `Shift` para ponerse a gatas. Dos jugadores: P1 con
WASD y `C`, P2 con flechas y `-` o `/`. `Esc` para la pausa. El objetivo: robar la pieza (quieto delante unos segundos) y
salir por la puerta verde antes de que acabe el reloj.

Para grabar o probar sin pulsar teclas: `godot -- --autostart` salta directamente a la partida
(`-- --autostart --two` con dos ladrones).

## El cerebro

En desarrollo, el mismo servicio que en la web:

```bash
uv venv --python 3.12 brain/.venv
uv pip install --python brain/.venv/bin/python -r brain/requirements.txt
(cd brain && .venv/bin/python -m uvicorn server:app --port 8000)
```

Sin el cerebro, los guardias deciden con reglas fijas: el juego siempre se puede jugar.

## Créditos

Los modelos 3D de terceros, cuando se incorporen, llevan su licencia en `CREDITS.md`.
