# Parámetros del comportamiento de los guardias

Referencia de todo lo que define cómo se comporta un guardia, de más
concreto (un guardia suelto) a más general (constantes fijas del motor).
Pensado para saber, al tocar algo, en qué nivel vive y a quién afecta.

## 1. Por guardia individual — `GuardSpawn` (editable en el editor de mapas)

Fichero: `logic/guard_spawn.gd`. Guardado en `MapFile.guards: Array[GuardSpawn]`
(`logic/map_file.gd`). Además de `at` y `dir`, cada guardia lleva `stance` (`round` o
`post`), `watch`, el `archetype` elegido y cuatro deslizadores de 0 a 4 (el 2 es el
guardia normal): `view_level`, `hearing_level`, `speed_level` y `attention_level`
(la «Atención», que decide lo fácil que le es notar una vitrina vacía; los niveles y
la fórmula están en la página «Alerta y guardias» de la web, `docs/ALERTA.md`).
En el JSON del mapa: `view`, `hearing`, `speed`, `attention`.

| Parámetro | Tipo | Qué hace | Se aplica en |
|---|---|---|---|
| `at` | `Vector2i` | Dónde empieza el guardia la noche. También decide, indirectamente, a qué punto de la ronda automática (`Museum.watchpoints`) se engancha: el más cercano a `at`. | `Sim.place_guards()`, `logic/sim.gd:424-437` |
| `dir` | `float` (radianes) | Hacia dónde mira al empezar. Se copia a `Guard.dir` y `Guard.post_dir`. | `Sim.place_guards()`, `logic/sim.gd:424-437` |

Lo que **no** es configurable por guardia: la ruta de patrulla. Siempre
la calcula `Museum._build_round()` a partir de la geometría del mapa
(salas, pasillos), igual para un mapa generado que para uno dibujado a
mano — el editor no la controla ni debería.

## 2. Por noche/mapa — `MapFile`

Fichero: `logic/map_file.gd`.

| Parámetro | Dónde | Qué hace |
|---|---|---|
| `guard_count` | `MapFile.guard_count` | Cuántos guardias hay esa noche. Si es `0`: uno por cada `GuardSpawn` colocado, o lo que diga la dificultad/tamaño del museo (`guards_tonight()`, `map_file.gd:542-548`). |
| `difficulty` | `MapFile.difficulty` | Qué fila de `Sim.DIFFICULTIES` usa (`easy`/`medium`/`hard`). |

## 3. Diales de dificultad — `Sim.DIFFICULTIES`

Fichero: `logic/sim.gd:101-108`. Una tabla por dificultad; toda regla que
depende de la dificultad pasa por `Sim.tuning(key)` (`sim.gd:123-127`), así
que los números viven en un solo sitio.

| Clave | Fácil | Media | Difícil | Qué escala |
|---|---|---|---|---|
| `view` | 0.8 | 1.0 | 1.25 | Alcance de la vista (`near`/`range`, no el ángulo del cono) y potencia de las linternas (`torch_power()`). |
| `hearing` | 0.8 | 1.0 | 1.2 | Qué tan lejos oye un ruido (`Hearing.heard_at`). |
| `speed` | 0.7 | 1.0 | 1.1 | Velocidad al moverse (`step_guard`, `sim.gd:1124`). |
| `lock` | 0.35 | 1.0 | 1.3 | Dificultad del minijuego de la cerradura (no afecta a la IA del guardia). |
| `calm_after` | 7.0 s | 10.0 s | 14.0 s | Cuánto tarda en bajar de sospecha 1 (`!`) sin nada nuevo. |
| `alarms` | 3 | 2 | 1 | Cuántos ruidos hacen falta para que quede alerta "para siempre" (`_alarm`, `sim.gd:881-893`). |
| `guards` | 1 | 0 | 0 | Guardias por defecto (`0` = lo decide el tamaño del museo, `Museum.SIZES[size].guards`). |

**Banda de ladrones** (`Sim.gang`, `GANG_EASE` en `sim.gd:120`): con 2, 3 o 4
ladrones, `view`/`speed`/`hearing` se multiplican además por 0.92/0.85/0.8
(más ladrones, guardias más torpes), y con banda de 3+ o 4+ se quita un
guardia (`guard_count()`, `sim.gd:132-141`).

Una noche de historia puede sobreescribir cualquiera de estas siete claves
una a una vía `Sim.custom` (`Story.tuning(n)`), sin tocar la dificultad
general — `Sim.tuning()` mira primero `custom`, luego `DIFFICULTIES`.

## 4. Otros ajustes de `Sim.custom` (nivel noche, solo modo historia)

| Clave | Qué hace |
|---|---|
| `post` | `"route"`, `"quiet"` o `"case"`: pone al primer guardia en un puesto fijo pensado para enseñar una lección concreta (`Sim.assign_posts`, `sim.gd:167-187`). Fija `at`/`dir` de ese guardia, pero desde el diseño de la noche (`Story`), no desde el editor. |
| `theme` | Qué tema de museo usa. No toca la IA, pero cambia qué salas salen. |
| `lights` | Si está apagado (`Sim.feature("lights")` da `false`), los guardias nunca hacen el recado de ir a revisar una luz encendida (`sim.gd:1076`, `sim.gd:1269`). |
| `props` | Interruptor de si hay objetos que tirar y que hacen ruido. |
| `case_alarm` | Si la vitrina tiene alarma: con ella, dos fallos en el mismo perno de la ganzúa (o en la misma lámpara de la ventosa) la hacen saltar (`Heist.alarm_live`, `logic/heist.gd`; `NightAlert.trip`). Ya no pita mientras se fuerza. En la historia está apagada hasta la noche 11. |
| `lockpick` | Si el robo usa el minijuego de la cerradura o se resuelve al momento (`logic/heist.gd:271`). |

