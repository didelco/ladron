# Biblioteca del menú antiguo

Copia íntegra del proyecto antes de migrar los menús, con los cambios locales existentes, escenas GDScript, recursos 3D, imágenes, shaders, audio, traducciones, mapas y pruebas. Godot genera los dioramas desde `scenes/menu_stage.gd` y `scenes/lesson_stage.gd`; no eran escenas `.tscn` independientes.

## Recuperar o reutilizar

1. Descomprime `proyecto-menu-antiguo.zip` en una carpeta independiente fuera del juego activo.
2. Abre su `project.godot` con Godot 4.7.2 y deja que reimporte los recursos. No necesita la caché `.godot` original.
3. Para ver el principal antiguo, ejecuta el proyecto con `-- --menu=story`; para otras pantallas usa `--menu=generative`, `--menu=challenges`, `--menu=settings` o `--menu=input`.
4. Para reutilizar un diorama, llama a `MenuStage.make(tipo)` en esa copia: story, generative, dojo, players:1..4, seat:1..4, guards:easy/medium/hard, museum:small/medium/large, theme:ID y lesson:ID. Las dependencias gráficas están incluidas.

`manifest.json` registra la revisión Git y el SHA-256 de cada fichero incluido. Se comprobó la integridad CRC de todo el ZIP. La copia no incluye cachés, aplicaciones exportadas ni entornos Python; incluye el código del cerebro, cuyas dependencias se instalan aparte si se quiere usar el servicio.

Esta carpeta está excluida del escaneo de Godot mediante `.gdignore`, para que sus clases y recursos históricos no se carguen en el juego migrado.

## Biblioteca de escenas

El ZIP incluye `library/` con 37 escenas `.tscn` listas para abrir y ejecutar con F6: todos los dioramas de modos, jugadores, asientos, dificultades, tamaños y temas, además de las lecciones. `library/README.md` contiene el catálogo completo.
