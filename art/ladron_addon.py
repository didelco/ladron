"""Panel «Ladrón» en Blender: exportar piezas al juego sin salir de Blender.

Se instala una vez (Preferencias → Add-ons → Instalar desde disco… → este fichero)
y aparece en la barra lateral del visor 3D (tecla N), pestaña «Ladrón», cuando
el fichero abierto es del catálogo (art/*.blend, art/personajes/*.blend):

  Exportar pieza    la pieza del objeto seleccionado (su colección)
  Exportar fichero  todas las piezas de este fichero
  Exportar todo     el catálogo entero
  Nueva pieza       una colección nueva al final de la fila, para modelar en ella
  Ordenar fila      vuelve a poner las piezas en fila con su nombre delante

Exportar guarda el fichero y llama a art/export.py en otro Blender, en segundo
plano (lo mismo que desde la terminal); después Godot reimporta los modelos si
está marcado y encuentra Godot. Lo que hace cada cosa: art/catalogo.py.
"""
import importlib
import os
import subprocess
import sys

import bpy

bl_info = {
    "name": "Ladrón: catálogo de piezas",
    "author": "Chema",
    "version": (1, 0),
    "blender": (4, 2, 0),
    "location": "Visor 3D → barra lateral (N) → Ladrón",
    "description": "Exporta las piezas del juego Ladrón a assets/models",
    "category": "Import-Export",
}


def _project():
    """La raíz del proyecto (donde está project.godot) del fichero abierto."""
    path = bpy.data.filepath
    d = os.path.dirname(path) if path else ""
    while d and d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "project.godot")):
            return d
        d = os.path.dirname(d)
    return None


def _catalogo():
    """El módulo art/catalogo.py del proyecto abierto, o None."""
    root = _project()
    if root is None:
        return None
    art = os.path.join(root, "art")
    if art not in sys.path:
        sys.path.insert(0, art)
    import catalogo
    if os.path.dirname(os.path.abspath(catalogo.__file__)) != art:
        sys.path.remove(art)
        sys.path.insert(0, art)
        catalogo = importlib.reload(catalogo)
    return catalogo


class LadronPrefs(bpy.types.AddonPreferences):
    bl_idname = __name__

    godot: bpy.props.StringProperty(name="Godot", subtype="FILE_PATH",
                                    default="/Applications/Godot.app/Contents/MacOS/Godot")
    reimport: bpy.props.BoolProperty(name="Reimportar en Godot al exportar", default=True)

    def draw(self, context):
        self.layout.prop(self, "godot")
        self.layout.prop(self, "reimport")


def _prefs():
    return bpy.context.preferences.addons[__name__].preferences


class LADRON_OT_export(bpy.types.Operator):
    """Guarda el fichero y exporta al juego"""
    bl_idname = "ladron.export"
    bl_label = "Exportar"

    what: bpy.props.EnumProperty(items=[("piece", "Pieza", ""), ("file", "Fichero", ""), ("all", "Todo", "")])

    def execute(self, context):
        cat = _catalogo()
        if cat is None or not cat.kind():
            self.report({"ERROR"}, "Este fichero no es del catálogo de Ladrón (art/)")
            return {"CANCELLED"}
        args = []
        if self.what == "piece":
            if cat.kind() == "personaje":
                args = cat.names()
            else:
                coll = cat.piece_of(context.active_object) if context.active_object else None
                if coll is None:
                    self.report({"ERROR"}, "Selecciona un objeto de la pieza")
                    return {"CANCELLED"}
                args = [coll.name]
        elif self.what == "file":
            args = [os.path.splitext(os.path.basename(bpy.data.filepath))[0]]
        prefs = _prefs()
        if prefs.reimport:
            args.append("--godot")
        bpy.ops.wm.save_mainfile()
        env = dict(os.environ, GODOT=bpy.path.abspath(prefs.godot))
        run = subprocess.run([bpy.app.binary_path, "-b", "--factory-startup", "-P",
                              os.path.join(_project(), "art", "export.py"), "--"] + args,
                             capture_output=True, text=True, env=env)
        lines = [l for l in run.stdout.splitlines() if l.startswith("[")]
        for l in lines:
            print(l)
        warnings = [l for l in lines if l.startswith("[cabe]") or "no encontradas" in l]
        done = [l for l in lines if l.startswith("[export]") and l.endswith(".glb")]
        if run.returncode != 0 or not done:
            print(run.stdout[-2000:], run.stderr[-2000:])
            self.report({"ERROR"}, "No se ha exportado nada: mira la consola (Ventana → Consola del sistema)")
            return {"CANCELLED"}
        for w in warnings:
            self.report({"WARNING"}, w)
        self.report({"INFO"}, f"Exportadas {len(done)}: " + ", ".join(
            os.path.splitext(os.path.basename(l))[0] for l in done[:6]) + ("…" if len(done) > 6 else ""))
        return {"FINISHED"}


