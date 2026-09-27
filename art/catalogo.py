"""El catálogo de piezas en Blender: qué hay en cada .blend de art/ y cómo sale al juego.

Hay dos clases de fichero (lo dicen las propiedades de su escena):
  piezas     varias piezas, cada una en su colección, en fila y con su nombre
             escrito en el suelo. Cada colección sale a
             assets/models/<salida>/<colección>.glb, con la pieza de vuelta en el
             origen (la colección guarda dónde está en la fila: instance_offset).
             Las colecciones que empiezan por "_" (etiquetas, apuntes) no salen.
  personaje  un personaje con esqueleto y acciones: sale entero a
             assets/models/<nombre del fichero>.glb, aligerado para el juego.

Convenciones de las piezas: 1 unidad = una casilla, el pie en z = 0, el frente
mirando a -Y (el +Z de Godot). Los materiales guardan su color base; Godot les
pone el sombreado toon (MuseumView.asset). Nombres de objeto que el juego busca:
  vitrina:  "glass" (transparente, sin sombra)
  panel:    "board" (la lámina, que el juego pinta por panel)
  armadura: una pieza por objeto (stand, leg_l, leg_r, torso, arm_l, arm_r,
            helm, lance): al caer, cada una es un cuerpo aparte.
Blender añade ".001" a un nombre repetido en el mismo fichero; al exportar se
le quita (a objetos y materiales), así que dos piezas pueden tener cada una su
"base" o su "oro".

Una colección con la propiedad "sitio" ("case", "plinth", "floor" o "botin":
la pieza a robar, que flota sobre su vitrina) avisa al exportar si la pieza
no cabe en su sitio (FITS).
"""
import os
import re
import sys

import bpy
from mathutils import Vector

ART = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.normpath(os.path.join(ART, "..", "assets", "models"))

## Tamaño máximo de cada sitio: [ancho, fondo, alto].
FITS = {"case": (0.6, 0.6, 0.34), "plinth": (0.5, 0.5, 0.5), "floor": (0.8, 0.8, 1.1), "botin": (0.5, 0.5, 0.5)}
## Hueco entre piezas en la fila, y la etiqueta: delante (más aún si la pieza
## es honda), tumbada en el suelo.
GAP = 0.6
LABEL_Y = -0.7
LABEL_SIZE = 0.12
LABELS = "_etiquetas"


# --- Qué es cada fichero -----------------------------------------------------

def mark(kind, out=""):
    """Marca el fichero abierto: "piezas" (con su carpeta de salida bajo
    assets/models, "" para la raíz) o "personaje"."""
    sc = bpy.context.scene
    sc["ladron_tipo"] = kind
    sc["ladron_salida"] = out


def kind():
    return bpy.context.scene.get("ladron_tipo", "")


def pieces():
    """Las colecciones que salen al juego, en el orden de la fila."""
    return [c for c in bpy.context.scene.collection.children if not c.name.startswith("_")]


def piece_of(obj):
    """La pieza (colección) a la que pertenece un objeto, o None."""
    for c in pieces():
        if obj.name in c.all_objects:
            return c
    return None


def names():
    """Lo que sale de este fichero: las piezas o el personaje."""
    if kind() == "personaje":
        return [os.path.splitext(os.path.basename(bpy.data.filepath))[0]]
    return [c.name for c in pieces()]


def target(name):
    """El .glb de una pieza de este fichero."""
    if kind() == "personaje":
        return os.path.join(MODELS, name + ".glb")
    return os.path.join(MODELS, bpy.context.scene.get("ladron_salida", ""), name + ".glb")


# --- La fila -----------------------------------------------------------------

def _roots(coll):
    return [o for o in coll.all_objects if o.parent is None or o.parent.name not in coll.all_objects]


def bounds(objs):
    """La caja de las mallas, en el mundo: (mínimo, máximo), o None."""
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    found = False
    for o in objs:
        if o.type != "MESH":
            continue
        found = True
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return (lo, hi) if found else None


