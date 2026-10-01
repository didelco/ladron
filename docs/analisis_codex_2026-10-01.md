# Análisis Codex — navegación, mensajes y experiencia de usuario

**Fecha:** 1 de octubre de 2026 · **Estado:** auditoría de escritorio completada.  
**Versión observada:** Ninja Karma v0.1.351, Godot 4.7.2, macOS.  
**Método:** recorrido manual con ratón y teclado por Historia, Generativo, Retos, Ajustes y editor; partida de un jugador y progreso previo; contraste de los fallos reproducibles con el código. No había mando conectado. No se modificó el código del juego.

## Diagnóstico

La portada distingue bien Historia, Generativo y Retos; las tarjetas tienen imágenes reconocibles y el foco seleccionado destaca. La navegación hacia la primera misión de Historia conserva una jerarquía comprensible: jugadores → ciudad → museo → plano → ficha → robo. La ciudad señala «SIGUIENTE» y Retos ofrece una vista previa del plano al recorrer la lista. La pausa presenta opciones claras para seguir y ajustar el juego.

Los problemas más urgentes son un error continuo al seleccionar un robo con guardia en Retos, mensajes que asignan a `Espacio` una acción opuesta a la real, y la salida inmediata de una noche desde la pausa sin aviso de pérdida. La leyenda del mapa también queda tapada por el retrato del jugador.

## Incidencias reproducibles

| ID | Prioridad | Dónde y cómo reproducir | Resultado observado | Corrección y criterio de aceptación |
| --- | --- | --- | --- | --- |
| N1 | **Crítica** | Portada → Retos → seleccionar **Robo 2 · La bola de chicle del récord** con flecha abajo. También se reproduce iniciando `-- --menu=challenges` y pulsando abajo. | El registro repite `Out of bounds get index '0' (on base: 'Array[Figure]')` en [`Scenery.draw_figures()`](../scenes/scenery.gd) cada fotograma; en la sesión de reproducción se acumularon más de 1.500 errores. | Evitar que la vista previa deje `host.guards` desincronizado con `guard_nodes`, o no dibujar actores de una misión que no está en curso. Seleccionar y recorrer todos los robos de Retos debe dejar el registro sin errores y mantener la interfaz fluida. Posible origen: [`ChallengeScreens.night_as_map()`](../scenes/challenge_screens.gd) construye el mapa alterando estado de la partida y solo restaura parte de él. |
| N2 | **Alta** | Historia → ciudad → museo → plano. En museo, leer «ESPACIO A LA CIUDAD» y pulsar `Espacio`; en plano, leer «ESPACIO AL MUSEO» y pulsar `Espacio`. | En museo se entra en el plano; en plano se abre la ficha seleccionada. `Esc` sí retrocede. | Elegir una convención y aplicarla a control, rótulo y ayuda en ciudad, museo y plano. [`MenuKeys`](../logic/menu_keys.gd) traduce `Espacio` a `accept`; [`Tour`](../scenes/tour.gd) lo presenta como vuelta. Probar cada indicación con teclado y mando. |
| N3 | **Alta** | Entrar en un robo → `P` → **«MENÚ»**. | Se abandona la noche y aparece la portada directamente. La advertencia «La noche en curso no se guarda» solo existe al elegir **«SALIR DEL JUEGO»**. | Mostrar la misma advertencia antes de abandonar la noche desde «Menú», o explicar explícitamente la pérdida en el propio botón. La opción de cancelar debe conservar la partida pausada. Véase [`_pause()` y `_quit_to_title()`](../scenes/main.gd). |
| N4 | **Alta** | Durante un robo de un jugador, abrir el mapa con `M`. | El retrato inferior se superpone a la leyenda: oculta parte de «la pieza», «la salida» y la ayuda para guardar el mapa. | Reubicar leyenda/retrato o reservar espacio para ambos; comprobar resoluciones y tamaños de interfaz disponibles. Ninguna etiqueta ni icono debe quedar tapado. |
| N5 | **Media** | Portada → Ajustes → Controles. | La tabla enumera moverse, acción, rodar, agacharse, andar lento, mapa, pausa y silenciar, pero omite la bomba de humo. La ayuda definida en [`texts.csv`](../locale/texts.csv) sí dice `F humo`; el manejo de teclado está en [`hands.gd`](../scenes/hands.gd). | Añadir la fila de humo con controles reales de J1, J2 y mando, y verificar que la tabla refleje las acciones disponibles en la partida. |
| N6 | **Media** | Portada → Retos, recorrer la columna izquierda. | Los nombres largos acaban en puntos suspensivos; el nombre completo aparece a la derecha al seleccionar. Algunos robos aparecen verdes, pero no hay leyenda visible del color. | Mantener el nombre completo en el panel de detalle; añadir una leyenda o distintivo «retocado» junto al asterisco y comprobar que se entiende sin depender del color. El código pinta de verde los robos editados. |
| N7 | **Media** | Portada → Generativo → abrir Dificultad, Tamaño, Tema y Ladrones. | La selección muestra valores, pero apenas explica qué cambia en el robo. El selector inferior ocupa mucho espacio y las opciones no seleccionadas quedan muy oscuras; esto es especialmente visible en Tamaño y Ladrones (2P–4P). | Añadir una frase sobre el efecto de cada parámetro; separar visualmente el selector de «Empezar» y elevar el contraste de las opciones disponibles no seleccionadas. Probarlo también en una ventana pequeña. |
| N8 | **Media** | Portada → Ajustes → Pantalla u Opciones. | Filas como «Escala 3D», «V-Sync», «Megafonía» y «Panel IA» presentan valores, pero no explican su efecto ni que un clic cambia el valor inmediatamente. Solo Sonido muestra ayuda para las flechas. | Añadir ayuda contextual breve y una indicación uniforme de ajuste (`←/→`, clic). Para opciones gráficas, permitir entender el coste visual/rendimiento antes de cambiarlas. |

