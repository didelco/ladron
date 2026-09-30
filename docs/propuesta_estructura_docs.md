# Propuesta: estructura y navegación de la documentación

Estado: **implementada** en `docs/index.html` + `docs/navegacion.js` + `docs/navegacion.css`. Este documento recoge la auditoría, el árbol nuevo y el porqué.

## 1. Auditoría del visor anterior

Recorrido con Chrome headless (puppeteer-core) a 1400 px y a 390 px, las 19 páginas y las 10 pantallas con página propia.

| Hallazgo | Detalle |
|---|---|
| Clics para llegar | Páginas de primer nivel: 1 clic. Pantallas hijas: 2 a 3 (árbol plegado, con un contador). Un objeto, una frase de megafonía, un sonido o una colección de procedencia: **no había camino directo**; había que abrir la página y filtrar o desplazarse. |
| Sin buscador global | Solo había filtros locales (Textos, Procedencia, Referencias). Buscar «calcetín» o «CC0» obligaba a saber en qué página mirar. |
| Sin migas de pan | Solo las pantallas tenían una ruta pequeña; el resto de páginas no decían en qué grupo estaban. |
| Páginas enormes sin índice | Textos 33 800 px, Paleta 19 100, Megafonía 18 200, Propuesta 13 700, Versiones 8 800, Procedencia 8 700. Ninguna con «en esta página» ni «volver arriba». |
| Grupos poco claros | «Referencia» mezclaba Estilo, Paleta, Textos, Megafonía, Procedencia y Versiones; «El juego» mezclaba diseño con arte. |
| Duplicados y solapes | Resumen (lista de pantallas) y Pantallas eran lo mismo con dos nombres; «Paleta» y «Paleta propuesta» sin relación aparente; Textos y Megafonía repiten las claves `MEGA_`; los sonidos, en tres sitios (Sonidos, Megafonía, fichas de objetos). |
| Enlaces cruzados | Buenos entre Procedencia y Referencias, pobres entre el resto. |
| Estados vacíos | Procedencia y Referencias avisaban; Textos y Objetos no. |
| Móvil (390 px) | La barra lateral era un bloque de **965 px** encima de cada página (había que bajar un kilómetro para leer). Textos y Procedencia tenían **scroll horizontal** (456 y 464 px). |
| Accesibilidad | Sin «saltar al contenido», sin nombres accesibles en los filtros y campos de búsqueda, imágenes ampliables sin teclado, texto gris `#72777d` por debajo de AA. |
| Bug de paso | 7 objetos del catálogo (tipo `hide`, los escondites) rompían su ficha al pulsarlos (`TIPOS` no tenía el tipo). Corregido. |

## 2. El árbol nuevo

Agrupado por lo que busca cada persona, no por cómo está hecho el código.

```
Empezar
  Resumen               el mapa de todo, «¿qué quieres hacer?»
  Capturas
Jugar y diseño
  Pantallas             (y su árbol: portada, título, noche, dojo…)
  Historia
  Ciudad y museos
  Antes de un robo
  Minijuegos
  Escondites
  Colección
  Objetos y piezas
  Personajes
Contenido editable
  Textos
  Megafonía
Arte y sonido
  Estilo
  Paleta
  Paleta propuesta
  Sonidos
Origen y licencias
  Assets a incorporar
  Referencias
Técnico
  Versiones
```

**Por qué así**

- *Empezar* responde a «acabo de llegar»: un mapa por intenciones y las capturas, sin leer nada.
- *Jugar y diseño* junta todo lo que explica **qué es el juego** (pantallas, historia, museos, reglas, cosas y personajes). Quien diseña o prueba vive aquí.
- *Contenido editable* separa lo que **se cambia desde el visor** con `serve` (textos y megafonía); quien escribe no tiene que buscar entre lo demás.
- *Arte y sonido* junta lo que consulta quien dibuja o compone: estilo, colores, sonidos.
- *Origen y licencias* junta lo legal y la investigación de terceros: de dónde sale un asset, con qué se puede sustituir y qué enlaces se han guardado. Antes estaba repartido entre «Referencia» y «El juego».
- *Técnico* queda para lo que solo mira quien mantiene el proyecto. Hoy solo hay Versiones (hitos); el código y las funciones se ven dentro de las pantallas («Opciones y detalles») y de las páginas de mecánicas, y no merecen una página propia hasta que haya más. Si aparece una página de tests o de código, va aquí: una entrada en `GRUPOS` de `navegacion.js`.

Cambios de nombre solo en la etiqueta (las direcciones no cambian): «Ciudad» → «Ciudad y museos», «Procedencia» → «Procedencia y alternativas», «Objetos y piezas» ya se llamaba así.

**Direcciones.** Ninguna se ha renombrado, así que todos los `#hash` antiguos siguen valiendo. Un único cambio: `#pantallas` y la lista de todas las pantallas ahora son una página propia (`#pantallas`); antes `#pantallas` era un alias de `#inicio`, que ahora es la portada-mapa.

## 3. Qué se ha añadido

