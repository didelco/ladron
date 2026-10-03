# Espacios de la guarida

- `salon.tscn`: entrada desde Guarida, recreativa y salida a la ciudad.
- `dojo.tscn`: entrenamiento, pruebas, aseo y alas cooperativas.
- `museo_casa.tscn`: colección de las piezas robadas.

Cada archivo instancia `HomeSpace` y guarda su propio plano y mobiliario. Para
editarlo, abre la escena en Godot y selecciona su nodo raíz. En el Inspector:

- `map_size` y `rooms` definen los límites y el suelo en casillas.
- `furniture` define modelos, posición (`at`), giro (`yaw`), escala (`s`) y
  casillas que ocupan (`block`).
- `doors` y `sensors` son puertas internas de esa escena.
- `portals` define umbrales para cambiar de escena; `arrivals` coloca la banda
  al llegar desde cada origen, fuera del umbral para evitar rebotes.
- `gallery` contiene los puestos del museo; `dojo_plan` y `dojo_zones`, el dojo.

El dibujo se genera al cargar la escena durante el juego. También se pueden
añadir nodos 3D propios como hijos de la escena. Las coordenadas de los tres
archivos son independientes: ampliar una zona no desplaza las demás.
Al cruzar un portal cambia toda la banda, conserva sus controles y el progreso,
sin selector ni menú intermedio. Guarida entra directamente al salón.
