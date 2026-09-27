// Lo que significan las cosas del juego, en español, para las páginas de minijuegos,
// escondites, colección y la previa. Escrito a mano (como pantallas.js y ESTILO.md):
// los valores, las listas y los textos salen del código (docs/data/codigo.js y
// juego.js); aquí solo se dice qué es cada cosa. Si cambia el sentido de una
// constante, se cambia aquí; si aparece una nueva, la página la enseña igual, con el
// comentario del código, hasta que se escriba aquí.
//
// Cada constante: NOMBRE: "qué es" (y la unidad, si la tiene).
window.MECANICAS = {
  minijuegos: {
    intro: "Los trabajos que se hacen con las manos, en una cajita al lado del ladrón (nunca encima), como en Among Us: el mundo sigue mientras tanto, así que cuanto más se tarda, más rato se está a la vista. Cada uno tiene tres niveles (fácil, medio, difícil) y a las manos asustadas les tiembla el pulso: cuanto más alarmados están los guardias, más difícil (el temblor va de 0 a 1 según la sospecha del más alarmado). Solo cuentan las pulsaciones: lo que ya estaba pulsado al abrirse no vale. Se suelta con la tecla de rodar (B), menos el estornudo, que se deja saliendo del escondite.",
    comun: {
      lockpick_from: "Desde el robo {n} de la historia (LOCKPICK_NIGHT), la vitrina se abre con ganzúa y el cuadro de alarma se corta a mano; antes, basta con quedarse quieto al lado.",
      niveles: "El nivel lo pone el robo: el primer museo con minijuegos los juega en fácil, cada museo sube un paso y un gran golpe, uno más (Story.tuning, «game_level»). Fuera de la historia, la dificultad elegida.",
      nuevo: "Uno nuevo: logic/minigames/<tipo>.gd (su lógica), scenes/minigame_views/<tipo>.gd (cómo se ve), una línea GAME_HOW_<TIPO> en locale/texts.csv, y quien lo empiece llama a Minigame.make(\"<tipo>\", …). Nada más necesita saber que existe.",
    },
    // En el orden en que salen en el juego.
    orden: ["lockpick", "wires", "steady", "balance", "squeeze", "sneeze", "arcade"],
    juegos: {
      lockpick: {
        nombre: "La ganzúa", donde: "En la vitrina de la pieza", clase: "de hacer: no se falla, solo se tarda",
        texto: "Una esfera en la cerradura con una aguja que da vueltas y un sector verde en el borde: se pulsa la acción cuando la aguja pasa por el verde y cae un perno; el verde cambia de sitio en cada uno. Un fallo hace resbalar la ganzúa un momento. Cada fallo cerca del mismo perno lo afloja (el verde se ensancha), así que quien insiste siempre llega. Con temblor, la aguja vibra y el verde se estrecha. De 1 a 4 pernos, según los segundos que pide la pieza.",
        consts: { PIN_PERIOD: "segundos que tarda la aguja en dar una vuelta", PIN_BAND: "medio ancho del sector verde (parte de la vuelta)", SHAKE_NARROW: "cuánto se estrecha el verde con todo el temblor", SHAKE_JITTER: "cuánto vibra la aguja con todo el temblor", SLIP_S: "segundos sin responder tras un fallo", GIVE: "cuánto se ensancha el verde por cada fallo cerca (parte de PIN_BAND)" },
      },
      wires: {
        nombre: "Los cables", donde: "En el cuadro de alarma", clase: "de hacer",
        texto: "Una fila de cables; sobre el siguiente a cortar, una flecha dice hacia dónde tirar de las tenazas: se pulsa esa dirección. Al revés salta una chispa y las manos se apartan un momento. Con temblor, se tarda más en afinar el siguiente cable.",
        consts: { SPARK_S: "segundos con las manos fuera tras una chispa", STEADY_S: "segundos para afinar el siguiente cable con todo el temblor", WIRES_LEVEL: "cables por nivel (fácil, medio, difícil)" },
      },
      steady: {
        nombre: "La ventosa", donde: "En el cristal del cuadro de alarma (o de la vitrina, algunas noches)", clase: "de hacer",
        texto: "Una ventosa sobre el cristal que se va sola hacia un lado u otro; las direcciones la devuelven. Si aguanta dentro del aro los segundos que hacen falta, seguidos, el cristal está cortado; si sale, la cuenta vuelve a empezar. Los niveles altos tienen el aro más pequeño y la deriva más fuerte; el temblor la vuelve más loca.",
        consts: { CUP: "radio de la ventosa (el aro fácil mide 1)", DRIFT: "fuerza de la deriva", RING_LEVEL: "tamaño del aro por nivel", DRIFT_LEVEL: "fuerza de la deriva por nivel", PUSH: "fuerza con que la empujan las teclas", DAMP: "cuánto se frena", GUST_S: "cada cuántos segundos cambia de idea la deriva" },
      },
      balance: {
        nombre: "El equilibrio", donde: "Posando como estatua en un pedestal", clase: "de aguantar: se puede fallar",
        texto: "A la pata coja sobre un pedestal, el ladrón se balancea y se inclina; izquierda y derecha lo mantienen. Pasado el punto sin vuelta, se cae, y eso hace ruido. No acaba solo: dura lo que dure la pose, cada segundo un poco más difícil (muy despacio), y además más cuanto más cerca están los guardias (y un poco con la luz encendida). Los toques cortos lo equilibran; mantener una tecla empuja cada vez más fuerte y lo tira al otro lado. Si se inclina mucho, suda y se tambalea, y un guardia que mire ve que no es una estatua.",
        consts: { TOPPLE: "lo rápido que crece la inclinación sola", LEAN_DAMP: "cuánto se frena el vaivén", TAP_KICK: "el empujoncito de un toque", PUSH_BASE: "empuje de una tecla mantenida al principio", HOLD_DOUBLE: "segundos en que se dobla el empuje mantenido", PUSH_MAX: "empuje máximo", NUDGE: "fuerza de los empujones que vienen de la nada", NUDGE_S: "cada cuántos segundos llega uno", TOPPLE_LEVEL: "lo rápido que se cae, por nivel", TIRE_LEVEL: "cuánto más difícil cada segundo, por nivel", PRESSURE_TOPPLE: "cuánto más se cae con los guardias encima", PRESSURE_NUDGE: "cuánto más fuertes los empujones con los guardias encima", FALL: "inclinación a la que se cae", WOBBLE: "inclinación a la que suda y un guardia lo nota" },
      },
      squeeze: {
        nombre: "Colarse en un escondite", donde: "Al meterse en un escondite", clase: "de hacer",
        texto: "El ladrón se mete retorciéndose: izquierda, derecha, izquierda, derecha, cada vez un poco más dentro. Un meneo solo cuenta cuando el cuerpo se ha asentado del anterior: machacar no sirve, y uno demasiado pronto, o dos al mismo lado, lo atasca un momento. No se falla, solo se tarda: de unos dos segundos, tranquilo y en un sitio holgado, a unos cinco, en uno estrecho y con los guardias alarmados. Todo ese rato, a la vista.",
        consts: { WRIGGLES_LEVEL: "meneos para entrar por nivel, más los del escondite (Hideouts.TIGHT)", SETTLE_S: "segundos para que el cuerpo se asiente", SHAKE_SETTLE: "cuánto más tarda con todo el temblor", STUCK_S: "segundos atascado tras un meneo mal hecho" },
      },
      sneeze: {
        nombre: "El estornudo", donde: "Escondido, al rato de estar dentro", clase: "de aguantar: se puede fallar",
        texto: "Tras unos segundos tranquilo dentro de un escondite, el polvo hace cosquillas: llegan picores por un carril, de izquierda a derecha, a ritmo, hacia la nariz; hay que pulsar la acción cuando cada uno pasa por la barra. Si uno llega a la nariz, o se falla demasiadas veces, ¡ACHÍS!: fuera del escondite, un momento en el suelo, y lo oyen todos los guardias cercanos. No acaba mientras se sigue dentro: cuanto más rato y más alarmados los guardias, más estrecha la barra y más rápido el ritmo. Es más fácil que la ganzúa: la barra empieza ancha. Se deja saliendo del escondite (cualquier dirección), no soltando.",
        consts: { CALM_S: "segundos tranquilo dentro antes de los picores", STUN_S: "segundos en el suelo tras el estornudo", BAR_X: "dónde está la barra en el carril (de -1 a 1)", BAR: "medio ancho de la barra al principio", NARROWEST: "medio ancho de la barra al final", SHRINK_S: "segundos dentro hasta la barra más estrecha", SHAKE_NARROW: "cuánto se estrecha con todo el temblor", BAR_LEVEL: "ancho de la barra por nivel", BEAT: "segundos entre picores al principio", QUICKEST: "segundos entre picores al final", SPEED: "velocidad de un picor (carriles por segundo)", MISSES: "fallos que hacen estornudar", CALM_HITS: "aciertos seguidos que perdonan un fallo", SLIP_S: "segundos sin responder tras un fallo" },
      },
      arcade: {
        nombre: "La recreativa", donde: "Delante de una máquina recreativa de la edad moderna", clase: "de broma: no se gana ni se acaba",
        texto: "Un pong contra la máquina: arriba y abajo mueven la pala. Es una broma: no hay nada que ganar, nunca acaba y solo se sale soltando («DEJA DE PERDER EL TIEMPO», con la tecla de siempre). Mientras, el ladrón está ahí de pie jugando, a la vista, y los guardias siguen su ronda. El marcador es solo por orgullo. Pueden jugar varios ladrones, cada uno en su máquina; todas juegan al pong, aunque cada una enseña un juego distinto en la pantalla.",
        consts: { HALF_W: "medio ancho de la pista", HALF_H: "medio alto de la pista", PADDLE_X: "dónde están las palas", PADDLE_H: "medio alto de una pala", BALL: "medio tamaño de la bola", MY_SPEED: "velocidad de tu pala", CPU_SPEED: "velocidad de la de la máquina (más lenta: se le puede ganar)", SERVE: "velocidad de la bola al sacar", FASTEST: "velocidad máxima de la bola", SPEED_UP: "cuánto acelera en cada golpe", STEEPEST: "ángulo máximo al salir de una pala (radianes)", SLOPPY: "cuánto se descuida la máquina (medias palas)", PAUSE_S: "segundos de pausa tras un punto" },
      },
    },
  },
  escondites: {
    intro: "Sitios donde meterse. Junto a uno, la acción mete dentro (con el minijuego de colarse); cualquier dirección saca, al suelo libre de ese lado. Dentro no se hace ruido y ningún guardia te ve. Pero, como la estatua, solo funciona sin testigos: si un guardia te ve entrar, se acuerda, va directo a por ti y, al llegar, te saca; uno que no te vio pasa de largo. Al rato de estar dentro llega el estornudo.",
    siempre: "Todo lo que parece un escondite lo es: cada pieza grande en la que se cabe, cada armadura de pie y cada mueble de escondite del museo. Lo que evita que sea demasiado fácil es que hay pocos y separados: el generador pone solo unas pocas piezas grandes, los objetos solo unas pocas armaduras, y cada noche añade muebles (y pedestales para posar) hasta la cuota del museo, lejos unos de otros. Un mapa guardado conserva lo que se puso a mano.",
    tipos: "Tres clases: las piezas grandes en las que se cabe (el sarcófago, el caballo de Troya, el mamut bajo su pelo, el tronco hueco y el cochecito en su tarima); los muebles, en una casilla de vitrina, uno por tema; y una armadura todavía de pie (se entra dentro; si alguien la tira contigo dentro, sales rodando).",
    consts: { REACH: "distancia (al borde) para meterse", GRAB: "distancia a la que un guardia que lo sabe te saca", PER_TILES: "casillas abiertas por cada escondite o pedestal", MIN: "mínimo por museo (si hay sitio)", PLINTH_EVERY: "de cada tantos, uno es pedestal", BIG_SHARE: "parte de los escondites que son piezas grandes", APART: "distancia mínima entre dos (casillas, de centro a centro)" },
    pedestales: { REACH: "distancia para subirse", HEIGHT: "altura del pedestal (m)", GRAB: "distancia a la que un guardia que lo sabe te baja", FALL_DOWN_S: "segundos en el suelo al caerse", GUARD_NEAR: "a cuántas casillas empiezan a poner nervioso", LIT_PRESSURE: "cuánto más difícil con la luz encendida" },
  },
  coleccion: {
    intro: "Lo que hay en cada vitrina del museo esta noche se decide una vez para todo el museo (logic/collection.gd): lo pinta la vista (MuseumView) y de ahí se sacan las recreativas (Arcades), así que las dos cosas nunca se contradicen. La pieza de una casilla sale del tema de su sala y de un número que depende de sus coordenadas, así que el mismo museo siempre se ve igual; y el museo lleva la cuenta de lo que ha puesto, casilla a casilla:",
    reglas: [
      "una pieza única (Themes.UNIQUE) sale una vez como mucho: una segunda sería una copia;",
      "una pieza con variantes (Themes.VARIANTS, la recreativa) es distinta cada vez; cuando se acaban las variantes, el sitio se queda con otra pieza;",
      "una pieza con frente (Themes.FRONTED: la recreativa, el trono, Anubis) solo va donde tenga suelo libre al que mirar;",
      "lo que un mapa guardado puso a mano se respeta tal cual y se cuenta primero;",
      "la vitrina del robo se queda vacía, sea lo que sea que fuera a enseñar: así el resto del museo no cambia según dónde esté la pieza de esta noche.",
    ],
    fuera: "No las decide la colección: los pedestales vacíos (Plinths), los muebles para esconderse (Hideouts), las piezas grandes y la vitrina del robo.",
    consts: { TRIES: "intentos por casilla antes de conformarse con una vitrina de colores", CASE_SHARE: "de lo que hay en una sala temática, parte en vitrina", PLINTH_SHARE: "parte en peana (el resto, en el suelo)" },
    recreativa: "La recreativa de la edad moderna tiene seis juegos (MuseumView.ARCADE_GAMES): cada máquina de un museo enseña uno distinto, con su mueble, su marquesina y su dibujo en la pantalla (16 × 9 píxeles). Los materiales del modelo que empiezan por color_mueble y color_marquesina toman los colores del juego; la pantalla, su dibujo. En todas se juega al mismo pong.",
  },
  previa: {
    intro: "Antes de cada robo, en cualquier modo, hasta tres páginas. Una sola norma para todos los modos: «La historia» si la pieza tiene una (en la historia, siempre; en el generativo, siempre, inventada; en los retos, si se escribió en el editor); «Lo nuevo» solo en los robos de la historia que enseñan algo (la lección, con su escena); y «El plan», siempre: el plano, la pieza y las reglas de esa noche.",
    reglas_titulo: "Las reglas del plan (logic/briefing.gd) se sacan de la noche misma, así que valen igual para la historia, un museo generado o un mapa guardado:",
    reglas: [
      "como mucho {MOST} líneas, apuntando a {AIM}: las que hay que decir van siempre, hasta {MOST}; las demás solo rellenan hasta {AIM};",
      "una línea corta cada una (como mucho {WORDS} palabras): qué pasa y qué hacer;",
      "lo normal no se dice: una vitrina sin alarma, unos guardias como los tiene el juego;",
      "los guardias, en una sola línea: cuántos, lo que destaca de ellos (dos rasgos como mucho) y qué hacer con el primero;",
      "una mecánica se cuenta dos veces en la historia: la noche que la enseña, en «Lo nuevo», y la noche siguiente, en el plan; después ya se sabe y no se dice. Fuera de la historia se dice siempre que el museo la tenga;",
      "el gran golpe de un museo dice qué lo hace especial en su propia línea, justo debajo de los guardias;",
      "en este orden: los guardias, el gran golpe, el trabajo y el museo.",
    ],
    consts: { FAST: "velocidad a partir de la que los guardias son «rápidos»", SLOW: "por debajo, «lentos»", SHARP_EARS: "oído a partir del que «oyen bien»", DULL_EARS: "por debajo, «medio sordos»", FAR_EYES: "vista a partir de la que «ven lejos»", SHORT_EYES: "por debajo, «cortos de vista»", GRUDGE: "segundos para calmarse a partir de los que son rencorosos", MOST: "líneas como mucho", AIM: "líneas a las que se apunta", WORDS: "palabras como mucho por línea" },
  },
};