| Pieza | Qué hace |
|---|---|
| Barra lateral en 6 grupos colapsables | Recuerda el estado (`localStorage`); el grupo de la página actual se abre al entrar; el árbol de pantallas cuelga de «Pantallas». |
| Buscador global | `/` o `Ctrl`/`Cmd`+`K` (o el botón «Buscar»). Índice construido al cargar desde los datos existentes: páginas, apartados, pantallas (con sus opciones), objetos y piezas, personajes, historia (25 robos con su cuento), ciudad, sonidos, ~1100 textos, 329 frases de megafonía, referencias, propuestas de assets a incorporar y constantes de paleta (por nombre o `#hex`). Sin tildes, varias palabras a la vez, resaltado, filtro por tipo, teclado completo. Cada resultado lleva **directo** al sitio: fila del texto, ficha del objeto, colección (quitando los filtros que la esconderían), etc. |
| Migas y título fijos | Barra pegada arriba: Ninja Karma › Grupo › Página (› subpantallas) › **sección en la que estás** (cambia al hacer scroll). También el `<title>` de la pestaña. |
| «En esta página» | Índice lateral a partir de 1360 px, plegable arriba en pantallas menores; resalta el apartado actual y hace scroll suave. |
| Enlaces profundos | `#pagina/seccion` estable; el `#` junto a cada título copia su enlace; atrás y adelante recuperan el apartado; los apartados se marcan con un destello al llegar. |
| Volver arriba y pie | Botón flotante y, al pie de cada página, «anterior / siguiente» (por el orden de los grupos; en pantallas, por el orden del árbol). |
| Portada | «¿Qué quieres hacer?»: 7 tarjetas por intención con una línea por página y su cifra; el mapa por grupos y las pantallas principales. |
| Móvil | Menú hamburguesa en cajón (deja de comerse 965 px), migas cortas, buscador a pantalla completa, tabla de Textos apilada, rutas largas que se parten: **sin scroll horizontal a 390 px en ninguna página**. |
| Accesibilidad | «Saltar al contenido», foco visible, `aria-current`, `aria-pressed` en filtros, nombres en campos, imágenes ampliables con teclado, diálogo del buscador con foco atrapado y `Esc`, `prefers-reduced-motion`, gris de texto a contraste AA. |
| Estados vacíos | Buscador («Nada para…», con sugerencias) y tabla de Textos. |

## 4. Cómo mantenerlo

- Página nueva: `<section class="pagina" id="p-<id>">`, su función de pintado en `pintar()` y **una entrada en `GRUPOS`** (`navegacion.js`); el buscador, la barra, la portada y el pie la recogen solos.
- Apartados: cualquier `<h2>` (o `<h3>` en Megafonía) de la página sale en el índice; si no tiene `id`, se le pone uno. Para que un enlace `#pagina/algo` llegue, el `id` del elemento ha de ser `pagina-algo`.
- Datos nuevos que deban ser buscables: añadirlos en `construirIndice()`.

## 5. Pendiente / ideas no hechas

- Una página «Técnico» real (funciones, código, tests) si se quiere que sea navegable como el resto: hoy esos datos (`funciones.js`, `codigo.js`) solo se ven dentro de otras páginas.
- ~~Enlaces cruzados más ricos entre Sonidos, Megafonía y las fichas de objetos que los usan.~~ Sin tocar todavía (fuera del encargo de «contexto de un robo»); sigue pendiente.
- Textos: agrupar por pantalla o por museo además de por prefijo, y paginar (hoy corta a 600 filas).

### Hecho: contexto completo de un robo (Historia)

`noche()` (en `historia()`, `docs/index.html`) ahora, por cada robo:
- Muestra sus capturas reales (`docs/data/capturas.json`, emparejadas por `_robo_NN` en el `id`, tanto `previa_robo_NN_*` como `juego_robo_NN*`) en una `<details>` plegable con galería, para no alargar las 25 fichas.
- Si el robo no tiene ninguna captura propia (12 de 25 hoy: la muestra es representativa, no las 25 noches), cae en la foto exterior del museo (`docs/data/ciudad.json`, `museums[].shot`) con un pie honesto («no es una foto de este robo en concreto»).
- Añade una línea «También:» con enlaces a los objetos de decoración del tema del museo (`#objetos/<tema>`), a Personajes (`#personajes`, el ladrón y el guardia son genéricos, sin variante por museo) y a la ficha del museo en Ciudad (`#ciudad/museoN`).
- La ficha de cada pieza en Objetos y piezas (`piezasComoObjetos()`) enlaza ahora directo a su robo (`#historia/robo-N`, antes iba solo a la sección del museo) y, nuevo, a su museo en Ciudad.
- El buscador global indexa también los títulos y textos de las capturas de cada robo (`navegacion.js`, `construirIndice()`), así que buscar «linterna» encuentra el robo 4 aunque la palabra no esté en su cuento.

**Huecos que quedan, no cerrados en esta sesión** (baratos de resolver en otra, si se quiere seguir el mismo criterio):
- La imagen de cada pieza (`assets/piezas/NN.webp`) no tiene regla de procedencia en `assets/PROCEDENCIA.json` (son capturas propias del juego, no assets de terceros): comprobado que no aplica un enlace de licencia ahí, así que no se añadió.
- La página Colección (`#coleccion`) no enlaza de vuelta a los robos concretos de cada tema (solo Ciudad lo hace); sería el mismo patrón que ya usa `ciudad()`.
- Los guardias son un único modelo genérico en Personajes: si algún día hay variante por museo o por tema, la ficha de robo ya tiene el sitio (`#personajes`) para apuntar más fino.

## Actualización: Procedencia y Alternativas ya no son páginas

«Procedencia y alternativas» (colecciones, filtros por licencia, comparaciones, elección) se ha sustituido por una sola página, **Assets a incorporar** (`#propuestas`), un tablero de propuestas de assets concretos con estado (propuesto, aceptado, incorporado, descartado). Sigue en el grupo «Origen y licencias», junto a Referencias. `#procedencia` y `#alternativas` redirigen a ella (con `#procedencia/<algo>` se abre «Lo que ya usamos», la tabla plegada del pie). El buscador global indexa las propuestas y ya no las colecciones ni las alternativas.
