# Créditos

<!-- Generado por tools/procedencia.py a partir de assets/PROCEDENCIA.json: no se edita a mano. -->

## Recursos de terceros

| recurso | autor | licencia |
|---|---|---|
| `assets/fonts/PressStart2P-Regular.ttf` (Press Start 2P) | The Press Start 2P Project Authors | [SIL Open Font License 1.1](https://openfontlicense.org/) |
| `assets/fonts/UnifrakturMaguntia-Book.ttf` (UnifrakturMaguntia, la cabecera del periódico) | j. 'mach' wust, Peter Wiegel | [SIL Open Font License 1.1](https://openfontlicense.org/) |
| `assets/fonts/AbrilFatface-Regular.ttf` (Abril Fatface, los titulares del periódico y la ficha) | TypeTogether | [SIL Open Font License 1.1](https://openfontlicense.org/) |
| `assets/models/statue-a.glb`, `assets/models/statue-b.glb` (Estatua) | — (Poly Pizza; autor sin anotar) | [Creative Commons Cero 1.0 (dominio público)](https://creativecommons.org/publicdomain/zero/1.0/) |
| `assets/models/bear.glb` (Black bear) y su textura `bear_BlackBear_BaseColor.png` | Poly by Google | [Creative Commons Reconocimiento 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `assets/models/ciudad/comercial/` (City Kit Commercial 2.1: edificios y rascacielos de la ciudad) | Kenney | [Creative Commons Cero 1.0 (dominio público)](https://creativecommons.org/publicdomain/zero/1.0/) |
| `assets/models/ciudad/suburbios/` (City Kit Suburban 2.0: casas, árboles y vallas) | Kenney | [Creative Commons Cero 1.0 (dominio público)](https://creativecommons.org/publicdomain/zero/1.0/) |
| `assets/models/ciudad/calles/` (City Kit Roads 2.1: calles, cruces y farolas) | Kenney | [Creative Commons Cero 1.0 (dominio público)](https://creativecommons.org/publicdomain/zero/1.0/) |
| `assets/models/casa/` (Furniture Kit 2.0: sofás, cocina, baño y demás muebles de la casa de la banda) | Kenney | [Creative Commons Cero 1.0 (dominio público)](https://creativecommons.org/publicdomain/zero/1.0/) |

### Atribución

- **Obligatoria** (CC BY 3.0): *Black bear* por Poly by Google, con licencia Creative Commons Reconocimiento 3.0. Ya no lo carga ningún script (el oso del juego es el propio oso.glb, desde el commit 258cf17), pero sigue en el repositorio y en las exportaciones: mientras esté, la atribución es obligatoria.
- **Obligatoria** (CC BY 4.0): Respuesta al impulso «Yorkshire Air Museum, hangar T2» (reverb), de OpenAIR, University of York (https://www.openair.hosting.york.ac.uk/), dentro de «Megafonía del museo (voz sintética)». CC BY 4.0 según el catálogo de OpenAIR; el README de megafonia-tool dice «confirmar antes de publicar». El audio resultante es una obra derivada: hay que citar «OpenAIR, University of York».
- Los modelos de Poly Pizza se descargaron de [Poly Pizza](https://poly.pizza).
- Los kits de ciudad y casa de Kenney (www.kenney.nl) son CC0: no piden atribución, pero se la damos igual. Se usan tal cual, en `.glb`; los colores de noche, las ventanas encendidas y los tejados los pone el juego (`TownBuilder.NIGHT_SHADER`).

## Obra propia y material que la acompaña

| colección | cómo se hizo | licencia |
|---|---|---|
| Catálogo modelado en Blender | Modelado en Blender (art/*.blend: museo, coleccion, botin y un tema por fichero), en parte con scripts de Python (art/temas/*.py, art/botin/*.py) y retocado a mano; exportado a .glb con art/export.py. | Propia |
| Personajes (ninja y guardia) | Modelados por script en Blender (art/characters/kit.py, ninja.py, guardia.py, rig.py: formas sencillas fundidas con remallado de vóxeles, esqueleto y acciones) y retocados a mano en art/personajes/*.blend; exportados con art/export.py. | Propia |
| Sonido sintetizado en código | Todos los efectos y la música se sintetizan al arrancar el juego (scenes/sfx.gd): ruido filtrado, parciales que decaen, sierras que se deslizan; la música es una pieza en re menor y otra en do mayor renderizadas en un hilo. | Propia |
| Megafonía del museo (voz sintética) | Frases MEGA_* de locale/texts.csv convertidas a .ogg con megafonia-tool (carpeta hermana ../megafonia-tool, fuera de este repositorio): TTS local Kokoro-82M con mlx-audio (voz em_santa, velocidad 0,9), cadena de «bocina en sala grande» con pedalboard (paso bajo, saturación, compresor), reverb por convolución con la respuesta al impulso del hangar del Yorkshire Air Museum al 30 % (25 % en las MEGA_ALARM_*), -16 LUFS, .ogg mono a 44,1 kHz. Lleva: Kokoro-82M (modelo TTS; voz em_santa) (hexgrad (conversión mlx-community/Kokoro-82M-bf16), Apache 2.0); Respuesta al impulso «Yorkshire Air Museum, hangar T2» (reverb) (OpenAIR, University of York, CC BY 4.0); Muestras vocales (risa, suspiro, ejem, tos) (ezwa (Wikimedia Commons), Dominio público). | Propia |
| Pegatinas de cabezas ninja | Dibujadas por código con Pillow (tools/ninja_stickers.py), con los colores de los ladrones leídos de scenes/main.gd. | Propia |
| Iconos de objetos del editor | Renders de 128 px de los propios modelos del juego, con la luz y el ángulo de siempre, sacados con tests/visual/icons.tscn. | Propia |
| Iconos vectoriales del editor | SVG sencillos escritos como código (formas blancas sobre 64 px) para los botones del editor de mapas; el juego los tiñe. | Propia |
| Shaders del juego | Escritos a mano en el lenguaje de shaders de Godot (suelo y pared de los museos, sombreado toon). | Propia |
| Ficheros fuente de arte | Los .blend, los scripts de Blender (art/**/*.py) y el generador de primitivas (art/botin/primitivas.gd) de los que salen los modelos. | Propia |

## Origen sin documentar

Estos assets están en el juego pero no se anotó de dónde salen ni con qué licencia. Cuando se sepa, se completa en `assets/PROCEDENCIA.json`.

- **Mapamundi del globo**: No se sabe de qué datos o imagen de mapa sale ni con qué licencia.
- **Ilustraciones de portada, menús y museos**: Portada, fondo de los menús y los cinco fondos de museo. El dueño debe anotar herramienta, autor y licencia.
- **Foto de detenido**: Sustituyó a las dos fotos renderizadas con MugshotStage.
- **Logo e icono de Ninja Karma**: Antes el icono era un pixel-art del ladrón bajo la luna (commit ed1b2ac).

El detalle de cada fichero (colección, método, autor y licencia) está en la página «Procedencia» de la documentación (`python3 tools/docs.py serve`) y se comprueba con `python3 tools/procedencia.py`.