class LADRON_OT_new_piece(bpy.types.Operator):
    """Una colección nueva al final de la fila, activa para modelar en ella"""
    bl_idname = "ladron.new_piece"
    bl_label = "Nueva pieza"
    bl_options = {"REGISTER", "UNDO"}

    name: bpy.props.StringProperty(name="Nombre", default="pieza_nueva")

    def invoke(self, context, event):
        return context.window_manager.invoke_props_dialog(self)

    def execute(self, context):
        cat = _catalogo()
        if cat is None or cat.kind() != "piezas":
            self.report({"ERROR"}, "Solo en un fichero de piezas del catálogo")
            return {"CANCELLED"}
        if self.name in bpy.data.collections:
            self.report({"ERROR"}, f"Ya hay una pieza «{self.name}»")
            return {"CANCELLED"}
        coll = cat.add_piece(self.name)
        cat.arrange()
        context.scene.cursor.location = coll.instance_offset
        context.view_layer.active_layer_collection = context.view_layer.layer_collection.children[coll.name]
        self.report({"INFO"}, f"Pieza «{self.name}»: lo que crees ahora va dentro; el cursor marca su origen")
        return {"FINISHED"}


class LADRON_OT_arrange(bpy.types.Operator):
    """Pone las piezas en fila, con su nombre delante"""
    bl_idname = "ladron.arrange"
    bl_label = "Ordenar fila"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        cat = _catalogo()
        if cat is None or cat.kind() != "piezas":
            return {"CANCELLED"}
        cat.arrange()
        return {"FINISHED"}


class LADRON_PT_panel(bpy.types.Panel):
    bl_label = "Ladrón"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Ladrón"

    def draw(self, context):
        col = self.layout.column()
        cat = _catalogo()
        if cat is None or not cat.kind():
            col.label(text="No es un fichero del catálogo", icon="INFO")
            col.label(text="(art/*.blend del proyecto)")
            return
        if cat.kind() == "personaje":
            col.label(text=f"Personaje: {cat.names()[0]}", icon="ARMATURE_DATA")
            col.operator("ladron.export", text="Exportar personaje", icon="EXPORT").what = "piece"
        else:
            out = context.scene.get("ladron_salida", "") or "assets/models"
            col.label(text=f"{len(cat.pieces())} piezas → {out}", icon="OUTLINER_COLLECTION")
            obj = context.active_object
            coll = cat.piece_of(obj) if obj else None
            row = col.row()
            row.enabled = coll is not None
            row.operator("ladron.export", text=f"Exportar {coll.name}" if coll else "Exportar pieza",
                         icon="EXPORT").what = "piece"
            col.operator("ladron.export", text="Exportar fichero").what = "file"
        col.operator("ladron.export", text="Exportar todo").what = "all"
        if cat.kind() == "piezas":
            col.separator()
            col.operator("ladron.new_piece", icon="ADD")
            col.operator("ladron.arrange", icon="SEQ_STRIP_DUPLICATE")


CLASSES = (LadronPrefs, LADRON_OT_export, LADRON_OT_new_piece, LADRON_OT_arrange, LADRON_PT_panel)


def register():
    for c in CLASSES:
        bpy.utils.register_class(c)


def unregister():
    for c in reversed(CLASSES):
        bpy.utils.unregister_class(c)
