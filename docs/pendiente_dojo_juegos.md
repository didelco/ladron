# Pruebas del dojo: estado y pendiente

## Cómo está hecho

Nueve pruebas, todas iguales (`DojoTrials.TABLE`, `DojoTrial`; ver «Las pruebas del dojo, todas iguales» y «Cómo añadir una prueba al dojo» en el README):
PILLA EL CALCETÍN, EQUILIBRIO, BOLOS, AGUANTA ESCONDIDO (`DojoGame`, rondas y récord de nivel), GANZÚA, ESCONDITE, CABLES, PULSO
(`BenchTrial`: una tirada del minijuego de un robo por dificultad, récord de tiempo, se falla con el reloj) y CIRCUITO (`CircuitTrial`).

Croquis del dojo (`Den.DOJO_PLAN`, 41 × 28 casillas desde el (21, 1); `#` muro, los huecos son pasillos de tres casillas):

```
 x:  21            34 35            48 49          61
 y1  +-------------+-+--------------+-+-------------+
     |  GANZÚA     |  CABLES         |  PULSO        |   alarma y vitrinas
     |  3 vitrinas    3 cajas en el muro norte        |
     |  (24,5)(27,5)(30,5) (37,1)(41,1)(45,1) (51,1)(55,1)(59,1)
 y9  +--    --------+-+---    -------+-+---    -------+
     |  CALCETÍN   |  EQUILIBRIO     |  BOLOS        |   juegos de habilidad
     |  3 pedestales  3 pedestales     3 círculos     |   (salón: puerta en (20,11-12))
     |  (24,15)(27,15)(30,15) (38,15)(41,15)(44,15) (52,14)(55,14)(58,14)
y18  +--    --------+-+---    -------+-+---    -------+
     |  CIRCUITO   |  ESCONDITE      |  AGUANTA      |   sigilo
     |  carriles con  3 muebles        3 armaduras +  |
     |  muros, cajas  (38,23)(41,23)   caja y taquilla|
     |  y 3 guardias  (44,23)          linterna (54,23)
y29  +---  puerta al aseo (27-28, 29) ----------------+
     ASEO (21..29, 30..36), bajo el circuito
```

Circuito: entra por el norte (26-28, 19) o por el este (34, 22-24); anillos de inicio en (21,20), (23,20) y (25,20); meta en (33, 27);
tres espantapájaros que giran (`turn: {amp, speed, phase}`): (33,19), (21,23) y (31,28). Fácil / medio / difícil barren a 0,7 / 1 / 1,4 veces y dan 90 / 75 / 60 s.

## Decisiones

- Los espantapájaros de guardia solo existen en el circuito (nunca en el resto del dojo). AGUANTA ESCONDIDO usa su espantapájaros temporal (`Practice.LANTERN_AT`); las rondas «vigiladas» de PILLA EL CALCETÍN
  (niveles 7 a 10) colocan el calcetín en el cono de los del circuito (`DojoField.ALIASES["circuito"]`), que está pegado a la bahía de PILLA EL CALCETÍN.
- SEGUIR empieza la siguiente dificultad desde el mismo punto (sin mover al ladrón); el objeto que se ilumina al superar una prueba del banco es el del punto donde se empezó.
- El aseo se movió bajo el dojo (`Den.BATH_DY`), sin puerta al salón.
- Zonas de los niveles de los juegos: `juegos`, `alarma`, `escondites`, `circuito` (grupos de bahías, `DojoField.ALIASES`).

## Pendiente

- ESCONDITE está integrado solo a nivel de flujo (`BenchTrial`, `Minigame.make("squeeze", "bench", …)`); si el minijuego `squeeze` cambia, se adapta en su fila de `DojoTrials.TABLE` (`pieces`, `limit`) y en `BenchTrial.steps_for`.
- Puertas que cierran los juegos (`gates_closed`): `Den` no tiene `dojo_gates()`; los niveles «con puerta» degradan.
- Al cerrar el bloque: capturas de documentación e hitos (`python3 tools/docs.py build shots`), no antes.
