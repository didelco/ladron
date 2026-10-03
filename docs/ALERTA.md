# Alerta, alarma y guardias

Página de consulta: cómo viven la noche los guardias, de la sospecha de uno solo a lo que sabe todo el museo. Está escrita a mano (`docs/ALERTA.md`) a partir del código; los valores salen de `logic/night_alert.gd` salvo que se diga otro archivo. Todo lo que es un número de equilibrio lleva la nota **valor de partida, por ajustar**: son los primeros que se han puesto para probar, no los definitivos.

> Los cuatro modos de la noche son lógica interna: **no se muestran en pantalla**. Lo que se ve sobre la cabeza de cada guardia es su propio nivel de alerta (`!`, `!!`, `!!!`), que es una consecuencia del modo, no el modo.

## Las dos capas

- **Cada guardia** tiene su sospecha (`Guard.suspicion`, de 0 a 3), que sube con lo que ve u oye y baja sola con el tiempo (`Sim.step_guard`, `logic/sim.gd`). Es lo único que se dibuja.
- **Toda la noche** tiene un modo (`NightAlert`, `logic/night_alert.gd`): lo que saben todos los guardias a la vez (hay un intruso, han robado la pieza). El modo no sustituye a la sospecha de cada uno: le pone un suelo por debajo.

`NightAlert.step` corre una vez por fotograma, antes que el paso de cada guardia (`NightLoop._guards`, `scenes/night_loop.gd`).

## 1. Los cuatro modos de la noche

`NightAlert.mode(guards)` devuelve uno solo, por este orden de prioridad: intruso, nos han robado, sospecha, noche tranquila.

| Modo | Qué lo hace entrar | Qué lo hace salir | Qué cambia en los guardias |
|---|---|---|---|
| **Noche tranquila** | Es el de partida (también tras `reset`). Se vuelve a él cuando ningún guardia tiene sospecha. | Cualquier guardia sube a `!` o más. | Nada: cada uno sigue su ronda. |
| **Sospecha** | Algún guardia está en `!` o `!!` por algo oído o visto (un ruido, algo caído, humo, una luz). Viene de los propios guardias; la capa global no hace nada. | Todos a 0: un `!` se pasa a los 3,5 s (calm_after × 0,35 en dificultad media) y un `!!` baja a `!` a los 30 s sin noticias. | Nada extra: lo de cada guardia (ver 2). |
| **Intruso** | Un guardia **ve** a alguien de la banda, o **salta la alarma**. | 45 s (`INTRUDER_HOLD_S`) sin que nadie vea a nadie y con la sirena callada. Cada vez que alguien ve a alguien, o mientras suena la sirena, la cuenta vuelve a cero. | Todos los guardias a alerta (`!!`) como mínimo (`INTRUDER_FLOOR` = 2) y con la alerta que ya tenían: **sin ojos, oídos ni paso extra**. Al salir, cada uno baja por su cuenta, un escalón cada vez (ver 2). |
| **Nos han robado** | Un guardia descubre la vitrina vacía (ver 6). | Nunca, hasta el final de la noche. | Nadie baja de `!` (`ROBBED_FLOOR` = 1). Buscan por todas partes (`Mind.fallback` pasa a cazar, no a pasear) y, de vez en cuando, uno va a vigilar la salida (ver 7). Quien lo descubre se pone en `!!`. |

### Cómo conviven intruso y nos han robado

**Nos han robado es un fondo para siempre; intruso va y viene encima.** `mode()` da «intruso» mientras lo haya y, cuando se acaba, vuelve a «nos han robado» (nunca a calma). El suelo de cada fotograma es el más alto que toque: 2 con intruso, 1 si solo hay robo. Si el robo se descubre durante un intruso, los dos están activos a la vez, y al terminar el intruso los guardias bajan hasta `!` y ahí se quedan.

### Diagrama de estados