def arrange():
    """Pone las piezas en fila a lo largo de X, en su orden, con su nombre
    escrito delante. Cada colección recuerda su sitio en la fila
    (instance_offset), que es lo que se le quita al exportar."""
    labels = bpy.data.collections.get(LABELS)
    if labels:
        for o in list(labels.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        labels = bpy.data.collections.new(LABELS)
        bpy.context.scene.collection.children.link(labels)
    x = 0.0
    for c in pieces():
        box = bounds(c.all_objects)
        off = Vector(c.instance_offset)
        if box is None:
            lo_x, width, front = 0.0, 1.0, 0.0
        else:
            lo_x, width, front = box[0].x - off.x, box[1].x - box[0].x, box[0].y - off.y
        new = Vector((x - lo_x, 0.0, 0.0))
        for o in _roots(c):
            o.location += new - off
        c.instance_offset = new
        text = bpy.data.curves.new("etiqueta_" + c.name, "FONT")
        text.body = c.name
        text.size = LABEL_SIZE
        text.align_x = "CENTER"
        label = bpy.data.objects.new("etiqueta_" + c.name, text)
        label.location = (new.x, min(LABEL_Y, front - 0.25), 0.0)
        label.hide_render = True
        labels.objects.link(label)
        x += width + GAP


def add_piece(name):
    """Una colección nueva al final de la fila, lista para modelar en ella."""
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# --- Exportar ----------------------------------------------------------------

def _plain_names(items, pool):
    """Quita el ".001" que Blender pone a los nombres repetidos (de objetos o
    materiales: pool es bpy.data.objects o bpy.data.materials); si el nombre
    limpio lo tiene otra pieza, se lo cede un momento (dentro de la misma
    pieza, el repetido se queda como está)."""
    for o in items:
        base = re.sub(r"\.\d{3}$", "", o.name)
        if base == o.name:
            continue
        other = pool.get(base)
        if other is not None:
            if other in items:
                continue
            other.name = base + "_otra_pieza"
        o.name = base


def check_fit(coll):
    """Avisa si una pieza no cabe en su sitio (la propiedad "sitio")."""
    where = coll.get("sitio")
    box = bounds(coll.all_objects)
    if where not in FITS or box is None:
        return
    off = Vector(coll.instance_offset)
    lo, hi = box[0] - off, box[1] - off
    size = hi - lo
    fx, fy, fz = FITS[where]
    if size.x > fx + 0.02 or size.y > fy + 0.02 or size.z > fz + 0.02 or lo.z < -0.01:
        print(f"[cabe] {coll.name} ({where}) mide {size.x:.2f} × {size.y:.2f} × {size.z:.2f}, suelo {lo.z:.2f}")


def export_piece(name, out=None):
    """Exporta una pieza de un fichero de piezas. Mueve y renombra objetos:
    después hay que volver a abrir el fichero sin guardar (export_file lo hace)."""
    coll = bpy.data.collections[name]
    check_fit(coll)
    objs = list(coll.all_objects)
    _plain_names(objs, bpy.data.objects)
    mats = list({s.material for o in objs for s in o.material_slots if s.material})
    _plain_names(mats, bpy.data.materials)
    off = Vector(coll.instance_offset)
    for o in _roots(coll):
        o.location -= off
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    path = out or target(name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("[export]", _shown(path))


def _shown(path):
    """La ruta desde la raíz del proyecto, si está dentro."""
    root = os.path.normpath(os.path.join(ART, ".."))
    path = os.path.normpath(path)
    return os.path.relpath(path, root) if path.startswith(root + os.sep) else path


def export_character(out=None):
    """Exporta el personaje del fichero: esqueleto, malla aligerada y acciones."""
    sys.path.append(os.path.join(ART, "characters"))
    import rig
    rig.export(out or target(names()[0]))


def export_file(path, wanted=None, out_dir=None):
    """Abre un .blend de art/ y exporta sus piezas (todas, o las de `wanted`);
    out_dir cambia la carpeta de assets/models por otra (para comparar).
    Devuelve los nombres exportados."""
    bpy.ops.wm.open_mainfile(filepath=path)
    if kind() not in ("piezas", "personaje"):
        return []
    done = []
    for name in names():
        stem = os.path.splitext(os.path.basename(path))[0]
        if wanted and name not in wanted and stem not in wanted and stem + ".blend" not in wanted:
            continue
        out = None
        if out_dir:
            sub = "" if kind() == "personaje" else bpy.context.scene.get("ladron_salida", "")
            out = os.path.join(out_dir, sub, name + ".glb")
        if kind() == "personaje":
            export_character(out)
        else:
            export_piece(name, out)
        done.append(name)
        bpy.ops.wm.open_mainfile(filepath=path)
    return done


def blend_files():
    """Los .blend del catálogo (art/ y art/personajes/)."""
    found = []
    for root in (ART, os.path.join(ART, "personajes")):
        if os.path.isdir(root):
            found += sorted(os.path.join(root, f) for f in os.listdir(root) if f.endswith(".blend"))
    return found
