"""Esqueleto y animaciones de los personajes.

Los dos personajes comparten proporciones (las mismas articulaciones en los
mismos sitios), así que comparten esqueleto y animaciones: cadera, columna,
pecho y cabeza; brazo, antebrazo y mano; muslo, espinilla y pie.

Pesos: cada pieza sabe de qué huesos depende (por su nombre). Las rígidas
(cabeza con todo lo suyo, manos, botas, linterna) van enteras a un hueso; las
blandas (torso, brazos, piernas) se reparten entre los huesos de su cadena por
cercanía, así se doblan suaves en codos, rodillas y cintura.

Animaciones (ciclos en el sitio, a 24 fps): reposo, andar, correr y, para el
ninja, gatear. Se guardan como acciones; el exportador de glTF las saca todas.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 24

## (hueso, cabeza, cola, padre). x > 0 es el lado izquierdo del personaje (.L).
BONES = [
    ("raiz", (0, 0, 0), (0, 0.12, 0), None),
    ("cadera", (0, 0, 0.3), (0, 0, 0.4), "raiz"),
    ("columna", (0, 0, 0.4), (0, 0, 0.5), "cadera"),
    ("pecho", (0, 0, 0.5), (0, 0, 0.62), "columna"),
    ("cabeza", (0, 0, 0.62), (0, 0, 1.0), "pecho"),
]
for _sx, _side in ((1, "L"), (-1, "R")):
    BONES += [
        (f"brazo.{_side}", (_sx * 0.2, 0, 0.565), (_sx * 0.29, -0.005, 0.44), "pecho"),
        (f"antebrazo.{_side}", (_sx * 0.29, -0.005, 0.44), (_sx * 0.312, -0.04, 0.33), f"brazo.{_side}"),
        (f"mano.{_side}", (_sx * 0.312, -0.04, 0.33), (_sx * 0.326, -0.07, 0.22), f"antebrazo.{_side}"),
        (f"muslo.{_side}", (_sx * 0.1, 0, 0.34), (_sx * 0.103, -0.005, 0.23), "cadera"),
        (f"espinilla.{_side}", (_sx * 0.103, -0.005, 0.23), (_sx * 0.106, -0.01, 0.12), f"muslo.{_side}"),
        (f"pie.{_side}", (_sx * 0.106, -0.01, 0.12), (_sx * 0.106, -0.15, 0.05), f"espinilla.{_side}"),
    ]


# --- Esqueleto ------------------------------------------------------------------

def armature(name):
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent in BONES:
        b = data.edit_bones.new(bname)
        b.head = head
        b.tail = tail
        b.roll = 0.0
        if parent:
            b.parent = data.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def _segments():
    return {name: (Vector(h), Vector(t)) for name, h, t, _ in BONES}


def _dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def flatten(root):
    """Hornea la transformación de cada malla bajo root en sus vértices y la
    deja suelta, en el origen. Devuelve [(malla, está bajo la cabeza)]."""
    out = []

    def walk(o, under_head):
        under_head = under_head or o.name == "cabeza_raiz"
        for c in list(o.children):
            walk(c, under_head)
        if o.type == "MESH":
            out.append((o, under_head))

    walk(root, False)
    bpy.context.view_layer.update()
    for o, _ in out:
        mw = o.matrix_world.copy()
        o.parent = None
        o.data.transform(mw)
        o.matrix_world = Matrix.Identity(4)
    return out


def skin(root, rules, name):
    """Esqueleto + pesos + una sola malla. rules(nombre, lado) -> [huesos]
    (lado "L" o "R" según dónde cae la pieza); las piezas bajo la cabeza van
    al hueso de la cabeza."""
    arm = armature(f"{name}_esqueleto")
    segs = _segments()
    meshes = flatten(root)
    for o, under_head in meshes:
        centre = sum((v.co for v in o.data.vertices), Vector()) / max(1, len(o.data.vertices))
        side = "L" if centre.x >= 0 else "R"
        bones = ["cabeza"] if under_head else rules(o.name.split(".")[0], side)
        if not bones:
            print("[rig] sin regla:", o.name)
            bones = [b for b, *_ in BONES if b != "raiz"]
        groups = {b: o.vertex_groups.new(name=b) for b in bones}
        for v in o.data.vertices:
            if len(bones) == 1:
                groups[bones[0]].add([v.index], 1.0, "REPLACE")
                continue
            # Reparto por cercanía a cada hueso de la cadena (inverso de la
            # distancia a la cuarta): suave en las uniones, firme lejos.
            ws = {b: 1.0 / (_dist(v.co, *segs[b]) ** 4 + 1e-7) for b in bones}
            total = sum(ws.values())
            for b, w in ws.items():
                if w / total > 0.01:
                    groups[b].add([v.index], w / total, "REPLACE")
    # Una sola malla, colgada del esqueleto.
    objs = [o for o, _ in meshes]
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = f"{name}_malla"
    body.data.name = body.name
    mod = body.modifiers.new("esqueleto", "ARMATURE")
    mod.object = arm
    body.parent = arm
    # Fuera los vacíos que ya no sostienen nada.
    for o in list(bpy.data.objects):
        if o.type == "EMPTY":
            bpy.data.objects.remove(o)
    return arm, body


# --- Poses y animaciones ----------------------------------------------------------

def _rest_rot(arm, bone):
    return arm.data.bones[bone].matrix_local.to_quaternion()


def rot(arm, bone, x=0.0, y=0.0, z=0.0):
    """Gira un hueso en grados alrededor de los ejes del mundo (X: + hacia
    atrás lo que cuelga, - hacia delante; Z: giro sobre sí), medidos en su
    postura de reposo."""
    q = Quaternion((1, 0, 0), math.radians(x)) @ Quaternion((0, 1, 0), math.radians(y)) @ Quaternion((0, 0, 1), math.radians(z))
    r = _rest_rot(arm, bone)
    arm.pose.bones[bone].rotation_quaternion = r.inverted() @ q @ r


def move(arm, bone, dx=0.0, dy=0.0, dz=0.0):
    """Desplaza un hueso en metros, en ejes del mundo."""
    r = _rest_rot(arm, bone)
    arm.pose.bones[bone].location = r.inverted() @ Vector((dx, dy, dz))


def _clear(arm):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


def action(arm, name, frames, pose_at, step=1):
    """Una acción cíclica de frames fotogramas: pose_at(arm, fase 0..1) pone
    la pose; se guarda cada step fotogramas, y el último repite el primero."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in list(range(0, frames, step)) + [frames]:
        _clear(arm)
        pose_at(arm, (f % frames) / frames)
        for pb in arm.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
            pb.keyframe_insert("location", frame=f, group=pb.name)
    act.frame_range = (0, frames)
    return act