```
                 un guardia sospecha                     
   TRANQUILA ───────────────────────────► SOSPECHA
       ▲                                      │
       └──────── todos a 0 ◄──────────────────┘

   cualquiera de las dos ──ve a la banda / salta la alarma──► INTRUSO
   INTRUSO ──45 s sin ver a nadie ni sirena──► (vuelve a lo que haya debajo)

   cualquiera (también INTRUSO) ──un guardia ve la vitrina vacía──► NOS HAN ROBADO
   NOS HAN ROBADO: no se sale hasta el final de la noche;
                   INTRUSO se superpone y se quita sin salir de él.
```

Tras un intruso, los guardias aún tienen `!!`: tardan unos 30 s en bajar a `!` y unos 3,5 s más en calmarse (comprobado en `tests/test_modos.gd`: a `!` hacia los 30 s, a calma antes de los 40 s). En total, algo más de un minuto desde la última vez que se les vio.

## 2. Niveles de alerta de cada guardia

Es lo que se ve sobre la cabeza. Cada guardia lleva el suyo (`Guard.suspicion`; `Guard.alert` es el interruptor de «en alerta»).

| Nivel | Marca | Qué es | Vista, oído y paso |
|---|---|---|---|
| 0 | (nada) | Tranquilo. | Cono de calma: foco `near` 3,5, resplandor `range` 7,0, medio ángulo π/4,2 (unos 43 grados). Oído × 0,75. Pasea: velocidad 1,0 a 1,5 × la dificultad y su agilidad. |
| 1 | `!` | Corazonada: algo raro, va a mirar, pero sigue tranquilo. | Igual que el nivel 0. |
| 2 | `!!` | Alerta: está seguro de que hay alguien. | Cono de alerta: `near` 5,0, `range` 10,0, medio ángulo π/2,8 (unos 64 grados). Oído × 1,25. Marcha ligera que llega a correr (2,3 a 4,6 × lo demás). Gira la mirada más rápido (1,6 frente a 0,7) y barre. Avisa a los compañeros y revisa las luces apagadas. |
| 3 | `!!!` | Te ve (o te sabe escondido y va a sacarte). | Los de alerta, y va a por ti. |

Fuentes: `Sim.VIEW`, `Hearing.HEARING_CALM` y `HEARING_ALERT`, `Sim.step_guard` (todo en `logic/sim.gd` y `logic/hearing.gd`). Después se multiplican por la dificultad (vista, oído, velocidad), por la banda y por los rasgos del guardia (ver 5).

**Qué los sube**

- Un paso oído: `!` si estaba tranquilo, `!!` si ya tenía `!` (`Sim._alarm`).
- Algo inconfundible (un choque, un grito de un compañero, una vitrina vacía): directo a `!!` (`_alarm(…, true)`).
- Algo caído que estaba en pie, o una nube de humo a la vista: un escalón.
- Ver a alguien de la banda: `!!!`, y alerta para el resto de la ronda (`Sim.step_guard`).
- Que un compañero te avise o grite: `!!` como mínimo.
- El modo intruso: suelo de `!!` en todos. El modo nos han robado: suelo de `!`.

**Qué los baja**, sin nada nuevo que los alimente (`logic/sim.gd`):

| De | A | Cuándo | Constante |
|---|---|---|---|
| `!!!` | `!!` | 60 s sin perseguir | `CHASE_LOST_MS` = 60 000 |
| `!!` | `!` | 30 s | `ALERT_HOLD_MS` = 30 000 |
| `!` | 0 | calm_after × 0,35: 2,5 s en fácil, 3,5 s en media, 4,9 s en difícil (cada noche de la historia pone el suyo) | `HUNCH_SHARE` = 0,35 |

El suelo del modo lo impide mientras dure: `NightAlert._floor` sube al guardia al nivel y le **renueva el reloj en cada fotograma**, así que la cuenta de bajada solo empieza cuando el modo suelta.

**Relación con los modos**: intruso pone el suelo en 2 (con `alert` encendido), nos han robado en 1. Ningún modo toca un nivel que ya esté por encima del suelo.

La dificultad decide cuántas veces hay que oír algo para quedarse «seguro»: `alarms` = 3 / 2 / 1 en fácil / media / difícil. Un guardia seguro pasa directo a `!!` con cualquier pista, hasta que su `!!` se acaba.

