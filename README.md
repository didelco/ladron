# Ladrón

Un museo cerrado de noche, vigilantes que piensan con [Laya](https://huggingface.co/convaiinnovations/laya) y tú.

Port a **Godot 4.7** (escritorio: Windows, macOS y Linux) del MVP web, que queda congelado en
[`didelco/ladron-threejs`](https://github.com/didelco/ladron-threejs) (etiqueta `web-ref`).

Regla general: **simplificar**. Se porta la lógica tal cual; las mejoras, después.

```
logic/   lógica pura, sin nodos (GDScript con tipos): se prueba sola
scenes/  lo visual: museo, figuras, HUD            (pendiente)
brain/   el cerebro: FastAPI sobre Laya, igual que en la web
tests/   pruebas sin ventana
```

## Plan

1. **Esqueleto y generador** ← aquí. Mismo museo que la web con la misma semilla, comprobado
   contra 90 museos exportados de la versión web (`tests/fixtures/`).
2. **Jugable sin IA**: museo con cajas, ladrón, guardias con las reglas de reserva, cámara y controles.
3. **Laya**: cliente HTTP a `brain/` (`POST /decide`, todos los guardias en una llamada) y la mente de cada guardia.
4. **Aspecto**: figuras como en la web (encapsuladas en una escena `Figure` para cambiarlas por
   modelos con esqueleto más adelante), luces, conos de visión, suelo y muros.
5. **Juego completo**: atraco, HUD, menús, tamaños de museo, sonido (unos pocos `.wav`).
6. **Exportar** a Windows, macOS y Linux, y decidir cómo va Laya para jugadores.

## Pruebas

```bash
godot --headless --script tests/test_mapgen.gd
```

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