def _legs_flat(arm, side, thigh, shin, toe=0.0):
    """Muslo y espinilla, y el pie compensado para seguir plano en el suelo."""
    rot(arm, f"muslo.{side}", x=thigh)
    rot(arm, f"espinilla.{side}", x=shin)
    rot(arm, f"pie.{side}", x=-(thigh + shin) * 0.85 + toe)


def idle(arm, u):
    """Ninja en guardia: rodillas flexionadas, puños arriba, respirando y
    meciéndose un poco de lado a lado."""
    a = 2 * math.pi * u
    breath = math.sin(a * 2)
    sway = math.sin(a)
    move(arm, "cadera", dz=-0.035 - 0.004 * breath, dx=0.008 * sway)
    rot(arm, "cadera", x=6, y=2 * sway)
    rot(arm, "columna", x=4)
    rot(arm, "pecho", x=-2 + 1.5 * breath, y=-2 * sway)
    rot(arm, "cabeza", x=-8 - breath, z=3 * math.sin(a + 0.6))
    for side, s_ in (("L", 1), ("R", -1)):
        # Piernas algo abiertas y flexionadas, pie plano.
        rot(arm, f"muslo.{side}", x=-22, y=s_ * 4)
        rot(arm, f"espinilla.{side}", x=38 + 2 * breath)
        rot(arm, f"pie.{side}", x=-(-22 + 38) * 0.85 - 6)
        # Brazos arriba, codos doblados, puños al frente.
        rot(arm, f"brazo.{side}", x=-12 - 2 * breath, y=s_ * 6)
        rot(arm, f"antebrazo.{side}", x=-35 + 2 * breath)
        rot(arm, f"mano.{side}", x=-10)