## 3. El evento alarma

La alarma **no es un nivel ni un modo**: es un evento con su propio reloj (`NightAlert.trip`).

**Qué la dispara.** Que la ganzúa en la vitrina o la ventosa en el cuadro de alarma lleguen a **rojo** (ver 4). Nada más: ya no suena por forzar la vitrina ni mientras se trabaja. Solo puede saltar si la vitrina tiene alarma esa noche y sigue conectada (`Heist.alarm_live`: `Sim.feature("case_alarm")` y, en banda, el cuadro aún sin cortar).

**Qué pasa al saltar**

- Suena una **sirena** en bucle por todo el museo (`Sfx.siren`, `scenes/sfx.gd`, volumen 0,55), y la música sube a máxima tensión (`Game._music_mood`, `scenes/main.gd`). Se calla con la pausa.
- Cada `ALARM_NOISE_EVERY_S` = 1,5 s sale un ruido de tipo `alarm` desde donde saltó, que los guardias oyen (alcance 26 casillas antes de paredes, `SoundEvent.LOUDNESS`; antes 14).
- **Balizas rojas giratorias** (`MuseumView.set_alarm`, `scenes/museum_view.gd`): hasta 6 alrededor del museo, con cúpula, brillo que late y haz que barre el suelo (0,9 vueltas por segundo); el foco de la vitrina late en rojo (`Scenery.draw_loot`).
- Un destello rojo, un temblor de cámara, vibración del mando, la línea del registro «¡Salta la alarma!» y la **megafonía** (ver 8).
- Entra el modo **intruso** (todos a `!!`) y la atención de los guardias ante una vitrina vacía sube a su máximo (ver 6).
- Cuenta en el periódico: la cifra «ALARMAS» (`HeistStats`, `logic/heist_stats.gd`). No cuesta ninguna estrella: solo sale en la noticia.

**Cuánto dura y cómo se reinicia.** Suena `ALARM_S` = 20 s. Si salta otra vez mientras suena, **la cuenta vuelve a 20 s** (no se suman ni se solapan). Al callar, el modo intruso sigue su cuenta de 45 s.

**Qué NO hace**: no descubre el robo. La alarma sola no pasa a «nos han robado»; lo único que hace sobre ello es subir la atención de los guardias (×2,5) para cuando miren la vitrina vacía. Y se reinicia entera cada ronda (ver 9).

## 4. Ganzúa y ventosa de colores

Cada **gancho** que se trabaja tiene un color (`Minigame.hook_colour`, `logic/minigame.gd`): un perno de la ganzúa, una lámpara de la ventosa. Solo cuenta con la alarma conectada; si no, se queda verde pase lo que pase.

| Fallos en ese gancho | Color | Qué pasa |
|---|---|---|
| 0 | verde | Nada. |
| 1 (`ORANGE_AT`) | naranja | Aviso en la caja del minijuego. |
| 2 (`RED_AT`) | rojo (parpadea) | Salta la alarma, una sola vez por gancho. Más fallos en el mismo no la disparan de nuevo. |

- **Ganzúa** (`logic/minigames/lockpick.gd`): cada pulsación fuera del verde cuenta, aunque sea muy lejos (un fallo «salvaje» también); las que caen mientras la ganzúa se asienta (0,45 s tras un fallo) no se leen. Al acertar y pasar al perno siguiente, **vuelve a verde**: el contador se reinicia por enganche. Abierta limpia, nunca suena.
- **Ventosa** (`logic/minigames/steady.gd`): salir del aro estando dentro cuenta un fallo en la lámpara que se está encendiendo; dos antes de que se encienda la siguiente, rojo. Cada lámpara encendida vuelve a verde. Vale en el cuadro de alarma y, algunas noches, en la vitrina.
- **El cuadro de alarma** (con dos o más ladrones): su ventosa también puede dispararla, **allí en el cuadro**. Cortado el cuadro (los dos, con cuatro), la vitrina queda sin alarma y su ganzúa ya no cuenta.

