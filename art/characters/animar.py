"""Rehace las animaciones de un personaje sobre su .blend por partes.

    Blender -b -P art/characters/animar.py -- ninja             # art/personajes/ninja.blend
    Blender -b -P art/characters/animar.py -- guardia --preview /ruta/prefijo

art/personajes/ninja.blend y guardia.blend son el personaje en piezas sueltas (un
objeto por pieza, cada una con su armature y sus pesos): ahí se edita a mano. Esto
NO toca las piezas: solo borra las acciones y vuelve a escribirlas desde rig.py
(reposo, andar, correr; el ninja también gatear, victoria y estatua). Se usa cuando se
cambia una animación en rig.py. Para sacar el .glb del juego: art/export.py.
"""
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import rig  # noqa: E402

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
name = args[0] if args else ""
if name not in ("ninja", "guardia"):
    sys.exit("uso: Blender -b -P art/characters/animar.py -- ninja|guardia [--preview prefijo]")

path = os.path.join(ART, "personajes", name + ".blend")
bpy.ops.wm.open_mainfile(filepath=path)
arm = bpy.data.objects[name + "_esqueleto"]
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
if name == "guardia":
    rig.animate(arm, ["reposo", "andar", "correr"], rig.GUARD_ANIMATIONS)
else:
    rig.animate(arm, ["reposo", "andar", "correr", "gatear", "victoria", "estatua"])
if "--preview" in args:
    rig.preview(arm, args[args.index("--preview") + 1], ["andar", "correr"])
else:
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print("[animar]", path)