def walk(arm, u):
    a = 2 * math.pi * u
    # Dos pasos por ciclo: la cadera baja al apoyar y sube al pasar.
    move(arm, "cadera", dz=-0.018 * (0.5 + 0.5 * math.cos(2 * a)))
    rot(arm, "cadera", z=5 * math.sin(a), y=2 * math.sin(a))
    rot(arm, "pecho", z=-7 * math.sin(a), x=3)
    rot(arm, "cabeza", z=2 * math.sin(a), x=-2)
    for side, ph in (("L", 0.0), ("R", math.pi)):
        p = a + ph
        thigh = -26 * math.sin(p)
        knee = 8 + 42 * max(0.0, math.cos(p)) ** 1.5
        _legs_flat(arm, side, thigh, knee, toe=12 * max(0.0, -math.cos(p)) * max(0.0, math.sin(p)))
        rot(arm, f"brazo.{side}", x=24 * math.sin(p))
        rot(arm, f"antebrazo.{side}", x=-18 - 10 * max(0.0, -math.sin(p)))


def run(arm, u):
    a = 2 * math.pi * u
    move(arm, "cadera", dz=-0.03 * (0.5 + 0.5 * math.cos(2 * a)) + 0.012)
    rot(arm, "cadera", z=7 * math.sin(a))
    rot(arm, "columna", x=8)
    rot(arm, "pecho", x=6, z=-10 * math.sin(a))
    rot(arm, "cabeza", x=-10, z=3 * math.sin(a))
    for side, ph in (("L", 0.0), ("R", math.pi)):
        p = a + ph
        thigh = -48 * math.sin(p) - 8
        knee = 20 + 75 * max(0.0, math.cos(p)) ** 1.2
        _legs_flat(arm, side, thigh, knee, toe=20 * max(0.0, -math.cos(p)))
        rot(arm, f"brazo.{side}", x=42 * math.sin(p))
        rot(arm, f"antebrazo.{side}", x=-75)


def crawl(arm, u):
    """A gatas, al trote: mano izquierda con rodilla derecha. El cuerpo se
    inclina hacia delante desde la cadera; los muslos quedan casi verticales
    y las espinillas tumbadas en el suelo."""
    a = 2 * math.pi * u
    move(arm, "cadera", dz=-0.135 + 0.008 * math.cos(2 * a), dy=0.02)
    rot(arm, "cadera", x=35, z=4 * math.sin(a))
    rot(arm, "columna", x=25)
    rot(arm, "pecho", x=15, z=-5 * math.sin(a))
    rot(arm, "cabeza", x=-72, z=4 * math.sin(a))
    for side, ph in (("L", 0.0), ("R", math.pi)):
        p = a + ph
        # Brazo: hacia el suelo (contra los 75° de inclinación), y avanza.
        lift = max(0.0, math.cos(p))
        rot(arm, f"brazo.{side}", x=-78 - 16 * math.sin(p) - 10 * lift)
        rot(arm, f"antebrazo.{side}", x=8 + 14 * lift)
        rot(arm, f"mano.{side}", x=-20)
    for side, ph in (("L", math.pi), ("R", 0.0)):
        p = a + ph
        lift = max(0.0, math.cos(p))
        rot(arm, f"muslo.{side}", x=-35 - 14 * math.sin(p) - 6 * lift)
        rot(arm, f"espinilla.{side}", x=92 - 10 * lift)
        rot(arm, f"pie.{side}", x=88)


# --- El guardia: más sobrio ------------------------------------------------------
#
# Erguido, poco vaivén de cadera, pasos firmes. La mano izquierda (.L, x > 0)
# lleva la linterna: ese brazo apenas se mueve y la mantiene al frente; el
# otro braceo corto.

TORCH = "L"
FREE = "R"


def _torch_arm(arm, a, amount, raise_=0.0):
    """El brazo de la linterna. raise_ (grados) lo adelanta para apuntar al
    frente; la mano compensa para que el haz vaya recto y un poco abajo."""
    up = raise_ + amount * math.sin(a * 2)
    fore = -14 - raise_ * 0.3
    rot(arm, f"brazo.{TORCH}", x=-6 - up)
    rot(arm, f"antebrazo.{TORCH}", x=fore)
    if raise_:
        rot(arm, f"mano.{TORCH}", x=6 + up - fore - 14 - 8)


def guard_idle(arm, u):
    a = 2 * math.pi * u
    move(arm, "cadera", dz=-0.003 * (1 - math.cos(a)))
    rot(arm, "pecho", x=-1 + 1.2 * math.sin(a))
    rot(arm, "cabeza", z=4 * math.sin(a * 0.5))
    _torch_arm(arm, a, 0.5)
    rot(arm, f"brazo.{FREE}", x=-2)
    rot(arm, f"antebrazo.{FREE}", x=-8)


