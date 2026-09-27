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
      { key: "MENU_STORY", text: "Cinco museos, cinco robos en cada uno (el quinto, su gran golpe), con cuento.", to: "historia" },
      { key: "MENU_GENERATIVE", text: "Un museo nuevo cada vez, con la dificultad y el tamaño que elijas.", to: "generativo" },
      { key: "MENU_CHALLENGE", text: "Mapas hechos a mano (los de serie y los tuyos) y el editor.", to: "retos" },
      { key: "MENU_SETTINGS", to: "ajustes" },
      { key: "MENU_QUIT", text: "Cierra el juego." },
    ],
    children: [
      {
        id: "historia", title: "MENU_STORY_TITLE", fn: "_show_story_menu", phase: "story_players",
        text: "Cuántos ladrones. Cada banda (de 1, 2, 3 o 4) guarda su propio progreso.",
        shots: ["menu_historia_jugadores"],
        options: [
          { key: "MENU_PLAYERS_1", text: "Directo a la ciudad.", to: "ciudad" },
          { key: "MENU_PLAYERS_2", text: "Primero cada uno elige su mando.", to: "mandos" },
          { key: "MENU_PLAYERS_3", to: "mandos" },
          { key: "MENU_PLAYERS_4", to: "mandos" },
          { key: "MENU_BACK", to: "titulo" },
        ],
        children: [
          {
            id: "mandos", title: "JOIN_TITLE", fn: "_show_join", phase: "join",
            text: "Con dos o más ladrones, en cualquier modo: cada uno pulsa un botón de su mando o una tecla de su mitad del teclado. P1 turquesa, P2 naranja, P3 violeta, P4 azul.",
            shots: ["menu_elegir_mandos"],
            options: [
              { key: "JOIN_PRESS", text: "En cada tarjeta, hasta que alguien la ocupa." },
              { key: "JOIN_UNDO", text: "Quita al último que se unió o vuelve atrás." },
              { key: "JOIN_READY", text: "Cuando están todos, sigue solo.", to: "ciudad" },
            ],
          },
          {
            id: "ciudad", title: "STORY_MAP_TITLE", fn: "_show_story_map", phase: "story_map",
            text: "La ciudad de noche vista desde arriba: los cinco museos en sus calles, cada uno en sus colores. Las calles se iluminan hasta el último museo abierto para esta banda.",
            shots: ["menu_historia_ciudad"],
            options: [
              { key: "MUSEUM_1_NAME", text: "La prehistoria. Robos 1 a 5.", to: "museo" },
              { key: "MUSEUM_2_NAME", text: "La naturaleza. Robos 6 a 10.", to: "museo" },
              { key: "MUSEUM_3_NAME", text: "El mundo antiguo. Robos 11 a 15.", to: "museo" },
              { key: "MUSEUM_4_NAME", text: "La Edad Media. Robos 16 a 20.", to: "museo" },
              { key: "MUSEUM_5_NAME", text: "La edad moderna. Robos 21 a 25, el final.", to: "museo" },
              { key: "MENU_BACK", to: "historia" },
            ],
            children: [
              {
                id: "museo", title: "«Un museo y sus salas»", fn: "_show_museum", phase: "museum",
                text: "Dentro de un museo, en sus colores: sus cinco robos como salas (se puede elegir cualquiera ya alcanzada), la quinta, la del gran golpe, más ancha, con alfombra roja, corona y puerta dorada; y la pieza de la elegida girando sobre terciopelo.",
                shots: ["menu_museo_1", "menu_museo_2", "menu_museo_3", "menu_museo_4", "menu_museo_5"],
                options: [
                  { label: "Las salas (1 a 5)", text: "Moverse por ellas cambia la pieza y su nombre." },
                  { key: "STORY_PLAY", text: "El robo 1 empieza con el prólogo; los demás, con la previa.", to: "previa" },
                  { key: "MENU_BACK", to: "ciudad" },
                ],
                children: [
                  {
                    id: "prologo", title: "PROLOGUE_TITLE", fn: "_show_prologue", phase: "prologue",
                    text: "Solo antes del robo 1: el cuento de la Banda del Calcetín en cuatro páginas.",
                    shots: ["previa_prologo_1", "previa_prologo_2", "previa_prologo_3", "previa_prologo_4"],
                    options: [
                      { key: "MENU_NEXT", text: "Página siguiente." },
                      { key: "PROLOGUE_GO", text: "En la última página.", to: "previa" },
                      { key: "MENU_SKIP", text: "Salta cuento y previa.", to: "cuenta" },
                      { key: "MENU_BACK", to: "museo" },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        id: "generativo", title: "MENU_GENERATIVE_TITLE", fn: "_show_generative_menu", phase: "menu",
        text: "Tres filas de tarjetas: dificultad, tamaño del museo y cuántos ladrones. Dificultad y tamaño se guardan en los ajustes.",
        shots: ["menu_generativo"],
        options: [
          { key: "MENU_DIFFICULTY_EASY", text: "Guardias lentos y medio dormidos." },
          { key: "MENU_DIFFICULTY_MEDIUM" },
          { key: "MENU_DIFFICULTY_HARD", text: "Guardias despiertos y rápidos." },
          { key: "MENU_SIZE_SMALL" },
          { key: "MENU_SIZE_MEDIUM" },
          { key: "MENU_SIZE_LARGE" },
          { key: "MENU_PLAY_1", to: "previa" },
          { key: "MENU_PLAY_2", text: "Con 2 a 4, antes se eligen los mandos.", to: "mandos" },
          { key: "MENU_PLAY_3", to: "mandos" },
          { key: "MENU_PLAY_4", to: "mandos" },
          { key: "MENU_BACK", to: "titulo" },
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
        text: "Desde el título o desde la pausa. Cada línea es un ajuste: Enter o clic lo cambia, ← y → lo bajan y suben. Cada cambio se guarda en user://settings.cfg.",
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
        text: "Hasta tres páginas antes de jugar, con la misma norma en todos los modos: «La historia» si la pieza tiene una, «Lo nuevo» solo en los robos de la historia que enseñan algo (la lección, con su escena) y «El plan» siempre: el plano, la pieza y las reglas de esa noche. Más en «Antes de un robo».",
        shots: ["previa_robo_01_story", "previa_robo_01_news", "previa_robo_01_plan", "previa_robo_02_news", "previa_robo_04_news", "previa_robo_05_story", "previa_robo_05_plan", "previa_robo_06_news", "previa_robo_08_news", "previa_robo_10_plan", "previa_robo_11_news", "previa_robo_13_news", "previa_robo_15_plan", "previa_robo_16_news", "previa_robo_20_plan", "previa_robo_21_news", "previa_robo_25_news", "previa_robo_25_plan", "previa_generativo_plan"],
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
            text: "Esc, P o Start. El mundo se para; la música y los menús, no.", shots: ["juego_pausa"],
            options: [
              { key: "MENU_RESUME", to: "juego" },
              { key: "MENU_SETTINGS", to: "ajustes" },
              { key: "MENU_TO_MENU", text: "Al menú del modo («VOLVER AL EDITOR» si se estaba probando un mapa)." },
            ],
          },
        ],
      },
      {
        id: "fin_pillado", title: "END_CAUGHT", fn: "_show_end", phase: "caught",
        text: "Si pillan a uno, se acaba la noche.", shots: ["final_pillado"],
        options: [{ key: "END_AGAIN", to: "previa" }, { key: "END_TO_MENU" }],
      },
      {
        id: "fin_escapado", title: "END_PERFECT", fn: "_show_end", phase: "escaped",
        text: "Toda la banda fuera con la pieza. En la historia abre la sala siguiente; tras un gran golpe, el siguiente museo (y vuelve a la ciudad).", shots: ["final_escapado"],
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
