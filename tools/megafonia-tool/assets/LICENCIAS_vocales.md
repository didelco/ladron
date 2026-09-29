# Licencias de las muestras de `assets/vocales/`

Todas vienen de Wikimedia Commons y se recortan con `python src/prepara_vocales.py`
(fuentes y recortes en `config.yaml`, `vocales_fuentes`). Ninguna pide atribución,
pero se deja anotado de dónde sale cada una.

| fichero | original | recorte | autor | licencia |
|---|---|---|---|---|
| `carraspeo.wav` | [Laughter and clearing voice.ogg](https://commons.wikimedia.org/wiki/File:Laughter_and_clearing_voice.ogg) | 5.15–6.80 s (soplo + «hm») | ezwa | Dominio público |
| `ejem.wav` | ídem | 6.15–6.80 s (solo el «hm» con voz) | ezwa | Dominio público |
| `risa.wav` | ídem | 0.10–2.60 s (primera tanda de risa) | ezwa | Dominio público |
| `tos.wav` | [Cough 2.ogg](https://commons.wikimedia.org/wiki/File:Cough_2.ogg) | 2.40–3.60 s | ezwa | Dominio público |
| `suspiro.wav` | [Four sighs.ogg](https://commons.wikimedia.org/wiki/File:Four_sighs.ogg) | 1.10–2.10 s (primer suspiro) | ezwa | Dominio público |

Los recortes se eligieron por análisis (envolvente, tono y ruido de cada tramo), sin escucharlos:
conviene revisarlos a oído y, si alguno no convence, cambiar `ini`/`fin` en `config.yaml`
o sustituir el wav por una grabación propia (mismo nombre).

Otras candidatas descargables sin cuenta, también de Commons, por si hacen falta:
*Cough 1.ogg*, *Three sighs.ogg*, *Hm and sigh.ogg* (ezwa, dominio público);
*Laughter(s).ogg* (sagetyrtle, CC0); *Krusty laugh impression.ogg* (dominio público, risa de payaso).