**Desde qué noche**: en la historia, desde la **noche 11** (primera del museo 3, la que lo enseña; `case_alarm` es `true` desde ahí en `Story.LEVELS`, `logic/story.gd`). En las noches 1 a 10 la ganzúa no cuenta fallos y no puede saltar. Fuera de la historia (mapas, misiones, generativo) está activa salvo que se apague; la casa y el dojo la tienen apagada.

## 5. Características de los guardias

Cuatro deslizadores por guardia, del 0 (el peor) al 4 (el mejor); el 2 es el guardia normal y vale 1,0, así que **no mueve nunca los diales de dificultad** (`GuardSpawn`, `logic/guard_spawn.gd`; se editan en el editor de mapas, `scenes/editor/guard_panel.gd`).

| Nivel | Vista (× alcance) | Oído (× alcance) | Agilidad (× velocidad) | Atención (× probabilidad de descubrir el robo) |
|---|---|---|---|---|
| 0 | 0,6 · cegato | 0,6 · sordo | 0,7 · cansado | 0,5 · despistado |
| 1 | 0,8 · poca vista | 0,8 · duro de oído | 0,85 · lento | 0,75 · poco atento |
| 2 | 1,0 · normal | 1,0 · normal | 1,0 · paso normal | 1,0 · atención normal |
| 3 | 1,2 · buena vista | 1,2 · oído fino | 1,15 · ágil | 1,25 · atento |
| 4 | 1,4 · vista de lince | 1,4 · oído de sabueso | 1,3 · veloz | 1,5 · muy atento |

La **Atención** es el rasgo nuevo (`attention_scale` en el guardia): cuánto se le nota a un guardia que una vitrina que mira está vacía. Vista, oído y agilidad se multiplican por los diales de la dificultad y de la banda (`Sim.tuning`); la atención va aparte, en la fórmula de la sección 6.

**Arquetipos** (el desplegable del editor los aplica de una vez; después manda cada deslizador):

| Arquetipo | Vista | Oído | Agilidad | Atención |
|---|---|---|---|---|
| Estándar | 2 | 2 | 2 | 2 |
| Vigía | 4 | 2 | 2 | 3 |
| Sabueso | 2 | 4 | 2 | 2 |
| Dormilón | 2 | 1 | 0 | 0 |
| Veterano | 3 | 3 | 2 | 3 |

## 6. Cómo se descubre el robo

Una vez cogida la pieza (`Heist.taken`), la vitrina queda vacía. **Nadie va a mirarla a propósito** (hay muchas vitrinas): se descubre solo si **la vitrina vacía cae en lo que está mirando un guardia**, es decir:

1. dentro de su cono de visión (salvo a menos de 1,1 casillas, `Sim.TOUCH_RANGE`, que lo nota mirando a donde mire);
2. dentro de lo que ve **ahora** (su alcance: ver abajo);
3. sin pared en medio y sin humo.

**Tiempos.** Cuando la vitrina entra en su mirada, a los **200 ms** (`FIND_FIRST_MS`) hace una tirada, y otra cada **500 ms** (`FIND_EVERY_MS`) mientras la siga mirando. Si deja de mirarla, se olvida y, al volver, otra vez 200 ms de espera. Las tiradas usan su propio azar: no tocan el del museo.

**Fórmula**

```
probabilidad por tirada = BASE × atención × cercanía        (entre 0 y 1)

atención  = rasgo de atención del guardia × multiplicador del estado
cercanía  = (1 − distancia / alcance)²                       (0 fuera del cono, del alcance o con pared o humo)
```

| Estado del guardia (el que más alto aplique) | Multiplicador |
|---|---|
| Tranquilo | × 1,0 (`ATTENTION_CALM`) |
| Sospecha `!` | × 1,5 (`ATTENTION_SUSPECT`) |
| En alerta `!!`, o la noche en modo intruso | × 2,0 (`ATTENTION_ALERT`) |
| Alarma sonando | × 2,5 (`ATTENTION_ALARM`) |

