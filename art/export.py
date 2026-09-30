"""Exporta el catálogo (art/*.blend y art/personajes/*.blend) a assets/models.

    Blender -b -P art/export.py                        # todo
    Blender -b -P art/export.py -- vitrina anubis      # esas piezas
    Blender -b -P art/export.py -- temas               # un fichero entero (temas, ciudad, museo...)
    Blender -b -P art/export.py -- --godot vitrina     # y que Godot las reimporte
    Blender -b -P art/export.py -- --salida /tmp/x     # a otra carpeta (para comparar)

(Blender es /Applications/Blender.app/Contents/MacOS/Blender.) Desde Blender, el
panel «Ladrón» de la barra lateral (N) hace lo mismo con un botón: art/ladron_addon.py.
Qué hay en cada fichero y las convenciones de las piezas: art/catalogo.py.
"""
import os
import subprocess
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import catalogo  # noqa: E402

GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
godot = "--godot" in args
out_dir = None
if "--salida" in args:
    out_dir = args[args.index("--salida") + 1]
    args.remove(out_dir)
wanted = [a for a in args if not a.startswith("--")]

done = []
for path in catalogo.blend_files():
    done += catalogo.export_file(path, wanted, out_dir)
missing = [w for w in wanted if w not in done and not any(
    os.path.splitext(os.path.basename(p))[0] == w.removesuffix(".blend") for p in catalogo.blend_files())]
if missing:
    print("[export] no encontradas:", ", ".join(missing))
print(f"[export] {len(done)} piezas")
if godot and done and os.path.exists(GODOT):
    subprocess.run([GODOT, "--headless", "--import", "--path", os.path.join(catalogo.ART, "..")],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("[export] Godot ha reimportado")