Todo lo no fijado en `custom` sale `true` por defecto (`Sim.feature()`,
`sim.gd:147-148`).

## 5. Constantes fijas del motor (no configurables por partida)

Mismas para todos: el "carácter" del juego. Cambiarlas es tocar código,
no una partida ni una noche.

### Vista — `Sim.VIEW` (`sim.gd:14-21`)

| Constante | Calma | Alerta | Qué es |
|---|---|---|---|
| `near` | 3.5 | 5.0 | Alcance del foco brillante: te ve estés como estés (de pie o agachado). |
| `range` | 7.0 | 10.0 | Alcance del resplandor tenue: solo te ve de pie. |
| `half` | π/4.2 | π/2.8 | Medio ángulo del cono de visión. |

`LIT_RANGE := 40.0` — en una sala con la luz encendida no hay límite
práctico de alcance, solo línea de visión.

### Alerta y sospecha (`sim.gd`)

| Constante | Valor | Qué es |
|---|---|---|
| `CALM_AFTER_S` | 10.0 s | Base de cuánto tarda una sospecha 1 en bajar sin nada nuevo (la dificultad la reescala vía `calm_after`). |
| `HUNCH_SHARE` | 0.35 | Fracción de `calm_after` que dura una sospecha 1 antes de bajar. |
| `ALERT_HOLD_MS` | 30 000 ms | Cuánto se sostiene la alerta (`!!`) sin nada nuevo antes de bajar un escalón. |
| `CHASE_LOST_MS` | 60 000 ms | Cuánto se sostiene tras perder de vista a mitad de persecución (`!!!`). |
| `ALARMS_TO_STAY` | 3 | (Documentado junto a `alarms` de la dificultad: referencia, el valor real por dificultad está en `DIFFICULTIES`.) |
| `MAX_WATCH` | 6.0 s | Nadie se queda plantado en un cruce más de esto. |

### Detección y captura (`sim.gd`)

| Constante | Valor | Qué es |
|---|---|---|
| `TOUCH_RANGE` | 1.1 | A esta distancia, un guardia te nota mires donde mires. |
| `LUNGE_RANGE` | 1.8 | Más cerca de esto, un guardia que persigue va derecho a por ti. |
| `CATCH_RANGE` | 0.75 | Distancia a la que te pilla. |
| `WARN_RANGE` | 1.3 | Lo bastante cerca como para avisar a otro guardia en voz baja. |
| `MEMORY_MS` | 14 000 ms | Cuánto sigue un guardia trabajando una pista antes de rendirse. |
| `NOISE_REFRESH_MS` | 1 200 ms | Cuánto se guarda un punto oído antes de que un nuevo ruido pueda moverlo. |
| `TOO_CLOSE` | 6.0 | Dos guardias sin nada que hacer más cerca que esto: se considera que se pisan y uno se reubica. |

### Oído — `Hearing` (`logic/hearing.gd`)

| Constante | Valor | Qué es |
|---|---|---|
| `HEARING_CALM` / `HEARING_ALERT` | 0.75 / 1.25 | Multiplicador de alcance: un guardia alerta escucha activamente, uno en calma va medio dormido. |
| `WALL_DAMPING` | 2.6 | Cuánto resta una pared de por medio al alcance de un ruido. |
| `SLOW_HUSH` | 0.5 | Caminar despacio a propósito hace la mitad de ruido que a esa misma velocidad sin cuidarse. |
| `LOUDNESS` (`SoundEvent.LOUDNESS`) | tabla | Alcance en casillas de cada tipo de sonido (paso, choque contra vitrina, contra pared...). |
| `CRASHES` | lista de tipos | Los golpes contra objetos (`bin`, `bust`, `panel`, `armour`, `roll_bump`, `tumble`) atraviesan paredes mejor que un paso: la mitad de amortiguación (`WALL_DAMPING * 0.5`). |

## Resumen: de dónde sale cada cosa

```
GuardSpawn (editor, por guardia)  →  posición y orientación iniciales
        │
        ▼
MapFile (por mapa)                →  cuántos guardias, qué dificultad
        │
        ▼
Sim.DIFFICULTIES + Sim.custom     →  cómo de bien ven/oyen/corren, cuánto tardan en calmarse
   (dificultad global, o          
    ajuste fino por noche de historia)
        │
        ▼
Constantes fijas de Sim/Hearing   →  la forma del cono de visión, los rangos de captura,
                                      cuánto dura cada nivel de alerta: iguales siempre
```

Si el editor crece, el hueco natural para nuevos parámetros por guardia es
`GuardSpawn`, que ya lleva la posición, la orientación, el puesto y los cuatro
deslizadores (vista, oído, agilidad, atención).

## Lo que ve toda la noche: `NightAlert`

Por encima de la sospecha de cada guardia hay una capa global (`logic/night_alert.gd`)
con cuatro modos (tranquila, sospecha, intruso, nos han robado), el evento alarma y la
regla para descubrir el robo. Todo está en la página **«Alerta y guardias»** de la web
(`docs/ALERTA.md`), con sus tablas, fórmulas y constantes.