- `BASE` = 0,25 (`FIND_BASE`).
- **Alcance** = lo que ve en ese momento (`Sim.view_of`): `range` del cono de calma (7,0) o de alerta (10,0), por la dificultad, la banda y su rasgo de vista; **40 casillas** (`Sim.LIT_RANGE`) si la sala de la vitrina tiene la luz encendida, donde solo manda la línea de visión. En alerta ve más lejos y por eso la cercanía, a la misma distancia, también sube.
- La **cercanía** cae con el cuadrado: a media distancia solo queda un cuarto de la probabilidad que hay pegado a la vitrina.
- Con la alarma sonando el multiplicador es 2,5 en todos, pero la alarma **no descubre nada por sí sola**: solo afecta a quien mire una vitrina vacía.

**Ejemplo calculado** (dificultad media, un ladrón, vitrina a oscuras, alcance 7 casillas en tranquilo o sospecha, 10 en alerta o alarma). Cada celda: probabilidad por tirada · tiempo medio hasta descubrirlo si no deja de mirarla.

**Guardia normal (atención 1,0)**

| Estado | A 2 casillas | A 4 casillas | A 6 casillas |
|---|---|---|---|
| Tranquilo | 12,8 % · 3,6 s | 4,6 % · 10,6 s | 0,5 % · 98 s |
| Sospecha `!` | 19,1 % · 2,3 s | 6,9 % · 7,0 s | 0,8 % · 65 s |
| Alerta `!!` | 32,0 % · 1,3 s | 18,0 % · 2,5 s | 8,0 % · 5,9 s |
| Alarma sonando | 40,0 % · 0,9 s | 22,5 % · 1,9 s | 10,0 % · 4,7 s |

**Guardia muy atento (atención 1,5)**

| Estado | A 2 casillas | A 4 casillas | A 6 casillas |
|---|---|---|---|
| Tranquilo | 19,1 % · 2,3 s | 6,9 % · 7,0 s | 0,8 % · 65 s |
| Sospecha `!` | 28,7 % · 1,4 s | 10,3 % · 4,5 s | 1,1 % · 43 s |
| Alerta `!!` | 48,0 % · 0,7 s | 27,0 % · 1,6 s | 12,0 % · 3,9 s |
| Alarma sonando | 60,0 % · 0,5 s | 33,8 % · 1,2 s | 15,0 % · 3,0 s |

El tiempo medio es 0,2 + 0,5 × (1/p − 1) segundos: el primer intento a los 200 ms y uno más cada 500 ms hasta que sale. Es el tiempo con la vitrina **siempre a la vista**; un guardia que pasa de largo no llega a hacer ni una tirada. Un dormilón (atención 0,5) tiene la mitad de probabilidad por tirada, y con la luz de la sala encendida la cercanía casi no cae con la distancia.

**Al descubrirlo** (`NightAlert._found`): entra el modo nos han robado, el guardia que lo ha visto se pone en `!!` y se anota su nombre, el registro dice «X ve la vitrina vacía: ¡han robado la pieza!», y la megafonía dice por fin «robada» (ver 8). La salida recibe a su primer vigilante enseguida.

## 7. Nos han robado

- **Suelo de nivel**: nadie baja de `!` hasta el final de la noche (`ROBBED_FLOOR`).
- **Búsqueda**: todos los guardias cazan en vez de pasear. `Mind.fallback` (`logic/mind.gd`) usa el orden de alerta (perseguir, seguir, buscar, revisar zona, cubrir, patrullar, vigilar), con la mirada barriendo y más agresividad. El texto que recibe la IA (Laya) también cuenta que la pieza ha desaparecido.
- **Vigilar la salida a ratos**: cada `DOOR_EVERY_S` = 60 s el guardia libre más cercano a la salida (no persigue, no está de recado, sospecha menor que 3) va a ponerse en un punto de suelo a 3 a 4 casillas de la salida (`DOOR_NEAR` y `DOOR_FAR`), con la salida a la vista y lo más despejado posible. Allí está **20 s** (`DOOR_STAND_S`) mirando hacia la puerta con la linterna balanceándose; si no ha llegado en **30 s** (`DOOR_WALK_S`), lo deja. Una persecución o un aviso lo sacan del recado, y el siguiente turno es a los 60 s. El primero va nada más descubrirse el robo.

