"""Un chat con Claude dentro de Blender, a través de Claude Code (tu suscripción, sin clave de API).

Se instala una vez (Preferencias → Add-ons → Instalar desde disco… → este fichero) y
aparece en la barra lateral del visor 3D (tecla N), pestaña «Claude»:

  - Escribe y pulsa Enter (o «Enviar»). Con cada mensaje va un resumen de la escena:
    el fichero, lo seleccionado (medidas, sitio, materiales) y las colecciones; y, si
    está marcado «Mandar captura», una imagen del visor.
  - Claude contesta; si hace falta cambiar la escena, con código de Blender (Python)
    que se ejecuta aquí, de una vez: Ctrl+Z (o «Deshacer») lo quita entero. Antes de
    cada cambio se guarda una copia del fichero en la carpeta temporal.
  - Si el código falla, «Pedir arreglo» le manda el error. «Revisar antes de ejecutar»
    (en las preferencias del add-on) deja el código pendiente en vez de ejecutarlo;
    se puede leer en el editor de texto («Claude: código»).
  - «Nueva» empieza otra conversación; la de ahora sigue en Claude Code.

Por debajo llama a `claude -p` sin herramientas (salvo leer la captura), sin servidores
MCP ni ajustes del usuario, para que cada mensaje sea rápido y gaste poco.
"""
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import threading
import time
import traceback

import bpy
import mathutils

bl_info = {
    "name": "Claude: chat en Blender",
    "author": "Chema",
    "version": (1, 0),
    "blender": (4, 2, 0),
    "location": "Visor 3D → barra lateral (N) → Claude",
    "description": "Habla con Claude (vía Claude Code) y deja que cambie la escena",
    "category": "3D View",
}

WORK = os.path.join(tempfile.gettempdir(), "claude_blender")
CODE_TEXT = "Claude: código"
LOG_TEXT = "Claude: conversación"

SYSTEM = """Eres Claude, dentro de Blender {version}, ayudando a modelar. El usuario escribe en un
panel de Blender; con cada mensaje te llega un resumen de la escena entre <escena> y </escena>.

Cómo responder:
- En español, breve: una o dos frases sobre lo que haces o la respuesta a la pregunta.
- Si hay que cambiar la escena, pon UN solo bloque ```python con el código, que se ejecuta
  tal cual dentro de Blender, en el visor 3D, como un único paso que el usuario puede deshacer.
  Ya están importados bpy, bmesh, math, mathutils y Vector; C es bpy.context y D es bpy.data.
- Si solo es una pregunta, no pongas código.
- Prefiere bpy.data y bmesh a bpy.ops. Busca los objetos por nombre, no por posición.
  Deja el modo en OBJECT al acabar. No guardes, abras ni cierres ficheros, ni salgas de
  Blender, ni toques nada fuera del fichero abierto.
- Si te llega un error de tu código, corrígelo con otro bloque completo.
- Si te dicen que hay una captura del visor, léela (Read) antes de contestar.

Unidades: 1 = 1 metro; Z hacia arriba. En el juego Ladrón (escena con la propiedad
"ladron_tipo" = "piezas"): cada pieza es una colección, puestas en fila; el origen de una pieza
es el instance_offset de su colección, con el pie en z = 0 y el frente mirando a -Y. Lo nuevo de
una pieza va dentro de su colección, y no se mueve una pieza de su sitio en la fila salvo que lo
pidan. Materiales sencillos (Principled BSDF con su color base: el juego pone el sombreado).
"""

# El estado del chat (no se guarda en el .blend).
_history = []   # [(quién, texto)]: "tú", "claude", "error", "info"
_state = {"session": None, "busy": False, "started": 0.0, "proc": None, "reply": None,
          "code": None, "error": None, "cost": 0.0}


# --- Claude Code --------------------------------------------------------------

def _find_claude():
    for p in (os.path.expanduser("~/.local/bin/claude"), "/opt/homebrew/bin/claude", "/usr/local/bin/claude",
              shutil.which("claude") or ""):
        if p and os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return ""


class ClaudePrefs(bpy.types.AddonPreferences):
    bl_idname = __name__

    claude: bpy.props.StringProperty(name="claude", subtype="FILE_PATH", default=_find_claude(),
                                     description="El ejecutable de Claude Code")
    model: bpy.props.StringProperty(name="Modelo", default="",
                                    description="Vacío: el de tu Claude Code (p. ej. sonnet, opus)")
    review: bpy.props.BoolProperty(name="Revisar antes de ejecutar", default=False,
                                   description="Deja el código pendiente en vez de ejecutarlo al llegar")

    def draw(self, context):
        col = self.layout.column()
        col.prop(self, "claude")
        col.prop(self, "model")
        col.prop(self, "review")


