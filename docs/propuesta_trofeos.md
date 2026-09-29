# Propuesta: trofeos que cuadran con su museo

Cada robo conserva su nivel, su mecánica, sus segundos, sus estrellas y su color de ficha; solo
cambian el objeto (nombre, frase, verbo, historia) y su modelo. El hilo sigue siendo el del Barón:
expone como «tesoro» lo que les quitó a los vecinos.

El museo 3 pasa a llamarse **La Villa Clásica** (`MUSEUM_3_NAME/TEXT`). El tema interno sigue
siendo `antiguo` (clave de datos, mapas y `MapFile`), pero su etiqueta visible (`THEME_ANTIGUO`)
pasa a **MUNDO CLÁSICO**.

## Los 25 huecos

| Robo | Museo | Antes | Después | Modelo | Verbo |
|---|---|---|---|---|---|
| 1 | Prehistoria | la dentadura del abuelo Paco | igual («mandíbula de cavernícola») | reutilizado `teeth` | DESENROSCANDO EL TARRO (igual) |
| 2 | Prehistoria | el calcetín del yeti | la bola de chicle del récord («coprolito gigante») | reutilizado `gum` | DESPEGANDO EL CHICLE |
| 3 | Prehistoria | el bote de ketchup de Jake | igual («pintura roja de las cavernas») | reutilizado `ketchup` | DESPEGANDO LA COSTRA (igual) |
| 4 | Prehistoria | el gnomo que baila claqué | el hueso del perro Bruto («fémur de mamut») | **nuevo** `bone` | SACANDO EL HUESO |
| 5 | Prehistoria (gran golpe) | el huevo del dinosaurio despistado | igual | reutilizado `egg` | SOLTANDO EL HUEVO (igual) |
| 6 | Ciencias Naturales | la corona de la Reina de los Pepinillos | la planta carnívora Filomena | **nuevo** `plant` | SOLTANDO LA MACETA |
| 7 | Ciencias Naturales | la bufanda del caracol friolero | el caracol Anselmo | **nuevo** `snail` | DESPEGANDO AL CARACOL |
| 8 | Ciencias Naturales | la máscara del Pulpo Enmascarado | igual (bichos del mar) | reutilizado `mask` | CORTANDO EL SELLO (igual) |
| 9 | Ciencias Naturales | la bola de pelo del gato Misifú | la amatista gigante de la abuela Lola | **nuevo** `crystal` | SACANDO LA PIEDRA |
| 10 | Ciencias Naturales (gran golpe) | el pato que canta ópera | el pato que canta ópera, expuesto como «especie recién descubierta» | reutilizado `duck` | CALMANDO AL PATO (igual) |
| 11 | Villa Clásica | el faraón de juguete de Pablito | el ánfora «Recuerdo de Atenas» | **nuevo** `amphora` | SOLTANDO EL ÁNFORA |
| 12 | Villa Clásica | el despertador de la momia Ramona | la corona de laurel de neón de César | **nuevo** `laurel` | APAGANDO EL NEÓN |
| 13 | Villa Clásica | el pato de goma de Arquímedes | la columna dórica de plástico de los Pérez | **nuevo** `column` | DESINFLANDO LA COLUMNA |
| 14 | Villa Clásica | el huevo duro del tío Ramsés | el David con delantal del carnicero | **nuevo** `david` | QUITANDO EL DELANTAL |
| 15 | Villa Clásica (gran golpe) | el anillo de Cleopatra | la Venus con gafas de sol de la peluquería | **nuevo** `venus` | QUITANDO LAS GAFAS |
| 16 | Castillo | el despertador de Leonardo | igual | reutilizado `clock` | PARANDO EL TANGO (igual) |
| 17 | Castillo | la albóndiga de la catapulta | igual | reutilizado `rock` | LEVANTANDO LA BOLA (igual) |
| 18 | Castillo | la bola de cristal de la bruja Paca | la espada en la piedra | **nuevo** `sword` | SACANDO LA ESPADA |
| 19 | Castillo | la mascarilla del dragón estornudón | el ornitóptero de Leonardo | **nuevo** `ornithopter` | PLEGANDO LAS ALAS |
| 20 | Castillo (gran golpe) | la corona del rey de las croquetas | igual | reutilizado `crown` | DESATORNILLANDO LA CORONA (igual) |
| 21 | Arte Contemporáneo | la tostada con la cara del Barón | igual | reutilizado `toast` | DESPEGANDO LA TOSTADA (igual) |
| 22 | Arte Contemporáneo | la bola de chicle del récord | el plátano pegado con cinta | **nuevo** `banana` | DESPEGANDO LA CINTA |
| 23 | Arte Contemporáneo | la dentadura que brilla en la oscuridad | el cubo de fregona «Limpieza y vacío» | **nuevo** `bucket` | VACIANDO EL CUBO |
| 24 | Arte Contemporáneo | el calcetín desparejado de Jake | igual («Soledad») | reutilizado `sock` | DOBLANDO LA OBRA DE ARTE (igual) |
| 25 | Arte Contemporáneo (final) | el Diamante Bostezo | igual | reutilizado `gem` | ABRIENDO LA CAJA FUERTE (igual) |

## Modelos

- **Nuevos (13)**: `bone`, `plant`, `snail`, `crystal`, `amphora`, `laurel`, `column`, `david`,
  `venus`, `sword`, `ornithopter`, `banana`, `bucket`. Hechos en Blender con primitivas low-poly en
  `art/botin/nuevas.py`, en `art/botin.blend` y exportados a `assets/models/botin/`. Los
  materiales `color*` siguen el color de la ficha; el resto (cinta, gafas, delantal...) son fijos.
- **Reutilizados**: `teeth`, `gum`, `ketchup`, `egg`, `mask`, `duck`, `clock`, `rock`, `crown`,
  `toast`, `sock`, `gem`.
- **Sin uso en la historia** (siguen en el catálogo y en el modo generativo): `idol` (gnomo y
  faraón). Los objetos retirados, sin modelo propio: calcetín del yeti, caracol/bufanda, bola de
  pelo, faraón de juguete, despertador de la momia, pato de Arquímedes, huevo del tío Ramsés,
  anillo de Cleopatra, bola de cristal de la bruja, mascarilla del dragón, dentadura luminosa.

## Otros textos

`STORY_PROLOGUE` (dentadura, pato y ketchup siguen), `STORY_ENDING` (el yeti se cambia por el
perro Bruto), `MUSEUM_3_NAME/TEXT`, `THEME_ANTIGUO`, y las claves `MEGA_*` que nombran objetos
viejos (ver informe; sus voces ya generadas no se tocan).