## 8. Megafonía

La megafonía (`Megaphone`, `scenes/megaphone_run.gd`) ya no comenta lo que el jugador aún no ha provocado. **Espera a que pase algo de verdad**:

| Comentario | Cuándo sale ahora |
|---|---|
| «alarma» | Solo cuando salta la alarma (evento `alarm`). |
| «robada» (`stolen`) | Solo cuando un guardia descubre el robo (evento `robbed`), no al coger la pieza. |
| «alguien abre la vitrina» (acción `case`) | Solo si la alarma está sonando en ese momento; abierta en silencio, no dice nada. |

Los dos primeros pasan por `NightLoop.alert_events` y el tercero por `NightLoop._do_action` (`scenes/night_loop.gd`). El resto de avisos no cambia.

## 9. Modelo de datos

**Capa global** (`NightAlert`, todo estático en `logic/night_alert.gd`):

| Campo | Qué guarda |
|---|---|
| `alarm_left`, `alarm_at`, `alarms` | segundos que le quedan a la sirena (0: callada), dónde saltó y cuántas veces esta noche |
| `intruder`, `quiet` | modo intruso encendido, y segundos desde que nadie vio a nadie con la sirena callada |
| `robbed`, `found_by` | pieza descubierta, y el nombre de quien la descubrió |
| `door_guard`, `door_spot`, `door_clock`, `door_left` | quién vigila la salida, desde dónde, segundos desde el último enviado y segundos de plantón que le quedan (−1 hasta que llega) |
| `clock` | reloj de la noche en ms (avanza con el `dt`, la pausa no lo corre) |
| `aims`, `rolls` | por guardia, cuándo toca su próxima tirada; tiradas hechas (las cuentan los tests) |
| `events` | lo ocurrido desde la última vez que `NightLoop` miró: `alarm`, `alarm_off`, `intruder`, `intruder_off`, `robbed` |
| `rng`, `_noise_in` | sus propios dados, y cuenta atrás del siguiente ruido de sirena |

**Campos nuevos del guardia** (`logic/guard.gd`): `attention_scale` (el rasgo, 1,0 por defecto), el recado `errand = "door"` y `errand_at` (la casilla donde plantarse). En el editor, `GuardSpawn.attention_level` (0 a 4, por defecto 2) y las listas `STATS`, `LEVELS` y `LEVEL_LABELS` ganan la entrada `attention`. `Sim.place_guards` copia el nivel a `attention_scale` al empezar la noche.

**Lo que se guarda en el mapa** (`logic/map_file.gd`): cada guardia del mapa lleva, además de `view`, `hearing` y `speed`, un campo **`attention`** (0 a 4; al leer se acota, y si falta, como en los mapas antiguos, vale 2). El modo y la alarma no se guardan nunca: son de la noche.

**Dónde se pone a cero** (`NightAlert.reset`): en `Heist.plan_job` (cada trabajo nuevo) y en `Game._new_round` (`scenes/main.gd`), junto a `HeistStats.reset`. Reiniciar vuelve todo a «noche tranquila» y renueva los dados. Al generar un museo para una vista previa (`scenes/challenge_screens.gd`) el estado se aparta y se restaura, para que no pise la noche en curso.

## 10. Constantes ajustables

Todas, salvo las que se dice, son **valor de partida, por ajustar**.