def _prefs():
    return bpy.context.preferences.addons[__name__].preferences


def _scene_summary(context):
    """Lo que Claude necesita saber de la escena, en pocas líneas."""
    sc = context.scene
    out = [f"Fichero: {bpy.data.filepath or '(sin guardar)'}", f"Modo: {context.mode}"]
    if sc.get("ladron_tipo"):
        out.append(f"Ladrón: fichero de {sc['ladron_tipo']}, sale a assets/models/{sc.get('ladron_salida', '')}")
    cols = [c for c in sc.collection.children]
    if cols:
        out.append("Colecciones: " + ", ".join(
            f"{c.name} ({len(c.all_objects)} obj, origen {tuple(round(v, 2) for v in c.instance_offset)})"
            for c in cols[:40]) + (" …" if len(cols) > 40 else ""))
    out.append(f"Objetos en la escena: {len(sc.objects)}")
    active = context.active_object
    sel = list(context.selected_objects)
    if active and active not in sel:
        sel.insert(0, active)
    if sel:
        out.append("Seleccionado" + (" (el activo primero)" if active else "") + ":")
        for o in sel[:20]:
            mats = [s.material.name for s in o.material_slots if s.material][:6]
            colls = [c.name for c in o.users_collection]
            out.append(f"  {o.name} ({o.type}) en {colls}, sitio {tuple(round(v, 3) for v in o.location)}, "
                       f"giro {tuple(round(math.degrees(v), 1) for v in o.rotation_euler)}°, "
                       f"medidas {tuple(round(v, 3) for v in o.dimensions)}"
                       + (f", materiales {mats}" if mats else "")
                       + (f", padre {o.parent.name}" if o.parent else ""))
        if len(sel) > 20:
            out.append(f"  … y {len(sel) - 20} más")
    else:
        out.append("Nada seleccionado.")
    return "\n".join(out)


def _view3d():
    """(ventana, área, región) de un visor 3D, para ejecutar como si fuera en él."""
    wm = bpy.context.window_manager
    for win in wm.windows:
        for area in win.screen.areas:
            if area.type == "VIEW_3D":
                for region in area.regions:
                    if region.type == "WINDOW":
                        return win, area, region
    return None


def _capture():
    """Una captura del visor 3D, o None."""
    where = _view3d()
    if not where:
        return None
    win, area, region = where
    path = os.path.join(WORK, f"visor_{int(time.time())}.png")
    try:
        with bpy.context.temp_override(window=win, area=area, region=region):
            bpy.ops.screen.screenshot_area(filepath=path)
    except Exception:
        return None
    return path if os.path.exists(path) else None


def _ask(prompt):
    """Manda un mensaje a Claude Code en otro hilo; _poll recoge la respuesta."""
    prefs = _prefs()
    claude = bpy.path.abspath(prefs.claude) or _find_claude()
    if not claude or not os.path.exists(claude):
        _say("error", "No encuentro Claude Code: pon su ruta en las preferencias del add-on.")
        return
    cmd = [claude, "-p", "--output-format", "json", "--tools", "Read", "--strict-mcp-config",
           "--setting-sources", "", "--system-prompt", SYSTEM.format(version=bpy.app.version_string)]
    if prefs.model:
        cmd += ["--model", prefs.model]
    if _state["session"]:
        cmd += ["--resume", _state["session"]]
    cmd += ["--", prompt]
    _state.update(busy=True, started=time.time(), reply=None)

    def run():
        try:
            proc = subprocess.Popen(cmd, cwd=WORK, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, text=True)
            _state["proc"] = proc
            out, err = proc.communicate()
            _state["reply"] = (proc.returncode, out, err)
        except Exception as e:
            _state["reply"] = (-1, "", str(e))

    threading.Thread(target=run, daemon=True).start()
    if not bpy.app.timers.is_registered(_poll):
        bpy.app.timers.register(_poll, first_interval=0.3)


def _poll():
    """Cada poco, en el hilo de Blender: ¿ha contestado ya?"""
    _redraw()
    if _state["reply"] is None:
        return 0.3 if _state["busy"] else None
    code, out, err = _state["reply"]
    _state.update(busy=False, reply=None, proc=None)
    try:
        data = json.loads(out)
    except Exception:
        _say("error", (err or out or f"Claude Code terminó con código {code}").strip()[-600:])
        return None
    if data.get("session_id"):
        _state["session"] = data["session_id"]
    _state["cost"] += data.get("total_cost_usd") or 0.0
    text = data.get("result") or ""
    if data.get("is_error"):
        _say("error", text or "Claude Code devolvió un error")
        return None
    blocks = re.findall(r"```(?:python|py)?\s*\n(.*?)```", text, re.S)
    words = re.sub(r"```(?:python|py)?\s*\n.*?```", "", text, flags=re.S).strip()
    _say("claude", words or "(solo código)")
    if blocks:
        code_text = blocks[-1].rstrip() + "\n"
        _state["code"] = code_text
        t = bpy.data.texts.get(CODE_TEXT) or bpy.data.texts.new(CODE_TEXT)
        t.from_string(code_text)
        if not _prefs().review:
            _run_code()
    _redraw()
    return None


