# Tareas de la auditoría de navegación y UX

Fuente: [auditoría del 1 de octubre](analisis_codex_2026-10-01.md).

Los agentes trabajan **uno por uno en este mismo workspace**. El coordinador revisa el resultado antes de iniciar el siguiente bloque. No se hacen commits automáticos.

| Tarea | Prioridad | Trabajo y aceptación | Dependencia | Estado |
| --- | --- | --- | --- | --- |
| N1 | Crítica | Aislar el estado de la vista previa de Retos; recorrer robos con distintos guardias sin errores de índices y añadir regresión. | — | Completada |
| N2 | Alta | Unificar controles, rótulos y ayuda de ciudad/museo/plano; verificar aceptar y retroceder con teclado y eventos de mando. | N1 | Completada |
| N3 | Alta | Confirmar la pérdida de la noche al volver a portada; cancelar conserva la partida pausada. | N2 | Completada |
| N4 | Alta | Reservar espacio para leyenda y retratos del mapa, comprobando tamaños de ventana/interfaz. | N3 | Completada |
| N5 | Media | Añadir humo a Controles con las asignaciones reales de J1, J2 y mando. | N4 | Completada |
| N6 | Media | Conservar el título completo de Retos y explicar con texto el distintivo de robo retocado. | N5 | Completada |
| N7 | Media | Explicar los parámetros generativos, mejorar contraste y separar selector de Empezar; comprobar ventana pequeña. | N6 | Completada |
| N8 | Media | Añadir ayuda sobre efecto/coste y forma de ajustar las opciones de Pantalla/Opciones. | N7 | Completada |
| CARD-DOJO | Petición adicional | Tarjeta Dojo en portada, acceso compartido con escondite y progreso ligado a Historia; comprobar entrada/salida y selección de banda. | N8 | En curso |
| TEMA-2D | Petición adicional | Crear cinco iconos PNG originales, uno por temática de museo, y reemplazar la escena 3D del selector de tema por estas imágenes estáticas. | C1 | Assets en curso; integración pendiente |
| C1 | Completada | Contrastar unión de jugadores, textos de alarma/escondite, ayuda inicial, secciones de Retos y observaciones del editor/ratón. Corregir lo demostrado; registrar límites de validación. | CARD-DOJO | Pendiente |

## Orden de agentes

1. Agente de estabilidad: N1.
2. Agente de navegación y pausa: N2–N3.
3. Agente de mapa y controles: N4–N5.
4. Agente de claridad de menús: N6–N8.
5. Agente de tarjeta Dojo: CARD-DOJO (prepara en lectura mientras corre el bloque 4; implementa después).
6. Agente de contraste de contenido: C1.

## Resultados y comprobaciones

Se actualizarán al revisar cada entrega. Superset CLI está instalado, pero sin autenticación; la ejecución usa los agentes de esta sesión.

### Agente 1 — N1

- Cambios: `scenes/challenge_screens.gd`; regresión `tests/test_challenge_preview.gd`. Generación en Game temporal y préstamo/restauración de estructuras globales, conservando referencias y alias.
- Agente: challenge_preview, mapfile, menus, heist y story pasan; importación y diff sin problemas.
- Coordinador: `tests/run_all.sh challenge_preview` pasa (50 selecciones, antes/después de partida multijugador); diff revisado.
- Límite: comprobación headless. La generación conserva el uso anterior del RNG global; no se restaura su secuencia.

### Agente 2 — N2–N3

- Cambios: `scenes/tour.gd`, `scenes/main.gd`, CSV y traducción; regresiones en menus/previa. Rótulo ESC coherente; confirmación de salida compartida, NO predeterminado, regreso al editor preservado.
- Agente: menus, previa, finales y controles pasan. Repetidos menus/previa después de importar traducción. Logs `/tmp/ninja-n2-n3-final` y `/tmp/ninja-n2-n3-tests`.
- Coordinador: revisión de diff y resultados de logs; `git diff --check` correcto.
- Límite: eventos de mando sintéticos. Error preexistente en `_bubble_open` durante menus; se revisará en N7 por afectar al selector.

### Agente 3 — N4–N5

- Cambios: `scenes/hud.gd`, `scenes/settings_screens.gd`, CSV/traducción; regresión `tests/test_map_controls.gd`. Imagen flexible, leyenda envolvente y visibilidad de retratos conservada. Fila HUMO: F / coma / Y.
- Agente: map_controls, textos y smoke pasan (`/tmp/n4-n5-final`); geometría en 216 combinaciones, eventos/polling de controles.
- Coordinador: diff, resultados de logs y renders Metal del mapa al 150% y Controles al 100% revisados; leyenda y HUMO legibles.
- Hallazgo para N8: Controles no cabe al 150% (problema previo); revisar accesibilidad de Ajustes a tamaño pequeño.

### Petición adicional — CARD-DOJO

El usuario autorizó crear la tarjeta Dojo en portada durante el bloque 4. El agente comienza con lectura, sin editar hasta que termine el bloque de menús. La integración reutiliza el progreso existente.