| Constante | Valor | Archivo | Para qué sirve |
|---|---|---|---|
| `ALARM_S` | 20 s | `logic/night_alert.gd` | cuánto suena la sirena; otro rojo reinicia la cuenta |
| `ALARM_NOISE_EVERY_S` | 1,5 s | `logic/night_alert.gd` | cada cuánto oyen los guardias la sirena |
| `INTRUDER_HOLD_S` | 45 s | `logic/night_alert.gd` | tiempo de intruso sin ver a nadie ni sirena |
| `INTRUDER_FLOOR` | 2 | `logic/night_alert.gd` | nivel mínimo de cada guardia en intruso (`!!`) |
| `ROBBED_FLOOR` | 1 | `logic/night_alert.gd` | nivel mínimo con la pieza descubierta (`!`) |
| `FIND_BASE` | 0,25 | `logic/night_alert.gd` | probabilidad base por tirada de descubrir el robo |
| `FIND_FIRST_MS` | 200 ms | `logic/night_alert.gd` | espera hasta la primera tirada |
| `FIND_EVERY_MS` | 500 ms | `logic/night_alert.gd` | tiempo entre tiradas |
| `ATTENTION_CALM` | 1,0 | `logic/night_alert.gd` | multiplicador de atención, tranquilo |
| `ATTENTION_SUSPECT` | 1,5 | `logic/night_alert.gd` | con `!` |
| `ATTENTION_ALERT` | 2,0 | `logic/night_alert.gd` | con `!!` o en modo intruso |
| `ATTENTION_ALARM` | 2,5 | `logic/night_alert.gd` | con la sirena sonando |
| `DOOR_EVERY_S` | 60 s | `logic/night_alert.gd` | cada cuánto se envía a uno a vigilar la salida |
| `DOOR_STAND_S` | 20 s | `logic/night_alert.gd` | cuánto se queda allí |
| `DOOR_NEAR` y `DOOR_FAR` | 3,0 y 4,0 casillas | `logic/night_alert.gd` | banda de distancia a la salida desde donde vigila |
| `DOOR_WALK_S` | 30 s | `logic/night_alert.gd` | tiempo máximo para llegar antes de rendirse |
| `ORANGE_AT` y `RED_AT` | 1 y 2 fallos | `logic/minigame.gd` | fallos por gancho para naranja y para rojo (alarma) |
| `LEVELS.attention` | 0,5 a 1,5 | `logic/guard_spawn.gd` | multiplicador de cada nivel de atención del guardia |
| `LOUDNESS["alarm"]` | 26 | `logic/sound_event.gd` | alcance en casillas del ruido de la sirena |
| `CHASE_LOST_MS` | 60 000 ms | `logic/sim.gd` | `!!!` pasa a `!!` tras perder de vista (valor ya existente) |
| `ALERT_HOLD_MS` | 30 000 ms | `logic/sim.gd` | `!!` pasa a `!` (valor ya existente) |
| `HUNCH_SHARE` | 0,35 | `logic/sim.gd` | parte de calm_after que dura un `!` (valor ya existente) |
| `VIEW` | calma 3,5 / 7,0 / π÷4,2 · alerta 5,0 / 10,0 / π÷2,8 | `logic/sim.gd` | foco, resplandor y medio ángulo de la vista (ya existente) |
| `LIT_RANGE` | 40 | `logic/sim.gd` | alcance en sala con luz (ya existente) |
| `SIREN_VOLUME` | 0,55 | `scenes/sfx.gd` | volumen de la sirena |
| `MAX_BEACONS`, `BEACON_TURNS` | 6 y 0,9 vueltas por segundo | `scenes/museum_view.gd` | balizas rojas y su giro |

Los **diales de dificultad** (`view`, `hearing`, `speed`, `calm_after`, `alarms`) siguen como se explican en `docs/guardias_parametros.md`.

## Lo que quedó cambiado respecto a antes

- La vitrina **ya no pita mientras se fuerza**: el ruido de `alarm` por forzar y su cadencia (`ALARM_EVERY_MS`) desaparecieron de `logic/heist.gd`. Ahora la alarma es un evento que salta por fallos (secciones 3 y 4).
- Abrir la vitrina, o coger la pieza, ya **no hace decir «robada» a la megafonía**: solo un guardia al descubrir la vitrina vacía.
- El ruido de la alarma pasó de alcance 14 a 26.
- Una pieza robada ya no es una noticia instantánea para todos: hay que **verla**.
