// El árbol de pantallas del juego: cómo se llega a cada una y qué opciones tiene.
// Escrito a mano (como ESTILO.md): cuando cambie un menú en scenes/main.gd, se cambia aquí.
//
// Cada pantalla:
//   id       su dirección en la documentación (#pantalla/<id>)
//   title    clave de locale/texts.csv (se enseña el texto actual) o texto entre «»
//   fn       la función que la pinta (docs.py pone su archivo:línea)
//   phase    el valor de `phase` en main.gd mientras está en pantalla
//   text     qué es, en una o dos frases
//   shots    ids de docs/capturas/
//   options  lo que se puede pulsar: {key | label, text, to}
//            key: clave del texto del botón · label: si no hay clave · to: pantalla a la que lleva
//   children las pantallas que cuelgan de esta
window.PANTALLAS = [
  {
    id: "portada", title: "«Portada»", fn: "_show_cover", phase: "cover",
    text: "Lo primero al abrir el juego: la portada (assets/ui/portada.png) a pantalla completa, recortada por los lados o por arriba sin cortar nunca el título, y «pulsa para empezar» parpadeando abajo (scenes/title_screen.gd).",
    shots: ["menu_portada"],
    options: [{ key: "TITLE_PRESS", text: "Cualquier tecla, botón o clic.", to: "titulo" }],
  },
  {
    id: "titulo", title: "«Pantalla de título»", fn: "_show_title", phase: "title",
    text: "La primera pantalla: el título y los tres modos de juego como tarjetas con su diorama.",
    shots: ["menu_titulo"],
    options: [
      { key: "MENU_STORY", text: "Cinco museos, cinco robos en cada uno (el quinto, su gran golpe), con cuento. Antes, cuántos ladrones, en un bocadillo.", to: "historia" },
      { key: "MENU_GENERATIVE", text: "Un museo nuevo cada vez, con la dificultad y el tamaño que elijas. Antes, cuántos ladrones, en un bocadillo.", to: "ladrones_generativo" },
      { key: "MENU_CHALLENGE", text: "Mapas hechos a mano (los de serie y los tuyos) y el editor.", to: "retos" },
      { key: "MENU_SETTINGS", to: "ajustes" },
      { key: "MENU_QUIT", text: "Cierra el juego." },
    ],
    children: [
      {
        id: "historia", title: "MENU_HOW_MANY", fn: "_pick_players", phase: "pick",
        text: "No es una pantalla: un bocadillo que sale de la tarjeta de la historia, sobre el título tal cual (sin apagarlo). De 1 a 4 ladrones: cada opción, una pegatina plana con tantas cabezas de ninja, cada una del color de su ladrón, y debajo solo «1P»…«4P»; la elegida a todo color y brillante, las demás apagadas, casi siluetas. El foco empieza en la banda de la última vez; cada banda guarda su propio progreso. Flechas, cruceta o stick (y A/D) para elegir, A, E o el punto (o 1–4) para seguir; B, Esc, Espacio, Enter o un clic fuera lo cierran, con el foco otra vez en la tarjeta.",
        shots: ["menu_titulo_ladrones"],
        options: [
          { label: "1P", text: "Directo a la ciudad.", to: "ciudad" },
          { label: "2P", text: "Primero cada uno elige su mando.", to: "mandos" },
          { label: "3P", to: "mandos" },
          { label: "4P", to: "mandos" },
          { label: "B, Esc, Espacio, Enter o clic fuera", text: "Cierra el bocadillo.", to: "titulo" },
        ],
        children: [
          {
            id: "mandos", title: "JOIN_TITLE", fn: "_show_join", phase: "join",
            text: "Con dos o más ladrones, en cualquier modo: cada uno pulsa un botón de su mando o una tecla de su mitad del teclado. P1 turquesa, P2 naranja, P3 violeta, P4 azul.",
            shots: ["menu_elegir_mandos"],
            options: [
              { key: "JOIN_PRESS", text: "En cada tarjeta, hasta que alguien la ocupa." },
              { key: "JOIN_UNDO", text: "Esc quita al último que se unió; B (Espacio o Enter en cada mitad del teclado) quita al suyo; sin nadie, vuelve atrás." },
              { key: "JOIN_READY", text: "Cuando están todos, sigue solo (en la historia, a la ciudad).", to: "ciudad" },
            ],
          },
          {
            id: "ciudad", title: "STORY_MAP_TITLE", fn: "_show_city", phase: "tour",
            text: "Toda la previa de la historia es una sola escena en 3D (Tour, CityStage), como el plan de un robo en una película. Empieza en la ciudad de noche, en axonometría y mucho más grande que la pantalla (TownBuilder, con los kits de ciudad de Kenney, CC0). Un río la cruza en diagonal haciendo meandros y la parte en cuatro barrios, dos a cada orilla, cada uno con su trama de calles girada a su manera: cruces y pasos de cebra, manzanas de tiendas, casas con jardín, parques, farolas, rascacielos al fondo de la parte alta. Entre los barrios y a lo largo del agua, bosque con casas y chalets sueltos, cada uno a su aire (alguno con la piscina encendida). La orilla de arriba está más alta, subiendo por un talud con árboles, y al norte se alza una loma de rocas grandes que los barrios rodean; solo dos puentes en rampa la unen con la de abajo, y unas carreteras enlazan los barrios de cada orilla. Por la orilla de abajo corre un paseo con farolas y bancos, y junto al agua hay una zona deportiva (fútbol, baloncesto y tenis) con sus focos. De noche la luz es barata: cada farola, casa encendida, piscina y foco deja un charco de luz en el suelo, un quad que se suma a lo que hay debajo, todos en un solo MultiMesh; las ventanas y las farolas brillan por su cuenta. Entre ellos, los cinco museos (MuseumBuilding): edificios de museo con escalinata, columnas, frontón y cúpula, cada uno en su color, con sus estandartes y su nombre en el friso, unidos por la ruta encendida desde el escondite de la banda. No caben todos: la cámara mira al museo elegido, con alguno más a la vista, y al pasar a otro se desliza por la ciudad hasta él (CityStage.FOLLOW_S). Van en zigzag a un lado y otro del río: el primero junto al agua, puente arriba los dos siguientes en la parte alta, el cuarto al otro lado, y por el segundo puente el último, otra vez junto al agua. La ruta encendida va por las calles y los puentes. Los cerrados, apagados y con candado. Sobre el elegido, su nombre, las salas robadas y sus estrellas. La primera vez, antes, el prólogo.",
            shots: ["menu_historia_ciudad"],
            options: [
              { label: "Flechas, WASD, stick o cruceta", text: "Cambian de museo; a uno cerrado no se llega." },
              { key: "TOUR_HINT_ENTER", text: "A, E o el punto: zoom de cámara hasta la fachada del museo; la ciudad alrededor se oscurece un poco.", to: "museo" },
              { key: "TOUR_HINT_BACK", text: "B, Esc, Espacio o Enter.", to: "historia" },
            ],
            children: [
              {
                id: "museo", title: "«Un museo y sus salas»", fn: "_show_museum_tour", phase: "tour",
                text: "El edificio del museo de cerca: cada sala es una ventana de su fachada (1 y 2 a la izquierda, 3 y 4 a la derecha; el gran golpe, la ventana alta del centro, con la corona en la cúpula), encendida y con su pieza a contraluz; las cerradas, a oscuras y con candado. Bajo cada ventana, su número y sus estrellas. La elegida brilla más, con el marco dorado y un aro de luz. Se abre en la siguiente sala sin hacer; tras un robo se vuelve aquí con la siguiente elegida.",
                shots: ["menu_museo_1", "menu_museo_2", "menu_museo_3", "menu_museo_4", "menu_museo_5"],
                options: [
                  { label: "Flechas", text: "De ventana en ventana, como se ven; saltan las cerradas." },
                  { key: "TOUR_HINT_PLAN", text: "De la ventana sale su plano, vuela hacia la cámara y se despliega; a la vez, la historia de la pieza en grande.", to: "plano" },
                  { key: "TOUR_HINT_TOWN", text: "Vuelve a la ciudad.", to: "ciudad" },
                ],
                children: [
                  {
                    id: "plano", title: "«El plano de la sala»", fn: "_tour_room", phase: "tour",
                    text: "Una sola tecla, SIGUIENTE, lleva por todo (PlanTalk, PlanBeats); nada pasa solo. Primero, la historia de la pieza en grande, casi a pantalla completa: la hoja del encargo con la pieza girando en su polaroid, mientras el plano sale de la ventana y se despliega detrás (un relato largo, en dos páginas). Luego lo nuevo, grande, con su maqueta animada, junto a lo que lo lleva en el plano. Luego el plano para explorar, que sigue enseñando sus pliegues (valles oscuros, crestas con brillo, cada panel con su luz): a la izquierda, con chinchetas para la vitrina, lo nuevo, cada guardia, la alarma, la entrada y la salida; a la derecha, la lista de la noche: la pieza y lo que cuesta sacarla, las reglas y las estrellas (las ganadas, marcadas). Elegir algo resalta sus reglas; A abre su ficha (la vitrina, la historia otra vez). Un robo ya hecho o ya contado va directo a explorar.",
                    shots: ["previa_robo_01_pieza", "previa_robo_01_nuevo", "previa_robo_01_plano", "previa_robo_06_nuevo", "previa_robo_08_plano", "previa_robo_11_nuevo", "previa_robo_25_plano"],
                    options: [
                      { key: "MENU_NEXT", text: "A, E o el punto: SIGUIENTE, de la historia a lo nuevo y al plano." },
                      { key: "TOUR_HINT_PREV", text: "B: un paso atrás (de la historia, al museo)." },
                      { key: "TOUR_HINT_SKIP", text: "Start o Tab: a explorar; explorando, a robar." },
                      { key: "TOUR_START", text: "El plano se funde con la partida y empieza la cuenta atrás.", to: "cuenta" },
                      { key: "TOUR_HINT_MUSEUM", text: "B: el plano se pliega y vuelve a su sala.", to: "museo" },
                    ],
                  },
                  {
                    id: "prologo", title: "PROLOGUE_TITLE", fn: "_show_prologue", phase: "prologue",
                    text: "Solo la primera vez, antes de la ciudad: el cuento de la Banda del Calcetín en cuatro páginas.",
                    shots: ["previa_prologo_1", "previa_prologo_2", "previa_prologo_3", "previa_prologo_4"],
                    options: [
                      { key: "MENU_NEXT", text: "Página siguiente; en la última, a la ciudad.", to: "ciudad" },
                      { key: "MENU_SKIP", text: "A la ciudad.", to: "ciudad" },
                      { key: "MENU_BACK", to: "historia" },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        id: "ladrones_generativo", title: "MENU_HOW_MANY", fn: "_pick_players", phase: "pick",
        text: "El mismo bocadillo que en la historia, desde la tarjeta del generativo: de 1 a 4 ladrones, y a su menú.",
        shots: ["menu_titulo_ladrones"],
        options: [
          { label: "1P", to: "generativo" },
          { label: "2P", to: "generativo" },
          { label: "3P", to: "generativo" },
          { label: "4P", to: "generativo" },
          { label: "B, Esc, Espacio, Enter o clic fuera", text: "Cierra el bocadillo.", to: "titulo" },
        ],
      },
      {
        id: "generativo", title: "MENU_GENERATIVE_TITLE", fn: "_show_generative_menu", phase: "generative",
        text: "Dos tarjetas grandes como las del título, con el mismo borde que todos los menús (solo se enciende la del foco): la dificultad y el tamaño del museo, cada una con el diorama y el nombre de la que hay (se guardan en los ajustes). Debajo, EMPEZAR, con el foco al llegar, y VOLVER. Los ladrones son los elegidos en el bocadillo del título.",
        shots: ["menu_generativo", "menu_generativo_dificultad"],
        options: [
          { key: "MENU_DIFFICULTY", text: "Saca debajo un bocadillo con las tres dificultades.", to: "generativo_ajuste" },
          { key: "MENU_SIZE", text: "Saca debajo un bocadillo con los tres tamaños.", to: "generativo_ajuste" },
          { key: "MENU_START", text: "Con 1, a la previa; con 2 a 4, antes se eligen los mandos.", to: "previa" },
          { key: "MENU_BACK", text: "Al bocadillo de cuántos ladrones, para cambiarlo.", to: "ladrones_generativo" },
        ],
        children: [
          {
            id: "generativo_ajuste", title: "«Dificultad o tamaño»", fn: "_pick_setting", phase: "pick",
            text: "No es una pantalla: un bocadillo que sale de la tarjeta pulsada, como el de cuántos ladrones del título. Sus tres opciones, cada una en su diorama quieto (el mismo de la tarjeta, sin animar); la que hay, a todo color y con el foco al abrirse, las demás apagadas. Flechas, cruceta o stick (y A/D) para moverse, A, E o el punto (o 1–3) para elegir: se guarda, se cierra y la tarjeta ya la enseña, con el foco. B, Esc, Espacio, Enter o un clic fuera lo cierran sin cambiar nada.",
            shots: ["menu_generativo_dificultad"],
            options: [
              { key: "MENU_DIFFICULTY_EASY", text: "Guardias lentos y medio dormidos." },
              { key: "MENU_DIFFICULTY_MEDIUM" },
              { key: "MENU_DIFFICULTY_HARD", text: "Guardias despiertos y rápidos." },
              { key: "MENU_SIZE_SMALL" },
              { key: "MENU_SIZE_MEDIUM" },
              { key: "MENU_SIZE_LARGE" },
              { label: "B, Esc, Espacio, Enter o clic fuera", text: "Cierra el bocadillo.", to: "generativo" },
            ],
          },
        ],
      },
      {
        id: "retos", title: "CHALLENGE_TITLE", fn: "_show_challenge_menu", phase: "menu",
        text: "Una lista de nombres (los robos de la historia y los mapas hechos a mano) con el plano del elegido a la derecha.",
        shots: ["menu_retos"],
        options: [
          { key: "CHALLENGE_STORY_HEAD", text: "Los veinticinco robos; «*» si están retocados a mano.", to: "reto_noche" },
          { key: "CHALLENGE_MAPS_HEAD", text: "Los mapas de serie (maps/) y los tuyos (user://maps).", to: "reto" },
          { key: "CHALLENGE_NEW", to: "editor" },
          { key: "MENU_BACK", to: "titulo" },
        ],
        children: [
          {
            id: "reto", title: "«Un reto elegido»", fn: "_show_challenge_map", phase: "challenge",
            text: "Un mapa hecho a mano: su plano, sus datos (tamaño, dificultad, guardias) y jugarlo con 1 a 4 ladrones.",
            shots: ["menu_reto_mapa"],
            options: [
              { key: "MENU_PLAY_1", to: "previa" },
              { key: "MENU_PLAY_2", to: "mandos" },
              { key: "MENU_PLAY_3", to: "mandos" },
              { key: "MENU_PLAY_4", to: "mandos" },
              { key: "CHALLENGE_EDIT", to: "editor" },
              { key: "CHALLENGE_DELETE", text: "Pide confirmación antes de borrar. Solo en los tuyos." },
              { key: "MENU_BACK", to: "retos" },
            ],
          },
          {
            id: "reto_noche", title: "«Un robo de la historia»", fn: "_show_night_map", phase: "challenge",
            text: "El museo de un robo, para retocarlo: al guardarlo, el robo jugará ese plano con su pieza, sus guardias y su dificultad.",
            shots: ["menu_reto_noche"],
            options: [
              { key: "CHALLENGE_EDIT", to: "editor" },
              { key: "CHALLENGE_RESTORE", text: "Solo si está retocada: la devuelve a como la genera el juego." },
              { key: "MENU_BACK", to: "retos" },
            ],
          },
          {
            id: "editor", title: "«Editor de mapas»", fn: "_show_editor", phase: "editor",
            text: "Pintar muros y suelo, poner vitrinas, piezas grandes, la entrada, la pieza, la salida, guardias y objetos; vista 2D y 3D. Solo deja jugar mapas cerrados con pieza y salida alcanzables.",
            shots: ["menu_editor"],
            options: [
              { key: "EDITOR_TAB_EDIT", text: "Las herramientas de pintar y poner." },
              { key: "EDITOR_TAB_OPTIONS", text: "Tamaño, dificultad, guardias, suelo y paredes." },
              { key: "EDITOR_PLAY", text: "Lo juega tal cual; al acabar, vuelve al editor.", to: "juego" },
              { key: "EDITOR_SAVE", text: "Con pestañas para el mapa, la pieza y su historia." },
              { key: "EDITOR_SAVE_AND_EXIT", to: "retos" },
            ],
          },
        ],
      },
      {
        id: "ajustes", title: "SETTINGS_TITLE", fn: "_show_settings", phase: "settings",
        text: "Desde el título o desde la pausa. Cada línea es un ajuste: A, E, el punto o clic lo cambia, ← y → lo bajan y suben. Cada cambio se guarda en user://settings.cfg.",
        shots: ["ajustes_inicio"],
        options: [
          { key: "SETTINGS_IA", text: "Enseña lo que piensa cada guardia (Laya o las reglas de reserva)." },
          { key: "SETTINGS_SOUND_PAGE", to: "ajustes_sonido" },
          { key: "SETTINGS_SCREEN_PAGE", to: "ajustes_pantalla" },
          { key: "SETTINGS_PADS_PAGE", to: "ajustes_controles" },
          { key: "SETTINGS_ASSETS_PAGE", to: "assets_juego" },
          { key: "MENU_BACK", text: "Al título o a la pausa, según de dónde se vino." },
        ],
        children: [
          {
            id: "ajustes_sonido", title: "SETTINGS_SOUND_TITLE", fn: "_show_settings", phase: "settings",
            text: "Sonido y música, y sus volúmenes.", shots: ["ajustes_sound"],
            options: [
              { key: "SETTINGS_SOUND", text: "Todo el sonido; N lo silencia en cualquier momento." },
              { key: "SETTINGS_MUSIC" },
              { key: "SETTINGS_MUSIC_VOLUME", text: "En pasos de 10 %." },
              { key: "SETTINGS_EFFECTS_VOLUME", text: "En pasos de 10 %." },
              { key: "MENU_BACK", to: "ajustes" },
            ],
          },
          {
            id: "ajustes_pantalla", title: "SETTINGS_SCREEN_TITLE", fn: "_show_settings", phase: "settings",
            text: "La ventana y el tamaño de la interfaz.", shots: ["ajustes_screen"],
            options: [
              { key: "SETTINGS_FULLSCREEN" },
              { key: "SETTINGS_WINDOW", text: "Tamaños 16:9 que quepan en la pantalla, o AUTO (el mayor)." },
              { key: "SETTINGS_UI_SCALE", text: "De 70 % a 150 %, menús y HUD." },
              { key: "SETTINGS_VSYNC" },
              { key: "MENU_BACK", to: "ajustes" },
            ],
          },
          {
            id: "ajustes_controles", title: "SETTINGS_PADS_TITLE", fn: "_show_settings", phase: "settings",
            text: "Los mandos conectados, la vibración, la zona muerta y la tabla de controles (teclado izquierdo, derecho y mando).",
            shots: ["ajustes_pads"],
            options: [
              { key: "SETTINGS_RUMBLE" },
              { key: "SETTINGS_RUMBLE_STRENGTH" },
              { key: "SETTINGS_DEADZONE", text: "Entre 20 % y 80 % del recorrido del stick." },
              { key: "MENU_BACK", to: "ajustes" },
            ],
          },
          {
            id: "assets_juego", title: "ASSETS_TITLE", fn: "_show_assets", phase: "assets",
            text: "Todo lo que forma el juego, para mirarlo dentro de él. Esta documentación tiene la misma página fuera del juego: ver Assets.",
            shots: ["assets_piezas", "assets_people", "assets_props", "assets_sounds", "assets_map"],
            options: [
              { key: "ASSETS_TAB_LOOT", text: "Cada pieza a robar en su peana.", doc: "piezas" },
              { key: "ASSETS_TAB_PEOPLE", text: "Ladrones y guardias en sus dioramas.", doc: "personajes" },
              { key: "ASSETS_TAB_PROPS", text: "Los objetos que se caen.", doc: "objetos/sin" },
              { key: "ASSETS_TAB_SOUNDS", text: "Cada sonido, con un botón para oírlo.", doc: "sonidos" },
              { key: "ASSETS_TAB_MAP", text: "La leyenda del mapa y las marcas de los guardias." },
              { key: "MENU_PREVIOUS" }, { key: "MENU_NEXT" },
              { key: "MENU_BACK", to: "ajustes" },
            ],
          },
        ],
      },
    ],
  },
  {
    id: "noche", title: "«Una noche»", text: "Lo que pasa desde que se elige una noche hasta que acaba, en cualquier modo.",
    options: [], shots: [],
    children: [
      {
        id: "previa", title: "«La previa»", fn: "_show_brief", phase: "brief",
        text: "En generativo y retos: la historia de la pieza si la tiene y «El plan» (el plano, la pieza y las reglas). En la historia, la previa es el plano que sale de la sala («El plano de la sala»).",
        shots: ["previa_generativo_plan"],
        options: [
          { key: "BRIEF_TAB_STORY", text: "La pieza en grande a la izquierda; la ficha y el cuento a la derecha.", doc: "previa" },
          { key: "BRIEF_TAB_NEWS", text: "La lección de la noche." },
          { key: "BRIEF_TAB_PLAN", text: "El plano y la pieza." },
          { key: "BRIEF_START", to: "cuenta" },
          { key: "MENU_SKIP", to: "cuenta" },
          { key: "MENU_BACK", text: "Al museo, al prólogo o al menú del modo." },
        ],
      },
      {
        id: "cuenta", title: "«Cuenta atrás»", fn: "_start_countdown", phase: "countdown",
        text: "3, 2, 1, ¡GO! con un pitido cada número; luego se juega.", shots: ["previa_cuenta_atras"],
        options: [], to: "juego",
      },
      {
        id: "juego", title: "«En juego»", fn: "_start_playing", phase: "playing",
        text: "El museo desde arriba. Abajo, un retrato por ladrón; arriba al centro, la alarma (! !! !!!); a la izquierda, lo que piensa cada guardia y la ayuda de teclas. No hay reloj: la noche dura lo que haga falta.",
        shots: ["juego_robo_01", "juego_robo_04_linterna", "juego_robo_08_objetos", "juego_robo_13_dos", "juego_robo_16_luces", "juego_robo_25_final", "juego_generativo", "juego_reto"],
        options: [
          { key: "HUD_HELP", text: "La ayuda de teclas, siempre abajo a la izquierda." },
          { label: "Robar", text: "Quieto junto a la vitrina hasta que se abre (desde el robo 6, el segundo museo, con minijuego)." },
          { label: "Salir por la flecha verde", text: "Con la pieza, toda la banda.", to: "fin_escapado" },
          { label: "Que te pillen", to: "fin_pillado" },
        ],
        children: [
          {
            id: "alerta", title: "«Los guardias»", text: "Cada guardia sospecha por niveles: ! algo raro (va a mirar), !! alerta (linterna roja), !!! va a por ti.",
            shots: ["juego_algo_raro", "juego_persecucion"], options: [],
          },
          {
            id: "minijuegos", title: "«Minijuegos»", text: "Una caja al lado del ladrón (nunca encima), sin palabras. Tiemblan más cuanto más alarmados están los guardias. Cada uno es un fichero de lógica (logic/minigames/) y otro de vista (scenes/minigame_views/).",
            shots: ["juego_minijuego_lockpick", "juego_minijuego_wires", "juego_minijuego_steady", "juego_minijuego_balance", "juego_minijuego_squeeze", "juego_minijuego_sneeze", "juego_minijuego_arcade"],
            options: [
              { key: "GAME_HOW_LOCKPICK", text: "La ganzúa, en la vitrina.", doc: "minijuegos/lockpick" },
              { key: "GAME_HOW_WIRES", text: "Los cables, en el cuadro de alarma.", doc: "minijuegos/wires" },
              { key: "GAME_HOW_STEADY", text: "La ventosa, en el cristal.", doc: "minijuegos/steady" },
              { key: "GAME_HOW_BALANCE", text: "El equilibrio, posando como estatua en un pedestal.", doc: "minijuegos/balance" },
              { key: "GAME_HOW_SQUEEZE", text: "Colarse en un escondite: a un lado y a otro, con ritmo; de 2 a 5 s a la vista.", doc: "escondites" },
              { key: "GAME_HOW_SNEEZE", text: "El estornudo, al rato de estar escondido; si se escapa, ¡ACHÍS! y fuera.", doc: "minijuegos/sneeze" },
              { key: "GAME_HOW_ARCADE", text: "Un pong de broma en la recreativa: no se gana nada y nunca acaba.", doc: "minijuegos/arcade" },
              { key: "GAME_LET_GO" },
              { key: "GAME_LET_GO_SNEEZE", text: "El estornudo no se suelta: se sale del escondite." },
              { key: "GAME_LET_GO_ARCADE", text: "La recreativa se suelta con la tecla de siempre." },
            ],
          },
          {
            id: "mapa", title: "«El mapa»", fn: "_toggle_map", phase: "playing",
            text: "Un pergamino plegado que se despliega (M o Y): la banda, la pieza, la salida, los guardias y lo que se puede tirar.",
            shots: ["juego_mapa"], options: [{ key: "HUD_MAP_HIDE" }],
          },
          {
            id: "pausa", title: "MENU_PAUSE", fn: "_pause", phase: "paused",
            text: "Esc, P o Start. El mundo se para; la música y los menús, no. Detrás del menú, la partida congelada en el monitor de vigilancia del museo: verde de fósforo, pixelada y oscura (se sabe dónde estás, pero no sirve para espiar a los guardias), con la cámara y la sala arriba, «REC» y la hora que sigue corriendo, y el museo abajo. Los ajustes abiertos desde aquí lo mantienen.", shots: ["juego_pausa"],
            options: [
              { key: "MENU_RESUME", to: "juego" },
              { key: "MENU_SETTINGS", to: "ajustes" },
              { key: "MENU_TO_MENU", text: "Al menú del modo («VOLVER AL EDITOR» si se estaba probando un mapa)." },
            ],
          },
        ],
      },
      {
        id: "fin_pillado", title: "END_FILE_STAMP_ONE", fn: "_show_end", phase: "caught",
        text: "Si pillan a uno, se acaba la noche. La ficha policial: un folio blanco que se sale por abajo, con las dos fotos de siempre (la cabeza del ninja de frente y de perfil, en blanco y negro, ante la regla de alturas), el número, el delito, quién te pilló y el sello rojo. Los botones, a su lado.", shots: ["final_pillado"],
        options: [{ key: "END_AGAIN", to: "previa" }, { key: "END_TO_MENU" }],
      },
      {
        id: "fin_escapado", title: "END_PAPER_NAME", fn: "_show_end", phase: "escaped",
        text: "Toda la banda fuera con la pieza. La portada del periódico del pueblo: el titular, la foto de la pieza en trama y el golpe en cifras (el tiempo, las veces que os vieron y lo que más hicisteis: bombas, escondites, cosas tiradas…, HeistStats). En la historia, bajo el titular, las tres estrellas del intento (botín, sigilo y rapidez, Story.STARS), llenas o vacías y las nuevas estampadas en rojo; y abre la sala siguiente; tras un gran golpe, el titular es el museo desvalijado y se pasa al siguiente museo (y vuelve a la ciudad).", shots: ["final_escapado"],
        options: [{ key: "END_NEXT_NIGHT", text: "En la historia.", to: "previa" }, { key: "END_NEXT_MUSEUM", text: "Tras el gran golpe de un museo.", to: "ciudad" }, { key: "END_NEXT_HEIST", text: "En el generativo.", to: "previa" }, { key: "END_TO_MENU" }],
      },
      {
        id: "final", title: "ENDING_TITLE", fn: "_show_ending", phase: "ending",
        text: "Tras el robo 25: el final del cuento.", shots: ["final_historia"],
        options: [{ key: "MENU_TO_MENU", to: "titulo" }],
      },
    ],
  },
];