def guard_walk(arm, u):
    a = 2 * math.pi * u
    move(arm, "cadera", dz=-0.012 * (0.5 + 0.5 * math.cos(2 * a)))
    rot(arm, "cadera", z=3 * math.sin(a))
    rot(arm, "pecho", z=-3 * math.sin(a), x=-1)
    rot(arm, "cabeza", z=1.5 * math.sin(a))
    for side, ph in (("L", 0.0), ("R", math.pi)):
        p = a + ph
        thigh = -22 * math.sin(p)
        knee = 6 + 34 * max(0.0, math.cos(p)) ** 1.5
        _legs_flat(arm, side, thigh, knee, toe=8 * max(0.0, -math.cos(p)) * max(0.0, math.sin(p)))
    # Sólo braceo el brazo libre, y corto; va con la pierna contraria.
    rot(arm, f"brazo.{FREE}", x=-14 * math.sin(a))
    rot(arm, f"antebrazo.{FREE}", x=-12 - 6 * max(0.0, math.sin(a)))
    # La linterna al frente, alumbrando por dónde va.
    _torch_arm(arm, a, 2.0, raise_=55)


def guard_run(arm, u):
    a = 2 * math.pi * u
    move(arm, "cadera", dz=-0.022 * (0.5 + 0.5 * math.cos(2 * a)) + 0.008)
    rot(arm, "cadera", z=4 * math.sin(a))
    rot(arm, "columna", x=4)
    rot(arm, "pecho", x=3, z=-5 * math.sin(a))
    rot(arm, "cabeza", x=-5, z=2 * math.sin(a))
    for side, ph in (("L", 0.0), ("R", math.pi)):
        p = a + ph
        thigh = -38 * math.sin(p) - 5
        knee = 14 + 60 * max(0.0, math.cos(p)) ** 1.2
        _legs_flat(arm, side, thigh, knee, toe=14 * max(0.0, -math.cos(p)))
    rot(arm, f"brazo.{FREE}", x=-26 * math.sin(a))
    rot(arm, f"antebrazo.{FREE}", x=-60)
    # La linterna al frente, firme mientras corre.
    _torch_arm(arm, a, 3.0, raise_=62)


ANIMATIONS = {
    "reposo": (48, idle),
    "andar": (24, walk),
    "correr": (16, run),
    "gatear": (28, crawl),
}

GUARD_ANIMATIONS = {
    "reposo": (48, guard_idle),
    "andar": (36, guard_walk),
    "correr": (18, guard_run),
}


def animate(arm, names, table=None):
    table = table or ANIMATIONS
    bpy.context.scene.render.fps = FPS
    acts = [action(arm, n, *table[n]) for n in names]
    # Queda puesta la de reposo.
    arm.animation_data.action = acts[0]
    return acts


# --- Revisión ----------------------------------------------------------------------

def preview(arm, prefix, names, frames=8):
    """Renders de perfil (y tres cuartos) de cada animación, fotograma a
    fotograma, para revisarlas sin abrir Blender: prefix_<anim>_<n>.png."""
    import sheet
    cam = sheet.stage()
    sc = bpy.context.scene
    sc.render.resolution_x = 480
    sc.render.resolution_y = 420
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.5
    # Un suelo, para ver si apoya.
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    floor = bpy.context.active_object
    m = bpy.data.materials.new("suelo")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.6, 0.75, 1)
    floor.data.materials.append(m)
    for name in names:
        act = bpy.data.actions[name]
        arm.animation_data.action = act
        length = int(act.frame_range[1])
        for view, loc in (("lado", (6, -0.12, 0.5)), ("tres", (4.2, -4.4, 1.9))):
            cam.location = loc
            cam.rotation_euler = (Vector((0, -0.12, 0.45)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            for i in range(frames):
                sc.frame_set(round(i * length / frames))
                sc.render.filepath = f"{prefix}_{name}_{view}_{i}.png"
                bpy.ops.render.render(write_still=True)


## Para el juego basta con una fracción de los triángulos del render.
GAME_DETAIL = 0.22


def export(path):
    """A glTF con el esqueleto, la malla con pesos (aligerada para el juego)
    y todas las acciones."""
    for o in bpy.data.objects:
        if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers):
            d = o.modifiers.new("aligerar", "DECIMATE")
            d.ratio = GAME_DETAIL
            d.use_collapse_triangulate = True
            # Antes que el esqueleto.
            o.modifiers.move(o.modifiers.find(d.name), 0)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=True)
    print("[export]", path)