# --- Ejecutar lo que manda -----------------------------------------------------

def _backup():
    if not bpy.data.filepath:
        return
    name = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
    try:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, f"{name}_antes_de_claude.blend"),
                                    copy=True, check_existing=False)
    except Exception:
        pass


def _run_code():
    code = _state["code"]
    if not code:
        return
    _state["code"] = None
    _backup()
    env = {"bpy": bpy, "bmesh": __import__("bmesh"), "math": math, "mathutils": mathutils,
           "Vector": mathutils.Vector, "C": bpy.context, "D": bpy.data}
    where = _view3d()
    try:
        if where:
            win, area, region = where
            with bpy.context.temp_override(window=win, area=area, region=region):
                bpy.ops.ed.undo_push(message="Antes de Claude")
                env["C"] = bpy.context
                exec(compile(code, "<claude>", "exec"), env)
                if bpy.context.mode != "OBJECT" and bpy.ops.object.mode_set.poll():
                    bpy.ops.object.mode_set(mode="OBJECT")
                bpy.ops.ed.undo_push(message="Claude")
        else:
            exec(compile(code, "<claude>", "exec"), env)
        _state["error"] = None
        _say("info", f"Hecho ({len(code.splitlines())} líneas). Ctrl+Z para deshacer.")
    except Exception:
        tb = traceback.format_exc()
        lines = [l for l in tb.strip().splitlines() if "<claude>" in l or not l.startswith("  File")]
        _state["error"] = tb[-1500:]
        _say("error", "\n".join(lines[-4:]))
    _redraw()


def _say(who, text):
    _history.append((who, text))
    log = bpy.data.texts.get(LOG_TEXT) or bpy.data.texts.new(LOG_TEXT)
    log.write(f"\n[{who}]\n{text}\n")


def _redraw():
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()


def _send(context, text):
    text = text.strip()
    if not text or _state["busy"]:
        return
    os.makedirs(WORK, exist_ok=True)
    _say("tú", text)
    prompt = f"{text}\n\n<escena>\n{_scene_summary(context)}\n</escena>"
    if context.window_manager.claude_capture:
        path = _capture()
        if path:
            prompt += f"\n\nCaptura del visor 3D: {path}"
    _ask(prompt)


def _on_enter(self, context):
    """Enter en la caja de texto: se manda y la caja se vacía."""
    text = self.claude_input
    if text.strip() and not _state["busy"]:
        self["claude_input"] = ""
        _send(context, text)


# --- Operadores y panel --------------------------------------------------------

class CLAUDE_OT_send(bpy.types.Operator):
    """Manda el mensaje a Claude"""
    bl_idname = "claude.send"
    bl_label = "Enviar"

    def execute(self, context):
        wm = context.window_manager
        text = wm.claude_input
        wm["claude_input"] = ""
        _send(context, text)
        return {"FINISHED"}


class CLAUDE_OT_run(bpy.types.Operator):
    """Ejecuta el código pendiente de Claude"""
    bl_idname = "claude.run"
    bl_label = "Ejecutar"

    def execute(self, context):
        _run_code()
        return {"FINISHED"}


class CLAUDE_OT_discard(bpy.types.Operator):
    """Descarta el código pendiente"""
    bl_idname = "claude.discard"
    bl_label = "Descartar"

    def execute(self, context):
        _state["code"] = None
        _say("info", "Código descartado.")
        return {"FINISHED"}


class CLAUDE_OT_fix(bpy.types.Operator):
    """Le manda a Claude el error de su código para que lo corrija"""
    bl_idname = "claude.fix"
    bl_label = "Pedir arreglo"

    def execute(self, context):
        err = _state["error"]
        _state["error"] = None
        if err:
            _send(context, "Tu código ha dado este error; corrígelo:\n" + err)
        return {"FINISHED"}


class CLAUDE_OT_stop(bpy.types.Operator):
    """Deja de esperar la respuesta"""
    bl_idname = "claude.stop"
    bl_label = "Parar"

    def execute(self, context):
        proc = _state["proc"]
        if proc and proc.poll() is None:
            proc.kill()
        _state.update(busy=False, reply=None, proc=None)
        _say("info", "Parado.")
        return {"FINISHED"}


