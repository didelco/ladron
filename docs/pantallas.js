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
    id: "titulo", title: "«Pantalla de título»", fn: "_show_title", phase: "title",
    text: "La primera pantalla: el título y los tres modos de juego como tarjetas con su diorama.",
    shots: ["menu_titulo"],
    options: [
      { key: "MENU_STORY", text: "Veinte noches fijas en cinco museos, con cuento.", to: "historia" },
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
              { key: "MUSEUM_1_NAME", text: "Noches 1 a 4.", to: "museo" },
              { key: "MUSEUM_2_NAME", text: "Noches 5 a 8.", to: "museo" },
              { key: "MUSEUM_3_NAME", text: "Noches 9 a 12.", to: "museo" },
              { key: "MUSEUM_4_NAME", text: "Noches 13 a 16.", to: "museo" },
              { key: "MUSEUM_5_NAME", text: "Noches 17 a 20, la final.", to: "museo" },
              { key: "MENU_BACK", to: "historia" },
            ],
            children: [
              {
                id: "museo", title: "«Un museo y sus noches»", fn: "_show_museum", phase: "museum",
                text: "Dentro de un museo, en sus colores: sus cuatro noches como salas (se puede elegir cualquiera ya alcanzada) y la pieza de la elegida girando sobre terciopelo.",
                shots: ["menu_museo_1", "menu_museo_2", "menu_museo_3", "menu_museo_4", "menu_museo_5"],
                options: [
                  { label: "Las noches (1, 2, 3…)", text: "Moverse por ellas cambia la pieza y su nombre." },
                  { key: "STORY_PLAY", text: "La noche 1 empieza con el prólogo; las demás, con la previa.", to: "previa" },
                  { key: "MENU_BACK", to: "ciudad" },
                ],
                children: [
                  {
                    id: "prologo", title: "PROLOGUE_TITLE", fn: "_show_prologue", phase: "prologue",
                    text: "Solo antes de la noche 1: el cuento de la Banda del Calcetín en tres páginas.",
                    shots: ["previa_prologo_1", "previa_prologo_2", "previa_prologo_3"],
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
        text: "Una lista de nombres (las noches de la historia y los mapas hechos a mano) con el plano del elegido a la derecha.",
        shots: ["menu_retos"],
        options: [
          { key: "CHALLENGE_STORY_HEAD", text: "Las veinte noches; «*» si están retocadas a mano.", to: "reto_noche" },
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
            id: "reto_noche", title: "«Una noche de la historia»", fn: "_show_night_map", phase: "challenge",
            text: "El museo de una noche, para retocarlo: al guardarlo, la noche jugará ese plano con su pieza, sus guardias y su dificultad.",
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
        text: "Una o dos páginas antes de jugar. «Lo nuevo» sale solo en las noches de la historia que enseñan algo (la lección, con su escena); «El plan» siempre: el plano, la pieza, su historia y consejos para esa noche.",
        shots: ["previa_noche_01_news", "previa_noche_01_plan", "previa_noche_02_news", "previa_noche_04_news", "previa_noche_06_news", "previa_noche_08_news", "previa_noche_09_plan", "previa_noche_11_news", "previa_noche_13_news", "previa_noche_15_news", "previa_noche_17_news", "previa_noche_20_news", "previa_noche_20_plan", "previa_generativo_plan"],
        options: [
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
        shots: ["juego_noche_01", "juego_noche_04_linterna", "juego_noche_08_objetos", "juego_noche_13_dos", "juego_noche_15_luces", "juego_noche_20_final", "juego_generativo", "juego_reto"],
        options: [
          { key: "HUD_HELP", text: "La ayuda de teclas, siempre abajo a la izquierda." },
          { label: "Robar", text: "Quieto junto a la vitrina hasta que se abre (desde la noche 9, con minijuego)." },
          { label: "Salir por la flecha verde", text: "Con la pieza, toda la banda.", to: "fin_escapado" },
          { label: "Que te pillen", to: "fin_pillado" },
        ],
        children: [
          {
            id: "alerta", title: "«Los guardias»", text: "Cada guardia sospecha por niveles: ! algo raro (va a mirar), !! alerta (linterna roja), !!! va a por ti.",
            shots: ["juego_algo_raro", "juego_persecucion"], options: [],
          },
          {
            id: "minijuegos", title: "«Minijuegos»", text: "Una caja al lado del ladrón (nunca encima), sin palabras. Tiemblan más cuanto más alarmados están los guardias.",
            shots: ["juego_minijuego_lockpick", "juego_minijuego_wires", "juego_minijuego_steady", "juego_minijuego_balance"],
            options: [
              { key: "GAME_HOW_LOCKPICK", text: "La ganzúa, en la vitrina." },
              { key: "GAME_HOW_WIRES", text: "Los cables, en el cuadro de alarma." },
              { key: "GAME_HOW_STEADY", text: "La ventosa, en el cristal." },
              { key: "GAME_HOW_BALANCE", text: "El equilibrio, posando como estatua en un pedestal." },
              { key: "GAME_LET_GO" },
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
        text: "Toda la banda fuera con la pieza. En la historia desbloquea la noche siguiente.", shots: ["final_escapado"],
        options: [{ key: "END_NEXT_NIGHT", text: "En la historia.", to: "previa" }, { key: "END_NEXT_HEIST", text: "En el generativo.", to: "previa" }, { key: "END_TO_MENU" }],
      },
      {
        id: "final", title: "ENDING_TITLE", fn: "_show_ending", phase: "ending",
        text: "Tras la noche 20: el final del cuento.", shots: ["final_historia"],
        options: [{ key: "MENU_TO_MENU", to: "titulo" }],
      },
    ],
  },
];