## Hallazgos de contenido que requieren contraste en juego

- **Unión de jugadores:** «Pulsa mando o teclado para unirte» y «Esc: quitar al último · tu tecla: salir» no dicen cuál es «tu tecla». Probar el flujo real con dos teclados y mandos y sustituirlo por instrucciones específicas para cada jugador. Textos en [`texts.csv`](../locale/texts.csv).
- **Vitrina con alarma:** la lección pide soltar la vitrina y esconderse si llega alguien; el consejo del plano dice correr hacia la salida después de abrirla. Pueden corresponder a momentos distintos, pero conviene hacerlo explícito: «Mientras la abres… / Una vez tengas la pieza…».
- **Escondite:** «No se abre: es para practicar» carece de sujeto en el texto aislado. Comprobarlo en su ubicación y nombrar la vitrina o pieza si no queda evidente visualmente.
- **Ayuda inicial de juego:** existe la cadena `HUD_HELP` con los controles principales, pero no encontré ninguna referencia que la muestre en las escenas; en la partida observada no apareció. Valorar un recordatorio breve al primer robo o una ayuda consultable en la pausa, sobre todo para humo y mapa.

## Observaciones de navegación

- **Historia:** `Esc` retrocede por ficha, plano, museo, ciudad y selección de jugadores. La secuencia funciona, aunque exige varias transiciones antes del primer robo. Conviene medir con jugadores nuevos si localizan «¡A robar!» sin ayuda.
- **Retos:** la primera sección es Historia y permite editar sus robos; los mapas hechos a mano quedan después en una lista larga. El título general «Retos» puede hacer esperar una lista de desafíos listos para jugar. Separar visualmente «Editar robos de Historia» de «Jugar mapas» y facilitar salto entre secciones.
- **Pausa:** muestra «Seguir», «Ajustes», «Menú» y «Salir del juego». El destino de «Menú» es la portada; el de «Salir del juego» es cerrar la aplicación. Los nombres son cortos, pero la diferencia en pérdida de la noche necesita la advertencia de N3.
- **Generativo:** las cuatro tarjetas dejan visible el valor elegido y «Empezar» está al pie. Abrir una tarjeta despliega las opciones debajo de ella; el contenido de Tamaño y Ladrones se entiende por sus imágenes, aunque no explica las consecuencias de elegir más espacio o jugadores (N7).
- **Editor:** en el mapa inicial se distinguen las herramientas de colocación con rótulos, y el cambio entre plano y vista 3D da una comprobación visual útil. El diálogo de guardado separa Mapa, Pieza e Historia; la pestaña Pieza explica la opción aleatoria. Las acciones de la barra superior e inferior usan solo iconos: tienen ayuda al pasar el ratón, pero convendría añadir rótulos visibles o una breve leyenda para la primera visita. En 3D, la larga línea de instrucciones se superpone a la escena; comprobar legibilidad a tamaños menores.
- **Ratón:** un clic sobre una sala del museo no produjo una respuesta inmediata evidente en una prueba; el teclado sí cambió de sala. No se considera fallo confirmado: repetirlo desde una partida limpia y fuera de la animación de cámara.

## Orden recomendado de trabajo

1. Corregir N1 y añadir una comprobación de regresión al recorrer robos con distintos números de guardias.
2. Resolver N2 y N3; después verificar todas las pistas de teclado, mando y rutas de salida.
3. Corregir N4 y N5: el mapa y la tabla de controles son ayudas que el jugador consulta para decidir qué hacer.
4. Mejorar la claridad de Retos, Generativo y Ajustes (N6–N8), y revisar los textos pendientes con una prueba de primera partida.

**Límites de la auditoría:** no se probó un mando ni una sesión multijugador; no se alteraron ajustes gráficos ni se guardaron mapas. En el editor se revisaron la navegación, la vista 3D y el diálogo de guardado, no la edición y persistencia de un mapa. Los puntos marcados «requieren contraste» son hipótesis editoriales, no errores funcionales demostrados.