### Agente 4 — N6–N8

- Cambios: Retos lleva `* RETOCADO` delante del título y leyenda; nombre completo envuelto. Generativo explica parámetros y adapta contraste/selectores. Ajustes explica efecto/coste y aplicación inmediata, con scroll y seguimiento de foco.
- Corregido error de `_bubble_open` al cerrar/recrear durante foco; dibujo de cada cola asociado a su Control.
- Agente: menus, menu_clarity, textos, challenge_preview y map_controls pasan, sin SCRIPT ERROR (`/tmp/ninja-n6-n8-verified`).
- Coordinador: revisados diffs, logs y renders pequeños de Tema/Ajustes/Retos; etiquetas legibles, Empezar libre y foco accesible.
- Sin cambios de firmas públicas; card Dojo inicia implementación tras esta entrega.

### Tarjeta Dojo — revisión coordinador

La implementación quedó en `scenes/main.gd`, `scenes/hands.gd`, `scenes/menu_stage.gd`, `locale/texts.csv` y `tests/test_dojo_card.gd`. Reutiliza `Practice.MODE`, `Practice.open_trials`/`DojoTrials`, entra al dojo para la banda elegida, conserva la entrada original desde el escondite y vuelve al origen al salir. El coordinador corrigió el test de menú para comparar el área visible en las mismas unidades de la ventana. Prueba `dojo_card` pasa; repetición secuencial de pruebas de integración en curso. Renders: `/tmp/dojo-card-qa/`.

### Integración tras la tarjeta Dojo

- `JOBS=1 tests/run_all.sh dojo_card menus previa challenge_preview menu_clarity map_controls smoke textos finales controles`: **10/10 verdes** (log `/var/folders/72/tbfn9qkn3f58f405l8_b7yxh0000gs/T/ninja-tests.FyOs66`).
- Nota: la primera ejecución amplia mezcló el nombre inexistente `finals` (el test es `finales`) y una aserción del nuevo test de menú comparaba coordenadas de ventana con área lógica; corregida a tamaño de ventana. La repetición serial completa pasa.
- Renders de portada Dojo revisados en `/tmp/dojo-card-qa/`: 1280×720 al 100%; 960×540 al 150%. Selección Dojo visible y legible.

### Agente 5 — C1

- Unión ahora aclara teclas de cada lado, mandos, Escape y límite de 2 jugadores por teclado. Lección y consejo separan el tiempo de abrir la vitrina del momento de salir con la pieza; la vitrina práctica nombra su sujeto.
- Pausa dirige a Ajustes → Controles; Retos nombra las secciones; editor indica iconos al foco y separa instrucciones 3D de herramienta.
- Tests afirmados por el agente: menus, previa, ciudad_nav, heist, textos y dojo_card; logs `/tmp/ninja-c1-verified` y `/tmp/ninja-c1-final`. Renders `/tmp/ninja-c1-join4.png`, `/tmp/ninja-c1-editor3d.png`.
- Límite: no se alteró observación de clic en salas del museo, que la auditoría marca no confirmada. Sin mando físico ni contraste de usuarios nuevos.

### Petición adicional — TEMA-2D

El usuario pidió cinco iconos bitmap 2D generados, sin usar `tests/visual/icons.gd`: faraón (antiguo), yelmo (edad_media), cráneo fósil (prehistoria), mariposa (naturaleza) y radio (moderna). Se guardaron en `assets/ui/temas/` como PNG RGBA de 512×342.

- `MENU_THEME` usa el PNG de la temática en su tarjeta y en las seis opciones del selector. Aleatorio muestra un collage 2D con alfa y caché; no crea escenas 3D de tema. El HUD filtra estas imágenes suavemente.
- `tests/test_menu_clarity.gd` comprueba que cada opción y tarjeta usa la imagen correcta, que no aparece un `MenuStage` temático y que el collage se conserva transparente y cacheado.
- Agente y coordinador: `menu_clarity` y `map_controls` pasan; render Metal de tarjeta y selector recorriendo las seis opciones sin errores (`/tmp/theme2d-render.log`). Revisión visual en `/tmp/theme2d-random-card.png` y `/tmp/theme2d-selector.png`.
- Nota menor: algunas etiquetas de tema quedan próximas entre sí en la ventana 1280 px, pero los iconos y la selección se ven correctamente.

### Ajuste visual — stickers y etiquetas

- Tras la revisión del usuario, los cinco PNG se regeneraron como stickers cartoon de colores planos, contorno violeta y borde blanco recortado; `antiguo`, `edad_media`, `prehistoria`, `naturaleza` y `moderna` verificados contra sus temas. Aleatorio compone los cinco.
- El selector usa rótulos cortos (`ANTIGUO`, `MEDIEVAL`, `PREHISTORIA`, `NATURALEZA`, `MODERNA`) y los ajusta al ancho de cada opción. `menu_clarity` vuelve a pasar (`FALLOS: 0`). Captura Metal renovada: `/tmp/ninja-n6-n8-theme.png`.
