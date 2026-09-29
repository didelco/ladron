window.RESUMEN = {
 "_": "El Resumen corto de la portada de la documentación (página «Resumen»). Se edita a mano; `python3 tools/docs.py texts` lo vuelca a resumen.js. Cada línea: 3 a 6 palabras. Un elemento de «items» es un texto o {\"t\": texto, \"href\": \"#pagina\"}. Se sustituyen {robos}, {museos}, {version} y {fecha} con los datos reales (historia.json, ciudad.json, project.godot); no hay que escribir esas cifras a mano. «museos»: true añade los nombres de los museos. «mas» es el enlace «más detalle →» a la página completa del tema.",
 "titular": "Ninja Karma",
 "subtitulo": "Sigilo cooperativo de noche: roba la pieza, esquiva a los guardias, sal.",
 "chips": [
  {
   "valor": "{robos}",
   "etiqueta": "robos",
   "href": "#historia"
  },
  {
   "valor": "{museos}",
   "etiqueta": "museos",
   "href": "#ciudad"
  },
  {
   "valor": "1-4",
   "etiqueta": "ladrones",
   "href": "#pantallas"
  },
  {
   "valor": "{version}",
   "etiqueta": "versión",
   "href": "#versiones"
  }
 ],
 "secciones": [
  {
   "id": "jugadores",
   "titulo": "Jugadores",
   "items": [
    "Solo: un ladrón",
    "Cooperativo: de 2 a 4",
    "Teclado: dos como mucho",
    "Mandos: hasta cuatro",
    "Vitrina con alarma: uno sujeta el cuadro"
   ],
   "mas": {
    "t": "Pantallas",
    "href": "#pantallas"
   }
  },
  {
   "id": "modos",
   "titulo": "Modos",
   "items": [
    "Historia: {museos} museos, {robos} robos",
    "Generativo: un museo nuevo cada vez",
    "Retos y editor de mapas",
    "La casa de la banda y el dojo"
   ],
   "mas": {
    "t": "Pantallas",
    "href": "#pantallas"
   }
  },
  {
   "id": "historia",
   "titulo": "Historia",
   "items": [
    "{museos} museos × 5 pruebas",
    "Cuatro robos y un gran golpe",
    "El Barón Von Bostezo lo ha robado todo",
    "La Banda del Calcetín rescata las obras"
   ],
   "museos": true,
   "mas": {
    "t": "Historia",
    "href": "#historia"
   }
  },
  {
   "id": "controles",
   "titulo": "Controles",
   "items": [
    "Moverse: WASD, flechas o stick",
    "Acción: E, . o A",
    "Rodar y soltar: Espacio, Enter o B",
    "Mapa M · pausa P · sonido N",
    "Andar lento: Shift"
   ],
   "mas": {
    "t": "Pantallas",
    "href": "#pantallas"
   }
  },
  {
   "id": "mecanicas",
   "titulo": "Mecánicas clave",
   "items": [
    {
     "t": "Sigilo: ruido, gatas y escondites",
     "href": "#escondites"
    },
    {
     "t": "Guardias: ven, oyen y piensan",
     "href": "#personajes"
    },
    "Alarma: sube y llama a los demás",
    {
     "t": "Minijuegos: ganzúa, cables, pulso",
     "href": "#minijuegos"
    },
    "Dojo: práctica sin riesgo"
   ],
   "mas": {
    "t": "Minijuegos",
    "href": "#minijuegos"
   }
  },
  {
   "id": "estado",
   "titulo": "Estado y versión",
   "items": [
    "Versión {version}",
    "Godot 4.7, escritorio",
    "Sin cerebro IA: guardias con reglas fijas",
    "Documentación de {fecha}"
   ],
   "mas": {
    "t": "Versiones",
    "href": "#versiones"
   }
  }
 ],
 "version": "0.1.315"
};