class CLAUDE_OT_new(bpy.types.Operator):
    """Empieza otra conversación"""
    bl_idname = "claude.new"
    bl_label = "Nueva"

    def execute(self, context):
        _history.clear()
        _state.update(session=None, code=None, error=None, cost=0.0)
        log = bpy.data.texts.get(LOG_TEXT)
        if log:
            log.clear()
        return {"FINISHED"}


class CLAUDE_OT_undo(bpy.types.Operator):
    """Deshace el último cambio (como Ctrl+Z)"""
    bl_idname = "claude.undo"
    bl_label = "Deshacer"

    def execute(self, context):
        bpy.ops.ed.undo()
        return {"FINISHED"}


WHO = {"tú": ("Tú", "USER"), "claude": ("Claude", "LIGHT"), "error": ("Error", "ERROR"), "info": ("", "INFO")}


class CLAUDE_PT_chat(bpy.types.Panel):
    bl_label = "Claude"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Claude"

    def draw(self, context):
        layout = self.layout
        wm = context.window_manager
        # Caracteres por línea: el ancho de la barra menos el icono y los márgenes,
        # a unos 7,5 puntos por letra.
        f = context.preferences.system.ui_scale
        width = max(16, int((context.region.width - 60 * f) / (7.5 * f)))
        box = layout.box()
        col = box.column(align=True)
        if not _history:
            col.label(text="Pregunta o pide un cambio:", icon="INFO")
            col.label(text="«haz la base más ancha», «¿qué mide esto?»")
        # Los últimos mensajes que caben (unas 40 líneas), del más viejo al más nuevo.
        blocks = []
        shown = 0
        for who, text in reversed(_history):
            name, icon = WHO[who]
            lines = []
            for para in text.splitlines() or [""]:
                lines += textwrap.wrap(para, width) or [""]
            block = [(line, icon if i == 0 else "BLANK1") for i, line in enumerate(lines[:14])]
            if len(lines) > 14:
                block.append(("… (entera en el editor de texto)", "BLANK1"))
            if name:
                block[0] = (f"{name}: {block[0][0]}", block[0][1])
            shown += len(block)
            if blocks and shown > 40:
                break
            blocks.append(block)
        for block in reversed(blocks):
            sub = col.column(align=True)
            sub.scale_y = 0.8
            for line, ic in block:
                sub.label(text=line, icon=ic)
            col.separator()
        if _state["busy"]:
            row = layout.row()
            row.label(text=f"Pensando… {int(time.time() - _state['started'])} s", icon="SORTTIME")
            row.operator("claude.stop", text="", icon="CANCEL")
        if _state["code"]:
            row = layout.row(align=True)
            row.label(text="Código pendiente", icon="SCRIPT")
            row.operator("claude.run", icon="PLAY")
            row.operator("claude.discard", text="", icon="X")
        if _state["error"]:
            layout.operator("claude.fix", icon="TOOL_SETTINGS")
        col = layout.column(align=True)
        col.enabled = not _state["busy"]
        col.prop(wm, "claude_input", text="", icon="GREASEPENCIL")
        row = col.row(align=True)
        row.operator("claude.send", icon="PLAY")
        row.operator("claude.undo", text="", icon="LOOP_BACK")
        row.operator("claude.new", text="", icon="FILE_NEW")
        layout.prop(wm, "claude_capture")
        if _state["cost"]:
            layout.label(text=f"Esta conversación: {_state['cost']:.3f} $ (de tu suscripción)")


CLASSES = (ClaudePrefs, CLAUDE_OT_send, CLAUDE_OT_run, CLAUDE_OT_discard, CLAUDE_OT_fix, CLAUDE_OT_stop,
           CLAUDE_OT_new, CLAUDE_OT_undo, CLAUDE_PT_chat)


def register():
    for c in CLASSES:
        bpy.utils.register_class(c)
    bpy.types.WindowManager.claude_input = bpy.props.StringProperty(
        name="Mensaje", description="Escribe y pulsa Enter", update=_on_enter)
    bpy.types.WindowManager.claude_capture = bpy.props.BoolProperty(
        name="Mandar captura del visor", description="Con cada mensaje, una imagen del visor 3D", default=False)


def unregister():
    if bpy.app.timers.is_registered(_poll):
        bpy.app.timers.unregister(_poll)
    del bpy.types.WindowManager.claude_input
    del bpy.types.WindowManager.claude_capture
    for c in reversed(CLASSES):
        bpy.utils.unregister_class(c)
