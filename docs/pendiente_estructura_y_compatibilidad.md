# Pendiente: estructura y compatibilidad

## Hechos

- [x] **EST-4: ciclos entre scripts de `logic/`.** Ver abajo.
- [x] **EST-5: `BrainClient` fuera de `logic/` y `Pads` detrás de una fuente inyectable.** Ver abajo.

## EST-5

- `logic/brain_client.gd` (un `Node` con un `HTTPRequest`, así que no era «lógica pura, sin nodos») pasa
  a `scenes/brain_client.gd`, con su `.uid`. Se usa por su `class_name` (`BrainClient`, en `scenes/main.gd`
  y `tests/test_brain.gd`), así que no cambia ninguna referencia en código; sí las rutas del índice de
  `docs/data` y la descripción de `scenes/` en el README.
- `Pads` (`logic/pads.gd`) ya no llama a `Input` directamente: lo hace a través de `Pads.source`, un
  `Pads.Source` con tres métodos (`connected`, `info`, `joy_name`) que por defecto pregunta a `Input`. Una
  prueba pone la suya (`Pads.source = MiFuente.new()`) y prueba `connected`, `real`, `describe` y
  `owner_back` sin mandos. `tests/test_controles.gd` lo hace con un Xbox y el falso de Apple (05ac:0004).
  Con la fuente por defecto, el comportamiento es el de antes.

## EST-4: ciclos

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
