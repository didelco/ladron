"""Exporta cada art/<nombre>.blend a assets/models/<nombre>.glb.

Tras retocar una pieza en Blender, guarda el .blend y ejecuta:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/export.py            # todas
    /Applications/Blender.app/Contents/MacOS/Blender -b -P art/export.py -- vitrina # solo esas
y abre Godot para que las reimporte (o: godot --headless --import).

Convenciones de las piezas: 1 unidad = una casilla, el pie en z=0, el frente
mirando a -Y (el +Z de Godot). Los materiales guardan su color base; Godot les
pone el sombreado toon (MuseumView.asset). Nombres de objeto que el juego busca:
  vitrina: "glass" (transparente, sin sombra)
  panel:   "board" (la lámina, que el juego pinta por panel)
  armadura: una pieza por objeto (stand, leg_l, leg_r, torso, arm_l, arm_r,
            helm, lance): al caer, cada una es un cuerpo aparte.
"""
import bpy, glob, os, sys

ART = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(ART, "..", "assets", "models")
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

for path in sorted(glob.glob(os.path.join(ART, "*.blend"))):
    name = os.path.splitext(os.path.basename(path))[0]
    if only and name not in only:
        continue
    bpy.ops.wm.open_mainfile(filepath=path)
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"), export_format="GLB",
                              export_apply=True, export_yup=True)
    print("[export]", name)
