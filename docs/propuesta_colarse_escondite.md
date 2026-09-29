# Propuesta: colarse en un escondite

## El problema (medido)

El minijuego anterior (`SqueezeGame`, meneos izquierda-derecha):

- 7, 8 o 9 meneos por nivel (+1 en muebles ajustados) con 0,32 s de asentamiento entre uno y otro: de 2,2 s a 5 s de pulsar dos teclas seguidas, a la vista.
- Repetitivo: siempre el mismo gesto, sin variación ni decisión, igual en fácil que en difícil (solo cambiaba el número).
- Absurdo: el riesgo (el guardia) no intervenía en nada; retorcerse a un lado y a otro no tenía relación con el mueble ni con quien mira.
- En el dojo no había guardias, así que la prueba ESCONDITE no enseñaba nada distinto por nivel.

## Cómo lo resuelven otros

- Metal Gear, Hitman, Dishonored, Untitled Goose Game: esconderse es un gesto instantáneo (un botón junto al escondite). El riesgo está en cuándo lo haces, no en cuánto pulsas.
- Cuando hay minijuego es de una sola pulsación (elegir el momento).

## Opciones

1. **Quitar el minijuego.** Entrar es la acción y ya; la animación depende del mueble. Pros: lo más corto, cero código de entrada. Contras: la prueba ESCONDITE del dojo desaparece y el nivel no enseña nada; no queda tensión.
2. **Un empujón y hundirse (elegida).** Un pulso de la acción y el ladrón se hunde (0,7 a 1 s). Empujar a la vista de un guardia lo atasca y lo hunde a cámara lenta (x2): el riesgo es el guardia. En el dojo, una linterna propia barre el sitio. Pros: corto (1 s fácil, 3 s como mucho en difícil), una sola tecla (la de siempre), enseña algo distinto por nivel, se entiende con una flecha y una barra roja. Contras: hace falta pasar «me ven» al minijuego (`watched`).
3. **Tiempo bala.** Una ventana estrecha en la que hay que pulsar cuando el guardia mira a otro lado. Pros: la más tensa. Contras: en un robo puede no llegar nunca la ventana; obliga a esperar sin poder hacer nada; difícil de enseñar en el dojo sin guardias.

## Elegida: opción 2

- Fácil: un empujón y dentro (~1 s). Aprende: la acción mete.
- Medio: un empujón, con una linterna que barre (35 % de la vuelta de 2,2 s): empujar a la vista hunde a cámara lenta. Aprende: elige el momento.
- Difícil: dos empujones (mitad y mitad), linterna encendida el 40 %. Aprende: elegir el momento dos veces (~3 s como mucho).
- Un mueble ajustado (`Hideouts.TIGHT`) se hunde 0,2 s más por empujón; el temblor de los guardias alarmados, hasta 0,15 s.
- El estornudo (`SneezeGame`) sigue siendo el minijuego largo de quedarse dentro; no se toca.
