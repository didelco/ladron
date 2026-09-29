# Ninja Karma (Ladrón)

## Capturas: solo cuando hacen falta

Hacer capturas cuesta tiempo (y a cada agente, su rato). No se sacan en cada cambio.

- **Para comprobar el propio trabajo**, renderizar y mirar lo que haga falta, pero sin guardar series de capturas ni enseñarlas.
- **Capturas para el usuario** (p. ej. en el Escritorio): solo si las pide, en un test A/B, o al cerrar un cambio visual grande (un edificio nuevo, una pantalla nueva). Una o dos que lo enseñen, no series de cinco o seis por encargo.
- **Capturas de la documentación** (`docs/capturas`, `python3 tools/docs.py build shots`): en lote, no por cambio. Se rehacen al cerrar un bloque de trabajo (al final de la sesión o del día) o cuando el usuario lo pida, todas de una vez.
- **Hitos** (`python3 tools/docs.py version …`): uno por pantalla y por bloque de trabajo, al rehacer las capturas de la documentación; no uno por cada iteración. Antes de rehacer una pantalla que va a cambiar mucho, sí se guarda su versión anterior (con `--commit` o `--from` una imagen sacada del juego), porque luego ya no se puede.
- Al encargar trabajo a un agente, no pedirle capturas de documentación ni hitos salvo que sea el cierre de un bloque.

Al sacar capturas con Godot, lanzarlo con `SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004 SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004`: algunos Mac tienen un HID de Apple que Godot toma por un mando y pulsa solo. Solo para tests y capturas: al lanzar el juego para que lo juegue el usuario, sin esas variables, o su mando no se detecta (en macOS ese id es el del mando de verdad).
