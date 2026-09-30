"""El ninja v2: un muñeco «de goma» (estilo Stumble Guys) rehecho entero sobre su .blend por piezas.

    Blender -b -P art/characters/ninja_v2.py                         # pisa art/personajes/ninja.blend
    Blender -b -P art/characters/ninja_v2.py -- --salida /tmp/n.blend  # a otro fichero

Abre art/personajes/ninja.blend, borra todas sus mallas y construye las nuevas con el mismo
esqueleto (ninja_esqueleto, de art/characters/rig.py, sin tocar) y las mismas acciones. Siempre
sale lo mismo: se puede repetir tras cambiar una medida de aquí. Luego, al juego:

    Blender -b -P art/export.py -- --godot ninja

Cómo se hace cada pieza
- Las formas orgánicas (el cuerpo, los mitones, los pies, los nudos) se describen como un campo de
  distancia con uniones suaves (numpy), se sacan como superficie (surface nets), se remallan en
  cuadriláteros con QuadriFlow (con simetría x cuando la pieza es simétrica), se subdividen una vez
  y se proyectan sobre la forma exacta. Sin vóxeles a la vista ni facetas.
- Las formas regladas (la cabeza, los ojos, las pupilas, la cinta, el cinturón, la suela, las
  colas) se construyen directamente con su malla de cuadriláteros.
- Simetría: todo lo simétrico sale exacto en x (se empareja cada vértice con su espejo y se
  promedia); lo de un lado (manos, pies, suelas, ojos, pupilas) se modela a la izquierda y la
  derecha es su espejo. Solo el nudo de la cinta y las colas de los nudos son asimétricos.

Piezas (nombre <hueso>_<material>, todas con padre ninja_esqueleto, modificador Armature y pesos):
- pecho_traje: el cuerpo de una pieza (torso de gominola, brazos y piernas gruesos). Pesos suaves:
  cadera/columna/pecho por altura; hombro, codo, cadera y rodilla repartidos a lo largo de cada
  cadena; el final de brazo y pierna va con la mano y el pie (queda dentro del mitón y del pie).
- cabeza_traje: la cabeza, una bola grande que se hunde en el torso sin cuello (rígida, cabeza).
- cabeza_ojo_L/R y cabeza_pupila_L/R: ojos ovalados abombados y pupila grande abajo; la cinta les
  tapa el borde de arriba y les da la mirada de medio párpado.
- cabeza_cinta (la cinta ancha, algo más alta por detrás), cabeza_cinta_nudo y cabeza_cinta_cola_1/2
  (el nudo atrás, a la derecha del ninja, y dos colas anchas al viento). Rígidas, cabeza.
- cadera_cinta (el cinturón ancho), cadera_cinta_nudo y cadera_cinta_cola_L/R (nudo delante y dos
  colas colgando): los pesos del cuerpo donde están; las colas se van yendo con el muslo de su lado.
- mano.L/R_guante: mitón redondo con pulgar y puño vuelto en la muñeca (rígido, mano).
- pie.L/R_traje y pie.L/R_suela: el pie, final redondeado y algo más ancho de la pierna, con el
  pliegue del tobillo; y una suela negra fina (rígidos, pie).

Materiales (el juego viste por nombre, scenes/figure.gd): traje (blanco; el juego lo tiñe del color
del jugador), cinta (negra: cinta, cinturón, nudos y colas), guante (negro), suela (negra), ojo
(blanco) y pupila (negra). Ya no hay cejas ni solapas.

Opción de color (no aplicada): el traje es blanco en el .blend porque el juego lo pinta; para ver
el ninja de un color en Blender basta cambiar TRAJE aquí (p. ej. "#2fb84a") y repetir.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils.kdtree import KDTree

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

# --- Colores (hex sRGB) -------------------------------------------------------------------------
TRAJE = "#f2f2f4"
CINTA = "#141418"
GUANTE = "#101014"
SUELA = "#141418"
OJO = "#ffffff"
PUPILA = "#0d0d12"

# --- Medidas (m; x > 0 es la izquierda del ninja, el frente mira a -y, los pies en z = 0) --------
# Las articulaciones son las del esqueleto (rig.BONES): no se mueven.
HIP, KNEE, ANKLE = (0.1, 0.0, 0.34), (0.103, -0.005, 0.23), (0.106, -0.01, 0.12)
SHOULDER, ELBOW, WRIST, HAND_END = (0.2, 0.0, 0.565), (0.29, -0.005, 0.44), (0.312, -0.04, 0.33), (0.326, -0.07, 0.22)
## Torso: dos elipsoides fundidos (tripa y pecho): (centro, semiejes).
BELLY = ((0.0, 0.004, 0.39), (0.205, 0.165, 0.155))
CHEST = ((0.0, 0.0, 0.54), (0.158, 0.138, 0.125))
TORSO_BLEND = 0.06
## Radios de pierna (cadera, rodilla, tobillo) y de brazo (hombro, codo, muñeca).
LEG_R = (0.09, 0.08, 0.068)
ARM_R = (0.078, 0.068, 0.059)
## Unión suave de las piernas con el torso, y de los brazos solo arriba (en el hombro; más abajo
## brazo y costado quedan separados, sin membrana en la axila).
LEG_BLEND = 0.05
ARM_BLEND, ARM_BLEND_Z = 0.055, (0.49, 0.59)
## Cabeza: elipsoide (centro, semiejes).
HEAD_C, HEAD_R = (0.0, 0.0, 0.85), (0.275, 0.255, 0.26)
## Cinta de la frente: altura del centro delante y detrás, ancho, grosor.
BAND_Z, BAND_BACK_RISE, BAND_W, BAND_T = 0.902, 0.03, 0.088, 0.02
## Ojos (el izquierdo; en la vista de frente): centro (x, z), semiejes, y lo que abomban.
## La cinta les tapa el borde de arriba a los dos (blanco y pupila): mirada de medio párpado.
EYE_C, EYE_AB, EYE_LIFT, EYE_DOME = (0.091, 0.836), (0.085, 0.076), 0.003, 0.006
PUPIL_C, PUPIL_AB = (0.085, 0.842), (0.037, 0.054)
GLINT_C, GLINT_AB = (0.097, 0.832), (0.009, 0.011)
## Cinturón: altura del centro, ancho, grosor; tamaño del nudo; y sus colas (lado, largo, apertura).
BELT_Z, BELT_W, BELT_T = 0.372, 0.078, 0.017
BELT_KNOT_SIZE = (0.046, 0.04, 0.028)
BELT_TAILS = (("L", 1, 0.155, 0.065), ("R", -1, 0.128, 0.055))

# Caras: QuadriFlow deja esto y luego una subdivisión lo multiplica por 4.
QF_FACES = {"cuerpo": 1750, "mano": 230, "pie": 210}
## Los nudos: una esfera de caras cuadradas (6 x KNOT_CUTS² caras, x4 al subdividir).
KNOT_CUTS = 5


# =================================================================================================
# Campos de distancia (numpy): p es (..., 3), devuelven (...)
# =================================================================================================

def _v(a):
    return np.asarray(a, dtype=float)


def norm(a):
    return np.sqrt(np.sum(a * a, axis=-1))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def smin(a, b, k):
    k = np.maximum(k, 1e-9)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def sd_ellipsoid(p, c, r, rot=None):
    """Elipsoide (aproximación de Íñigo Quílez, exacta en la superficie). rot: 3x3 con los ejes
    locales en columnas."""
    q = p - _v(c)
    if rot is not None:
        q = q @ rot
    r = _v(r)
    k0 = norm(q / r)
    k1 = norm(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-12)


def sd_round_cone(p, a, b, r1, r2):
    """Cápsula de a a b que pasa del radio r1 al r2 (Íñigo Quílez)."""
    a, b = _v(a), _v(b)
    ba = b - a
    l2 = ba @ ba
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    xv = pa * l2 - y[..., None] * ba
    x2 = np.sum(xv * xv, axis=-1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d1 = np.sqrt(x2 + z2) * il2 - r2
    d2 = np.sqrt(x2 + y2) * il2 - r1
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))


def sd_rounded_cylinder(p, a, b, ra, rb):
    """Cilindro de a a b, de radio ra, con los cantos redondeados rb."""
    a, b = _v(a), _v(b)
    ba = b - a
    length = np.linalg.norm(ba)
    axis = ba / length
    q = p - (a + b) / 2
    h = q @ axis
    rad = norm(q - h[..., None] * axis)
    dx = rad - ra + rb
    dy = np.abs(h) - length / 2 + rb
    return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2) - rb


def mirror_pt(p):
    return (-p[0], p[1], p[2])


# --- El cuerpo ----------------------------------------------------------------------------------

def sd_torso(p):
    return smin(sd_ellipsoid(p, *BELLY), sd_ellipsoid(p, *CHEST), TORSO_BLEND)


def _side(pt, s):
    return (s * pt[0], pt[1], pt[2])


def sd_leg(p, s):
    h, k, a = _side(HIP, s), _side(KNEE, s), _side(ANKLE, s)
    return smin(sd_round_cone(p, h, k, LEG_R[0], LEG_R[1]), sd_round_cone(p, k, a, LEG_R[1], LEG_R[2]), 0.01)


def sd_arm(p, s):
    sh, el, wr = _v(_side(SHOULDER, s)), _v(_side(ELBOW, s)), _v(_side(WRIST, s))
    fore = (wr - el) / np.linalg.norm(wr - el)
    # El final, dentro del puño del guante, se afina para no asomar por los lados del mitón.
    end = sd_round_cone(p, wr - fore * 0.015, wr + fore * 0.02, ARM_R[2], 0.036)
    arm = smin(sd_round_cone(p, sh, el, ARM_R[0], ARM_R[1]), sd_round_cone(p, el, wr - fore * 0.015, ARM_R[1], ARM_R[2]), 0.01)
    return np.minimum(arm, end)


def body_parts(p):
    return sd_torso(p), sd_arm(p, 1), sd_arm(p, -1), sd_leg(p, 1), sd_leg(p, -1)


def sd_lower_body(p):
    """Torso y piernas (sin brazos): donde se apoya el cinturón."""
    t = sd_torso(p)
    return np.minimum(smin(t, sd_leg(p, 1), LEG_BLEND), smin(t, sd_leg(p, -1), LEG_BLEND))


## La axila: una hoja fina entre el brazo y el costado (de arriba abajo, y de delante atrás) que
## se resta del cuerpo. Sin ella brazo y costado quedan a milímetros en un tramo, y esa rendija
## sale en la malla como una membrana que se estira al levantar el brazo.
ARMPIT_TOP, ARMPIT_BOTTOM, ARMPIT_DEPTH, ARMPIT_GAP = (0.152, -0.004, 0.535), (0.214, -0.004, 0.415), 0.085, 0.006


def sd_armpit(p, s):
    top, bot = _v(_side(ARMPIT_TOP, s)), _v(_side(ARMPIT_BOTTOM, s))
    a1 = (bot - top) / np.linalg.norm(bot - top)
    a2 = _v((0, 1, 0))
    a3 = np.cross(a1, a2)
    rot = np.stack([a1, a2, a3], 1)
    half = np.linalg.norm(bot - top) / 2 + 0.03
    return sd_ellipsoid(p, (top + bot) / 2, (half, ARMPIT_DEPTH, ARMPIT_GAP), rot)


def sd_body(p):
    t, al, ar, ll, lr = body_parts(p)
    ka = ARM_BLEND * smoothstep(ARM_BLEND_Z[0], ARM_BLEND_Z[1], p[..., 2])
    legs = np.minimum(smin(t, ll, LEG_BLEND), smin(t, lr, LEG_BLEND))
    arms = np.minimum(smin(t, al, ka), smin(t, ar, ka))
    body = np.minimum(legs, arms)
    for s in (1, -1):
        body = smax(body, -sd_armpit(p, s), 0.012)
    return body


# --- Cabeza ---------------------------------------------------------------------------------------

def sd_head(p):
    return sd_ellipsoid(p, HEAD_C, HEAD_R)


# --- Mitón (el izquierdo) -------------------------------------------------------------------------

def hand_frame():
    """Ejes de la mano izquierda: u a lo largo (hacia la punta), v hacia delante, w hacia fuera."""
    w0, tip = _v(WRIST), _v(HAND_END)
    u = tip - w0
    u /= np.linalg.norm(u)
    v = _v((0, -1, 0)) - u * (u @ _v((0, -1, 0)))
    v /= np.linalg.norm(v)
    w = np.cross(v, u)
    return w0, u, v, w


def sd_mitten(p):
    w0, u, v, w = hand_frame()

    def at(a, b, c):
        return w0 + u * a + v * b + w * c

    rot = np.stack([u, v, w], 1)
    # El puño vuelto del guante: un aro algo más ancho que la muñeca, con el canto redondo, a lo
    # largo del antebrazo (que entra por él).
    fore = w0 - _v(ELBOW)
    fore /= np.linalg.norm(fore)
    cuff = sd_rounded_cylinder(p, w0 - fore * 0.03, w0 + fore * 0.02, ARM_R[2] + 0.012, 0.015)
    # La mano: una manopla redonda y gorda, algo aplanada de palma a dorso.
    palm = sd_ellipsoid(p, at(0.08, 0.002, 0.004), (0.074, 0.064, 0.055), rot)
    # El pulgar: sale por delante, del lado de la palma, y baja apuntando al frente.
    thumb = sd_round_cone(p, at(0.042, -0.046, -0.012), at(0.09, -0.086, -0.02), 0.027, 0.023)
    return smin(smin(palm, cuff, 0.03), thumb, 0.012)


# --- Pie (el izquierdo) ---------------------------------------------------------------------------

FOOT_X = ANKLE[0]
## La planta del pie queda a esta altura, metida en la suela (que llega al suelo).
FOOT_SOLE = 0.008


def sd_foot_raw(p):
    toe = sd_ellipsoid(p, (FOOT_X + 0.002, -0.088, 0.05), (0.086, 0.1, 0.06))
    heel = sd_ellipsoid(p, (FOOT_X, 0.015, 0.054), (0.076, 0.072, 0.062))
    # El tobillo: un cuello algo más ancho que la pierna, plano arriba con el canto redondo; por
    # ahí entra la pierna, derecha, y queda el pliegue.
    collar = sd_rounded_cylinder(p, (FOOT_X, -0.008, 0.03), (FOOT_X, -0.008, 0.13), LEG_R[2] + 0.013, 0.017)
    return smin(smin(toe, heel, 0.05), collar, 0.04)


def sd_foot(p):
    # Planta plana con el borde redondeado.
    return smax(sd_foot_raw(p), FOOT_SOLE - p[..., 2], 0.006)


# =================================================================================================
# Mallas
# =================================================================================================

def surface_nets(field, origin, cell):
    """Malla de cuadriláteros de la superficie de nivel 0 de field (negativo dentro)."""
    nx, ny, nz = field.shape
    inside = field < 0
    corners = [(i, j, k) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
    c = [inside[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k] for i, j, k in corners]
    active = np.logical_or.reduce(c) & ~np.logical_and.reduce(c)
    idx = -np.ones(active.shape, dtype=np.int64)
    cells = np.argwhere(active)
    idx[active] = np.arange(len(cells))
    acc = np.zeros((len(cells), 3))
    cnt = np.zeros(len(cells))
    ci, cj, ck = cells[:, 0], cells[:, 1], cells[:, 2]
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8)
             if sum(abs(corners[a][t] - corners[b][t]) for t in range(3)) == 1]
    for a, b in edges:
        pa, pb = corners[a], corners[b]
        fa = field[ci + pa[0], cj + pa[1], ck + pa[2]]
        fb = field[ci + pb[0], cj + pb[1], ck + pb[2]]
        cross = (fa < 0) != (fb < 0)
        den = np.where(fa - fb == 0, 1.0, fa - fb)
        t = np.where(cross, fa / den, 0.0)
        pos = np.stack([ci + pa[0] + t * (pb[0] - pa[0]), cj + pa[1] + t * (pb[1] - pa[1]),
                        ck + pa[2] + t * (pb[2] - pa[2])], 1)
        acc += pos * cross[:, None]
        cnt += cross
    verts = origin + (acc / cnt[:, None]) * cell
    quads = []
    for axis in range(3):
        a1, a2 = [a for a in range(3) if a != axis]
        s0 = [slice(None)] * 3
        s1 = [slice(None)] * 3
        s0[axis] = slice(0, -1)
        s1[axis] = slice(1, None)
        f0, f1 = inside[tuple(s0)], inside[tuple(s1)]
        pts = np.argwhere(f0 != f1)
        ok = (pts[:, a1] >= 1) & (pts[:, a2] >= 1) & (pts[:, a1] < field.shape[a1] - 1) & (pts[:, a2] < field.shape[a2] - 1)
        pts = pts[ok]
        flip = f0[tuple(pts.T)]

        def cell_at(d1, d2):
            q = pts.copy()
            q[:, a1] -= d1
            q[:, a2] -= d2
            return idx[tuple(q.T)]

        quad = np.stack([cell_at(1, 1), cell_at(0, 1), cell_at(0, 0), cell_at(1, 0)], 1)
        quad[flip] = quad[flip][:, ::-1]
        quads.append(quad)
    return verts, np.concatenate(quads)


def sample(sdf, lo, hi, cell):
    lo, hi = _v(lo), _v(hi)
    n = np.ceil((hi - lo) / cell).astype(int) + 1
    axes = [lo[i] + cell * np.arange(n[i]) for i in range(3)]
    field = np.empty(n)
    yy, zz = np.meshgrid(axes[1], axes[2], indexing="ij")
    for i, x in enumerate(axes[0]):
        p = np.stack([np.full_like(yy, x), yy, zz], -1)
        field[i] = sdf(p)
    # Un valor exactamente 0 en una esquina deja vértices repetidos (y QuadriFlow los rechaza).
    field[np.abs(field) < 1e-7] = 1e-7
    return surface_nets(field, lo, cell)


def _select_only(obj):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _temp_object(V, F):
    me = bpy.data.meshes.new("_tmp")
    me.from_pydata(np.asarray(V).tolist(), [], [list(f) for f in F])
    me.update()
    obj = bpy.data.objects.new("_tmp", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _read(me):
    V = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", V)
    return V.reshape(-1, 3), [tuple(p.vertices) for p in me.polygons]


def _drop(obj):
    me = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    if me.users == 0:
        bpy.data.meshes.remove(me)


## QuadriFlow no admite aristas de menos de 0,1 mm: se le pasa la pieza cien veces más grande.
QF_SCALE = 100.0


def quadriflow(V, F, faces, symmetric, cell):
    obj = _temp_object(np.asarray(V) * QF_SCALE, F)
    _select_only(obj)
    # Una pasada de vóxeles del tamaño de la rejilla: si dos superficies casi se tocan (la axila)
    # la malla de surface nets puede no ser cerrada, y QuadriFlow la quiere cerrada y orientada.
    rem = obj.modifiers.new("vox", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = cell * QF_SCALE
    rem.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier=rem.name)
    obj.data.use_mirror_x = symmetric
    res = bpy.ops.object.quadriflow_remesh(target_faces=faces, use_mesh_symmetry=symmetric, use_preserve_sharp=False,
                                           use_preserve_boundary=False, smooth_normals=False, seed=0)
    if "FINISHED" not in res:
        raise RuntimeError("QuadriFlow no ha podido")
    if symmetric:
        # Con simetría QuadriFlow deja las dos mitades sin coser en x = 0 (a veces con una tapa
        # plana cada una): fuera las tapas, se cosen los bordes y se tapa lo que quede abierto.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        eps = 1e-4 * QF_SCALE
        for v in bm.verts:
            if abs(v.co.x) < eps:
                v.co.x = 0.0
        caps = [f for f in bm.faces if all(v.co.x == 0.0 for v in f.verts)]
        bmesh.ops.delete(bm, geom=caps, context="FACES_ONLY")
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=2 * eps)
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
        bad = sum(not e.is_manifold for e in bm.edges)
        if bad:
            raise RuntimeError(f"la costura del centro queda con {bad} aristas sueltas")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
    V2, F2 = _read(obj.data)
    _drop(obj)
    return V2 / QF_SCALE, F2


def subdivide(V, F, levels=1):
    obj = _temp_object(V, F)
    mod = obj.modifiers.new("sub", "SUBSURF")
    mod.levels = levels
    mod.quality = 3
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    out = _read(me)
    ev.to_mesh_clear()
    _drop(obj)
    return out


def gradient(sdf, P, h=1e-4):
    g = np.empty_like(P)
    for i in range(3):
        e = np.zeros(3)
        e[i] = h
        g[:, i] = (sdf(P + e) - sdf(P - e)) / (2 * h)
    return g


def project(sdf, P, iters=10):
    """Lleva cada punto a la superficie (nivel 0) por el gradiente."""
    P = P.copy()
    for _ in range(iters):
        f = sdf(P)
        g = gradient(sdf, P)
        P -= (f / np.maximum(np.sum(g * g, -1), 1e-10))[:, None] * g
    return P


def normals_of(sdf, P):
    g = gradient(sdf, P)
    return g / np.maximum(norm(g), 1e-12)[:, None]


def mirror_pairs(V, tol=2e-4):
    kd = KDTree(len(V))
    for i, v in enumerate(V):
        kd.insert(v, i)
    kd.balance()
    pair = np.empty(len(V), dtype=int)
    for i, v in enumerate(V):
        _, j, d = kd.find((-v[0], v[1], v[2]))
        if d > tol:
            raise RuntimeError(f"sin espejo el vértice {i} {tuple(v)} ({d:.5f})")
        pair[i] = j
    return pair


def symmetrize(V, pair):
    M = V[pair] * np.array([-1.0, 1.0, 1.0])
    return (V + M) / 2


def sdf_piece(sdf, lo, hi, cell, faces, symmetric):
    """Pieza orgánica: campo -> superficie -> QuadriFlow -> subdivisión -> proyección."""
    V, F = sample(sdf, lo, hi, cell)
    V, F = quadriflow(V, F, faces, symmetric, cell)
    V, F = subdivide(V, F)
    pair = mirror_pairs(V) if symmetric else None
    if symmetric:
        V = symmetrize(V, pair)
    V = project(sdf, V)
    if symmetric:
        V = symmetrize(V, pair)
    return V, F


def star_piece(sdf, centre, rot, radii, n, symmetric):
    """Pieza pequeña y abombada (un nudo): una esfera de caras cuadradas estirada a radii (en los
    ejes de rot), llevada a la superficie por rayos desde centre, subdividida y proyectada.
    Simétrica en x si el primer eje de rot es x."""
    U, F = cube_sphere(n)
    centre = _v(centre)
    D = (U * _v(radii)) @ rot.T
    D /= norm(D)[:, None]
    lo, hi = np.zeros(len(D)), np.full(len(D), max(radii) * 3)
    for _ in range(50):
        mid = (lo + hi) / 2
        inside = sdf(centre + D * mid[:, None]) < 0
        lo = np.where(inside, mid, lo)
        hi = np.where(inside, hi, mid)
    V = centre + D * ((lo + hi) / 2)[:, None]
    V, F = subdivide(V, F)
    pair = mirror_pairs(V - centre * np.array([0.0, 1.0, 1.0])) if symmetric else None
    V = project(sdf, V)
    if symmetric:
        c = centre * np.array([0.0, 1.0, 1.0])
        V = symmetrize(V - c, pair) + c
    return V, F


def mirrored(V, F):
    return V * np.array([-1.0, 1.0, 1.0]), [tuple(reversed(f)) for f in F]


def grid_faces(rows, cols, closed_cols=True, closed_rows=False):
    """Caras de una rejilla de rows x cols vértices (índice r * cols + c)."""
    F = []
    for r in range(rows - (0 if closed_rows else 1)):
        for c in range(cols - (0 if closed_cols else 1)):
            r2, c2 = (r + 1) % rows, (c + 1) % cols
            F.append((r * cols + c, r * cols + c2, r2 * cols + c2, r2 * cols + c))
    return F


# --- Piezas regladas -----------------------------------------------------------------------------

def cube_sphere(n):
    """Esfera unidad con caras cuadradas repartidas por igual (sin polos)."""
    verts = {}
    V = []

    def vert(i, j, k):
        key = (i, j, k)
        if key not in verts:
            u = np.tan(np.pi / 4 * (2 * np.array((i, j, k)) / n - 1))
            verts[key] = len(V)
            V.append(u / np.linalg.norm(u))
        return verts[key]

    F = []
    for axis in range(3):
        a1, a2 = [a for a in range(3) if a != axis]
        for side in (0, n):
            for p in range(n):
                for q in range(n):
                    quad = []
                    for dp, dq in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        idx = [0, 0, 0]
                        idx[axis], idx[a1], idx[a2] = side, p + dp, q + dq
                        quad.append(vert(*idx))
                    F.append(tuple(quad))
    V = np.array(V)
    # Todas hacia fuera (si no, la subdivisión toma las aristas por bordes y sale torcida).
    out = []
    for f in F:
        a, b, c = V[f[0]], V[f[1]], V[f[2]]
        out.append(f if np.cross(b - a, c - a) @ (a + b + c) > 0 else tuple(reversed(f)))
    return V, out


def band_around(sdf, axis_xy, zc, width, thick, n_around=64, n_loop=12, inner=0.006, e=4.0):
    """Una cinta que rodea una forma a la altura zc(phi) (phi = 0 delante, hacia -y): cada
    sección es un rectángulo redondeado apoyado en la superficie, de width de ancho y thick de
    grueso (y inner metido hacia dentro, para que no quede rendija)."""
    phis = 2 * np.pi * np.arange(n_around) / n_around
    th = 2 * np.pi * np.arange(n_loop) / n_loop
    ca, sa = np.cos(th), np.sin(th)
    t = np.sign(ca) * np.abs(ca) ** (2 / e)
    h = (thick - inner) / 2 + (thick + inner) / 2 * np.sign(sa) * np.abs(sa) ** (2 / e)
    PH, T = np.meshgrid(phis, t, indexing="ij")
    _, H = np.meshgrid(phis, h, indexing="ij")
    Z = zc(PH) + T * width / 2
    S, N = surface_hits(sdf, axis_xy, PH.ravel(), Z.ravel())
    V = S + N * H.ravel()[:, None]
    return V, grid_faces(n_around, n_loop, closed_cols=True, closed_rows=True)


def surface_hits(sdf, axis_xy, phi, z, r_max=0.6, steps=240):
    """Donde un rayo horizontal desde fuera hacia el eje (en phi, a la altura z) toca la forma por
    primera vez; y la normal allí."""
    d = np.stack([np.sin(phi), -np.cos(phi), np.zeros_like(phi)], -1)
    base = np.stack([np.full_like(phi, axis_xy[0]), np.full_like(phi, axis_xy[1]), z], -1)
    rs = np.linspace(r_max, 0.0, steps)
    P = base[:, None, :] + d[:, None, :] * rs[None, :, None]
    f = sdf(P)
    first = np.argmax(f < 0, axis=1)
    lo = rs[np.maximum(first - 1, 0)]
    hi = rs[first]
    for _ in range(40):
        mid = (lo + hi) / 2
        inside = sdf(base + d * mid[:, None]) < 0
        hi = np.where(inside, mid, hi)
        lo = np.where(inside, lo, mid)
    S = base + d * ((lo + hi) / 2)[:, None]
    return S, normals_of(sdf, S)


def disc(n):
    """Rejilla n x n llevada al disco unidad (todo cuadriláteros) y su borde en orden."""
    u = np.linspace(-1, 1, n)
    U, W = np.meshgrid(u, u, indexing="ij")
    X = U * np.sqrt(1 - W * W / 2)
    Y = W * np.sqrt(1 - U * U / 2)
    pts = np.stack([X.ravel(), Y.ravel()], -1)
    F = grid_faces(n, n, closed_cols=False)
    rim = [i * n for i in range(n)] + [(n - 1) * n + j for j in range(1, n)] + \
          [i * n + n - 1 for i in range(n - 2, -1, -1)] + [j for j in range(n - 2, 0, -1)]
    return pts, F, rim


def head_front(x, z):
    """Punto de la cara delantera de la cabeza en (x, z) (vista de frente) y su normal."""
    c, r = _v(HEAD_C), _v(HEAD_R)
    s = 1 - ((x - c[0]) / r[0]) ** 2 - ((z - c[2]) / r[2]) ** 2
    y = c[1] - r[1] * np.sqrt(np.maximum(s, 0.0))
    P = np.stack([x, y, z], -1)
    n = (P - c) / (r * r)
    return P, n / norm(n)[..., None]


def _eye_height(x, z):
    """Lo que el blanco del ojo izquierdo sobresale de la cabeza en (x, z)."""
    rho2 = ((x - EYE_C[0]) / EYE_AB[0]) ** 2 + ((z - EYE_C[1]) / EYE_AB[1]) ** 2
    return EYE_LIFT + EYE_DOME * np.clip(1 - rho2, 0.0, 1.0)


def eye_white(n=12):
    pts, F, rim = disc(n)
    return _decal(pts, F, rim, EYE_C, EYE_AB, lambda x, z: _eye_height(x, z),
                  [(1.012, lambda h: h * 0.55), (1.024, lambda h: -0.004)])


def pupil(n=10):
    pts, F, rim = disc(n)

    def height(x, z):
        rho2 = ((x - PUPIL_C[0]) / PUPIL_AB[0]) ** 2 + ((z - PUPIL_C[1]) / PUPIL_AB[1]) ** 2
        return _eye_height(x, z) + 0.0018 + 0.0012 * np.clip(1 - rho2, 0, 1)

    return _decal(pts, F, rim, PUPIL_C, PUPIL_AB, height, [(1.01, lambda h: h - 0.0012), (1.02, lambda h: h - 0.0045)])


def _pupil_height(x, z):
    rho2 = ((x - PUPIL_C[0]) / PUPIL_AB[0]) ** 2 + ((z - PUPIL_C[1]) / PUPIL_AB[1]) ** 2
    return _eye_height(x, z) + 0.0018 + 0.0012 * np.clip(1 - rho2, 0, 1)


def glint(n=6):
    """El brillo de la pupila: una gota blanca pequeña arriba y hacia fuera."""
    pts, F, rim = disc(n)
    return _decal(pts, F, rim, GLINT_C, GLINT_AB, lambda x, z: _pupil_height(x, z) + 0.0012,
                  [(1.05, lambda h: h - 0.0016)])


def _decal(pts, F, rim, centre, ab, height, rim_rings):
    """Calca sobre la cabeza: el disco en (x, z) de frente, levantado height(x, z) por la normal,
    y unos anillos de borde (escala, altura(h del borde)) que bajan hacia la cabeza."""
    x = centre[0] + ab[0] * pts[:, 0]
    z = centre[1] + ab[1] * pts[:, 1]
    P, N = head_front(x, z)
    V = list(P + N * height(x, z)[:, None])
    F = list(F)
    prev = rim
    for scale, h_of in rim_rings:
        ring = []
        for i in rim:
            xr = centre[0] + ab[0] * pts[i, 0] * scale
            zr = centre[1] + ab[1] * pts[i, 1] * scale
            p, nrm = head_front(np.array([xr]), np.array([zr]))
            hh = h_of(height(np.array([centre[0] + ab[0] * pts[i, 0]]), np.array([centre[1] + ab[1] * pts[i, 1]]))[0])
            ring.append(len(V))
            V.append(p[0] + nrm[0] * hh)
        for k in range(len(rim)):
            k2 = (k + 1) % len(rim)
            F.append((prev[k], ring[k], ring[k2], prev[k2]))
        prev = ring
    V = np.array(V)
    return V, _facing(V, F, np.array([0.0, -1.0, 0.0]))


def _facing(V, F, direction):
    """Da la vuelta a las caras si miran al revés de direction (de media)."""
    s = 0.0
    for f in F:
        a, b, c = V[f[0]], V[f[1]], V[f[2]]
        s += np.cross(b - a, c - a) @ direction
    return F if s > 0 else [tuple(reversed(f)) for f in F]


def ribbon(path, widths, thick, face_normals=None, rows=10, cut=0.0, e=4.0, sides=None):
    """Una tira de tela a lo largo de path (m, 3): anchos por punto, grosor, y la normal de la cara
    ancha en cada punto (o, con sides, la dirección del ancho). cut corta la punta en bisel (m a
    lo largo por unidad de ancho)."""
    path = _v(path)
    m = len(path)
    th = 2 * np.pi * np.arange(rows) / rows
    ca, sa = np.cos(th), np.sin(th)
    a = np.sign(ca) * np.abs(ca) ** (2 / e)
    b = np.sign(sa) * np.abs(sa) ** (2 / e)
    V = []
    for i in range(m):
        tg = path[min(i + 1, m - 1)] - path[max(i - 1, 0)]
        tg /= np.linalg.norm(tg)
        if sides is not None:
            side = _v(sides[i])
            side = side - tg * (side @ tg)
            side /= np.linalg.norm(side)
            nrm = np.cross(side, tg)
        else:
            nrm = _v(face_normals[i])
            nrm = nrm - tg * (nrm @ tg)
            nrm /= np.linalg.norm(nrm)
            side = np.cross(tg, nrm)
        w = widths[i] / 2
        t_ = thick[i] / 2 if hasattr(thick, "__len__") else thick / 2
        # Las puntas: redondas al empezar (dentro del nudo) y cortadas en bisel al final.
        shift = cut * a * w if i == m - 1 else 0.0
        for k in range(rows):
            V.append(path[i] + side * (a[k] * w) + nrm * (b[k] * t_) + tg * (shift[k] if i == m - 1 else 0.0))
    V = np.array(V)
    F = grid_faces(m, rows, closed_cols=True)
    n0 = len(V)
    V = np.vstack([V, path[0], path[-1]])
    for k in range(rows):
        k2 = (k + 1) % rows
        F.append((n0, k2, k))
        F.append((n0 + 1, (m - 1) * rows + k, (m - 1) * rows + k2))
    return V, F


def bezier(ctrl, n):
    ctrl = [_v(c) for c in ctrl]
    out = []
    for i in range(n + 1):
        t = i / n
        p = list(ctrl)
        while len(p) > 1:
            p = [p[j] * (1 - t) + p[j + 1] * t for j in range(len(p) - 1)]
        out.append(p[0])
    return np.array(out)


def smooth01(t):
    return t * t * (3 - 2 * t)


# =================================================================================================
# Pesos
# =================================================================================================

def chain_param(P, pts):
    """Para cada punto, la longitud de arco del punto más cercano de la polilínea pts."""
    pts = [_v(p) for p in pts]
    best_d = np.full(len(P), np.inf)
    best_s = np.zeros(len(P))
    s0 = 0.0
    for a, b in zip(pts, pts[1:]):
        ab = b - a
        L = np.linalg.norm(ab)
        t = np.clip(((P - a) @ ab) / (L * L), 0, 1)
        d = norm(P - (a + t[:, None] * ab))
        better = d < best_d
        best_d = np.where(better, d, best_d)
        best_s = np.where(better, s0 + t * L, best_s)
        s0 += L
    return best_s


def _step(x, centre, half):
    """0 antes de centre - half, 1 después de centre + half, suave entre medias."""
    return smoothstep(centre - half, centre + half, x)


def diffuse(values, F, iters):
    """Suaviza valores por vértice a lo largo de la malla (solo entre vecinos por arista)."""
    E = set()
    for f in F:
        for a, b in zip(f, f[1:] + f[:1]):
            E.add((min(a, b), max(a, b)))
    E = np.array(sorted(E))
    n = len(values)
    cnt = np.bincount(E[:, 0], minlength=n) + np.bincount(E[:, 1], minlength=n)
    v = values.copy()
    for _ in range(iters):
        acc = np.bincount(E[:, 0], weights=v[E[:, 1]], minlength=n) + np.bincount(E[:, 1], weights=v[E[:, 0]], minlength=n)
        v = 0.5 * v + 0.5 * acc / np.maximum(cnt, 1)
    return v


## Reparto entre torso y extremidad: de qué es cada vértice (por qué forma tiene más cerca) y
## luego suavizado por la superficie, así el costado junto al antebrazo no se va con el brazo.
MEMBER_SHARP, MEMBER_SMOOTH = 0.008, {"A": 14, "L": 22}


def body_weights(P, F):
    """Pesos del cuerpo por vértice: {hueso: array}."""
    t, al, ar, ll, lr = body_parts(P)
    d = {"AL": al, "AR": ar, "LL": ll, "LR": lr}
    W = {}

    def member(key):
        # De esta extremidad si es la forma más cercana (contra el torso y las demás).
        others = np.minimum.reduce([t] + [v for k, v in d.items() if k != key])
        m = smoothstep(-MEMBER_SHARP, MEMBER_SHARP, others - d[key])
        return np.clip(diffuse(m, F, MEMBER_SMOOTH[key[0]]), 0, 1)

    limbs = {k: member(k) for k in d}
    total = sum(limbs.values())
    over = np.maximum(total, 1.0)
    for k in limbs:
        limbs[k] = limbs[k] / over
    torso = 1.0 - sum(limbs.values())
    z = P[:, 2]
    cad = 1 - _step(z, 0.405, 0.05)
    pec = _step(z, 0.505, 0.05)
    W["cadera"] = torso * cad
    W["columna"] = torso * (1 - cad - pec)
    W["pecho"] = torso * pec
    for s, tag in ((1, "L"), (-1, "R")):
        m = limbs["A" + tag]
        chain = [_side(SHOULDER, s), _side(ELBOW, s), _side(WRIST, s), _side(HAND_END, s)]
        sp = chain_param(P, chain)
        se = np.linalg.norm(_v(ELBOW) - _v(SHOULDER))
        sw = se + np.linalg.norm(_v(WRIST) - _v(ELBOW))
        fore = _step(sp, se, 0.045)
        hand = _step(sp, sw + 0.012, 0.018)
        W[f"brazo.{tag}"] = m * (1 - fore)
        W[f"antebrazo.{tag}"] = m * (fore - hand)
        W[f"mano.{tag}"] = m * hand
        m = limbs["L" + tag]
        chain = [_side(HIP, s), _side(KNEE, s), _side(ANKLE, s), (s * ANKLE[0], ANKLE[1], 0.0)]
        sp = chain_param(P, chain)
        sk = np.linalg.norm(_v(KNEE) - _v(HIP))
        sa = sk + np.linalg.norm(_v(ANKLE) - _v(KNEE))
        shin = _step(sp, sk, 0.045)
        foot = _step(sp, sa + 0.004, 0.022)
        W[f"muslo.{tag}"] = m * (1 - shin)
        W[f"espinilla.{tag}"] = m * (shin - foot)
        W[f"pie.{tag}"] = m * foot
    return limit(W)


def limit(W, keep=4, floor=0.01):
    """Como mucho keep huesos por vértice, sin pesos de menos de floor, y que sumen 1."""
    names = list(W)
    M = np.stack([np.clip(W[n], 0, None) for n in names], 1)
    if M.shape[1] > keep:
        # Se queda con los que pasan del keep-ésimo; si hay empate justo en el corte (un hueso
        # .L y su .R en el centro), fuera los empatados: así el espejo sigue exacto.
        s = -np.sort(-M, axis=1)
        cut = s[:, keep - 1]
        tie = s[:, keep] >= cut - 1e-7
        cut = np.where(tie, cut + 1e-7, cut - 1e-12)
        M = np.where(M >= cut[:, None], M, 0.0)
    M = np.where(M >= floor, M, 0.0)
    M /= np.maximum(M.sum(1, keepdims=True), 1e-12)
    return {n: M[:, i] for i, n in enumerate(names) if M[:, i].max() > 0}


# =================================================================================================
# Piezas
# =================================================================================================

def piece(name, V, F, mat, weights, flat=()):
    return {"name": name, "V": np.asarray(V), "F": [tuple(f) for f in F], "mat": mat, "w": weights, "flat": set(flat)}


def rigid(bone, n):
    return {bone: np.ones(n)}


## El cuerpo ya hecho (vértices y pesos): el cinturón copia de él sus pesos.
BODY = {}


def build_body():
    V, F = sdf_piece(sd_body, (-0.42, -0.27, 0.0), (0.42, 0.25, 0.72), 0.005, QF_FACES["cuerpo"], True)
    W = mirrored_weights(body_weights(V, F), mirror_pairs(V, tol=1e-9))
    BODY.update(V=V, W=W)
    return [piece("pecho_traje", V, F, "traje", W)]


def _flip(name):
    return name.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")


def mirrored_weights(W, pair):
    """Pesos exactos en espejo: cada vértice, la media de lo suyo y lo de su espejo (con los
    huesos de un lado cambiados por los del otro)."""
    names = set(W) | {_flip(n) for n in W}
    n = len(pair)
    get = lambda nm: W.get(nm, np.zeros(n))  # noqa: E731
    return limit({nm: (get(nm) + get(_flip(nm))[pair]) / 2 for nm in names})


def copied_weights(P, k=6):
    """Pesos para lo que va encima del torso (cinturón, nudo): la media de los k vértices del
    cuerpo más cercanos que no son de los brazos."""
    V, W = BODY["V"], BODY["W"]
    arm = sum(W.get(f"{b}.{s}", 0) for b in ("brazo", "antebrazo", "mano") for s in "LR")
    idx = np.nonzero(arm < 0.01)[0]
    kd = KDTree(len(idx))
    for j, i in enumerate(idx):
        kd.insert(V[i], j)
    kd.balance()
    out = {n: np.zeros(len(P)) for n in W}
    for pi, p in enumerate(P):
        found = kd.find_n(p, k)
        ws = np.array([1.0 / (d + 1e-4) ** 2 for _, _, d in found])
        ws /= ws.sum()
        for (_, j, _), wt in zip(found, ws):
            for n in W:
                out[n][pi] += wt * W[n][idx[j]]
    return limit(out)


def build_head():
    out = []
    U, F = cube_sphere(16)
    V = _v(HEAD_C) + U * _v(HEAD_R)
    out.append(piece("cabeza_traje", V, F, "traje", rigid("cabeza", len(V))))
    for tag, s in (("L", 1), ("R", -1)):
        for nm, (V, F), mat in (("ojo", eye_white(), "ojo"), ("pupila", pupil(), "pupila"), ("ojo_brillo", glint(), "ojo")):
            if s < 0:
                V, F = mirrored(V, F)
            out.append(piece(f"cabeza_{nm}_{tag}", V, F, mat, rigid("cabeza", len(V))))
    # La cinta: algo más alta por detrás.
    zc = lambda ph: BAND_Z + BAND_BACK_RISE * (1 - np.cos(ph)) / 2  # noqa: E731
    V, F = band_around(sd_head, HEAD_C[:2], zc, BAND_W, BAND_T, n_around=72, n_loop=12)
    out.append(piece("cabeza_cinta", V, F, "cinta", rigid("cabeza", len(V))))
    out += head_knot(zc)
    return out


def _frame(normal, up=(0, 0, 1)):
    n = _v(normal) / np.linalg.norm(normal)
    u = _v(up) - n * (n @ _v(up))
    u /= np.linalg.norm(u)
    t = np.cross(u, n)
    return t, u, n


def knot_sdf(centre, t, u, n, size, strap=True):
    """Un nudo de tela: un cojín redondeado y, por encima, la vuelta de la cinta que lo aprieta."""
    rot = np.stack([t, u, n], 1)
    sx, sy, sz = size

    def f(p):
        body = sd_ellipsoid(p, centre, (sx, sy, sz), rot)
        if not strap:
            return body
        wrap = sd_ellipsoid(p, centre + n * 0.003, (sx * 0.62, sy * 1.12, sz * 1.08), rot)
        return smin(body, wrap, 0.01)

    return f


## El nudo de la cinta: dónde (ángulo desde delante; más de pi es la derecha del ninja) y tamaño;
## y sus colas: (subida, largo, ancho al salir, ancho al final).
HEAD_KNOT_PHI, HEAD_KNOT_SIZE = np.pi + 0.95, (0.042, 0.038, 0.028)
## Colas: (subida al salir, caída al final, largo, ancho al salir, ancho al final).
HEAD_TAILS = ((0.32, 0.05, 0.24, 0.048, 0.078), (-0.18, -0.42, 0.2, 0.048, 0.072))


def head_knot(zc):
    """Nudo atrás, hacia la derecha del ninja, y dos colas anchas que se abren en V al viento."""
    phi = HEAD_KNOT_PHI
    S, N = surface_hits(sd_head, HEAD_C[:2], np.array([phi]), np.array([zc(phi)]))
    S, N = S[0], N[0]
    t, u, n = _frame(N)
    centre = S + n * (BAND_T + 0.004)
    f = knot_sdf(centre, t, u, n, HEAD_KNOT_SIZE, strap=True)
    V, F = star_piece(f, centre, np.stack([t, u, n], 1), HEAD_KNOT_SIZE, KNOT_CUTS, False)
    out = [piece("cabeza_cinta_nudo", V, F, "cinta", rigid("cabeza", len(V)))]
    # Las colas salen del nudo hacia atrás y hacia fuera (como si corriera), una subiendo y otra
    # bajando, con una onda; el ancho va de canto al salir y se tumba hacia la punta para que se
    # vean también desde arriba.
    up = _v((0, 0, 1))
    trail = _v((-0.68, 0.73, 0.0))
    trail /= np.linalg.norm(trail)
    across = np.cross(trail, up)
    root = centre + n * 0.002
    for i, (rise, fall, length, w0, w1) in enumerate(HEAD_TAILS, 1):
        # Sale hacia atrás y afuera subiendo (rise) y acaba cayendo (fall), con una onda de lado.
        wave = across * (0.02 if i == 1 else -0.016)
        L = length
        path = bezier([root, root + trail * L * 0.33 + up * L * rise * 0.6 + wave,
                       root + trail * L * 0.68 + up * L * (rise * 0.7 + fall * 0.4) - wave,
                       root + trail * L + up * L * (rise * 0.4 + fall)], 16)
        m = len(path)
        widths = [w0 + (w1 - w0) * smooth01(k / (m - 1)) for k in range(m)]
        sides = []
        for k in range(m):
            # El ancho, de pie al salir del nudo, se va tumbando (y se ve desde arriba).
            flat_ = (0.3 + 0.75 * smooth01(k / (m - 1))) * (1 if i == 1 else -1)
            sides.append(up * math.cos(flat_) + across * math.sin(flat_))
        V, F = ribbon(path, widths, 0.011, sides=sides, rows=10, cut=0.4 if i == 1 else -0.4)
        out.append(piece(f"cabeza_cinta_cola_{i}", V, F, "cinta", rigid("cabeza", len(V)), flat=range(len(F) - 20, len(F))))
    return out


def build_belt():
    out = []
    V, F = band_around(sd_lower_body, (0.0, 0.0), lambda ph: np.full_like(ph, BELT_Z), BELT_W, BELT_T, n_around=72, n_loop=12)
    pair = mirror_pairs(V)
    V = symmetrize(V, pair)
    out.append(piece("cadera_cinta", V, F, "cinta", mirrored_weights(copied_weights(V), pair)))
    # El nudo, delante en el centro.
    S, N = surface_hits(sd_lower_body, (0.0, 0.0), np.array([0.0]), np.array([BELT_Z]))
    S, N = S[0], N[0]
    t, u, n = _frame(N)
    centre = S + n * (BELT_T + 0.01)
    f = knot_sdf(centre, t, u, n, BELT_KNOT_SIZE, strap=True)
    V, F = star_piece(f, centre, np.stack([t, u, n], 1), BELT_KNOT_SIZE, KNOT_CUTS, True)
    knot_w = mirrored_weights(copied_weights(V), mirror_pairs(V))
    out.append(piece("cadera_cinta_nudo", V, F, "cinta", knot_w))
    # Las colas: salen de debajo del nudo, cuelgan algo abiertas y una más larga que otra. Se van
    # con el muslo de su lado (hasta un 60 % en la punta) para no quedarse dentro al levantarlo.
    root_w = copied_weights(centre[None, :])
    fwd = n
    for tag, s, length, spread in BELT_TAILS:
        top = centre - u * 0.016 + t * (s * 0.01) - fwd * 0.004
        ctrl = [top, top - u * 0.05 + t * (s * 0.014) + fwd * 0.002,
                top - u * 0.1 + t * (s * spread * 0.7) - fwd * 0.004, top - u * length + t * (s * spread) - fwd * 0.016]
        path = bezier(ctrl, 12)
        m = len(path)
        widths = [0.038 + 0.02 * smooth01(k / (m - 1)) for k in range(m)]
        normals = [fwd + t * (s * 0.3)] * m
        V, F = ribbon(path, widths, 0.01, normals, rows=10, cut=-0.55 * s)
        # Peso: el del nudo arriba, y el muslo creciendo hacia la punta.
        along = np.repeat(np.linspace(0, 1, m), 10)
        along = np.concatenate([along, [0.0, 1.0]])
        pull = 0.6 * smooth01(np.clip(along * 1.2, 0, 1))
        w = {k: v[0] * (1 - pull) for k, v in root_w.items()}
        w[f"muslo.{tag}"] = w.get(f"muslo.{tag}", 0) + pull
        out.append(piece(f"cadera_cinta_cola_{tag}", V, F, "cinta", limit(w), flat=range(len(F) - 20, len(F))))
    return out


def build_hands():
    w0 = _v(WRIST)
    V, F = sdf_piece(sd_mitten, w0 - (0.1, 0.16, 0.18), w0 + (0.12, 0.1, 0.06), 0.002, QF_FACES["mano"], False)
    out = [piece("mano.L_guante", V, F, "guante", rigid("mano.L", len(V)))]
    V2, F2 = mirrored(V, F)
    out.append(piece("mano.R_guante", V2, F2, "guante", rigid("mano.R", len(V2))))
    return out


def sole_ring():
    """La suela del pie izquierdo: un canto fino que asoma bajo el pie, siguiendo su contorno."""
    n = 56
    phis = 2 * np.pi * np.arange(n) / n
    centre = (FOOT_X, -0.035)
    # El contorno del pie justo por encima de la planta, y la suela siguiéndolo: canto redondo que
    # asoma 2 mm y se mete en el pie por arriba. (altura, cuánto sale del contorno)
    rings = [(0.0, -0.004), (0.0015, 0.0), (0.004, 0.0018), (0.010, 0.0018), (0.013, 0.0004), (0.0155, -0.004)]
    S, _ = surface_hits(sd_foot, centre, phis, np.full(n, FOOT_SOLE + 0.008), r_max=0.3)
    outline = norm(S[:, :2] - _v(centre))
    d = np.stack([np.sin(phis), -np.cos(phis), np.zeros(n)], -1)
    V = []
    for z_place, dr in rings:
        r = outline + dr
        V.append(np.stack([centre[0] + d[:, 0] * r, centre[1] + d[:, 1] * r, np.full(n, z_place)], -1))
    V = np.vstack(V)
    F = grid_faces(len(rings), n, closed_cols=True)
    bottom = len(V)
    top = bottom + 1
    V = np.vstack([V, [[centre[0], centre[1], rings[0][0]], [centre[0], centre[1], rings[-1][0]]]])
    flat = []
    last = (len(rings) - 1) * n
    for k in range(n):
        k2 = (k + 1) % n
        flat.append(len(F))
        F.append((bottom, k2, k))
        F.append((top, last + k, last + k2))
    F = _facing_out(V, F, _v((centre[0], centre[1], 0.006)))
    return V, F, flat


def _facing_out(V, F, centre):
    s = 0.0
    for f in F:
        a, b, c = V[f[0]], V[f[1]], V[f[2]]
        s += np.cross(b - a, c - a) @ ((a + b + c) / 3 - centre)
    return F if s > 0 else [tuple(reversed(f)) for f in F]


def build_feet():
    lo = (FOOT_X - 0.12, -0.22, -0.01)
    hi = (FOOT_X + 0.12, 0.12, 0.2)
    V, F = sdf_piece(sd_foot, lo, hi, 0.002, QF_FACES["pie"], False)
    out = [piece("pie.L_traje", V, F, "traje", rigid("pie.L", len(V)))]
    V2, F2 = mirrored(V, F)
    out.append(piece("pie.R_traje", V2, F2, "traje", rigid("pie.R", len(V2))))
    V, F, flat = sole_ring()
    out.append(piece("pie.L_suela", V, F, "suela", rigid("pie.L", len(V)), flat=flat))
    V2, F2 = mirrored(V, F)
    out.append(piece("pie.R_suela", V2, F2, "suela", rigid("pie.R", len(V2)), flat=flat))
    return out


# =================================================================================================
# El .blend
# =================================================================================================

def hex_linear(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in srgb)


def material(name, colour, rough=0.7, sheen=0.0, coat=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = hex_linear(colour)
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
    if coat:
        b.inputs["Coat Weight"].default_value = coat
    m.diffuse_color = (*c, 1)
    return m


def make_object(p, arm, coll, mats):
    me = bpy.data.meshes.new(p["name"])
    me.from_pydata(p["V"].tolist(), [], [list(f) for f in p["F"]])
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    # Las piezas cerradas, con las caras hacia fuera; las calcas (abiertas) ya salen bien.
    if not any(e.is_boundary for e in bm.edges):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mats[p["mat"]])
    for poly in me.polygons:
        poly.use_smooth = poly.index not in p["flat"]
    obj = bpy.data.objects.new(p["name"], me)
    coll.objects.link(obj)
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    for bone, w in p["w"].items():
        vg = obj.vertex_groups.new(name=bone)
        for i in np.nonzero(w > 0)[0]:
            vg.add([int(i)], float(w[i]), "REPLACE")
    return obj


def symmetry_error(objs):
    """Máximo desvío del espejo: dentro de cada pieza simétrica y entre cada pareja L/R."""
    def verts(o):
        return np.array([v.co[:] for v in o.data.vertices])

    def err(A, B):
        kd = KDTree(len(B))
        for i, v in enumerate(B):
            kd.insert(v, i)
        kd.balance()
        return max(kd.find((-a[0], a[1], a[2]))[2] for a in A)

    report = {}
    by = {o.name: o for o in objs}
    for n in ("pecho_traje", "cabeza_traje", "cabeza_cinta", "cadera_cinta", "cadera_cinta_nudo"):
        report[n] = err(verts(by[n]), verts(by[n]))
    for a, b in (("mano.L_guante", "mano.R_guante"), ("pie.L_traje", "pie.R_traje"), ("pie.L_suela", "pie.R_suela"),
                 ("cabeza_ojo_L", "cabeza_ojo_R"), ("cabeza_pupila_L", "cabeza_pupila_R"),
                 ("cabeza_ojo_brillo_L", "cabeza_ojo_brillo_R")):
        report[f"{a} / {b}"] = err(verts(by[a]), verts(by[b]))
    # Y los pesos del cuerpo: cada vértice con su espejo, cada hueso con el de su lado contrario.
    body = by["pecho_traje"]
    V = verts(body)
    pair = mirror_pairs(V, tol=1e-6)
    names = {g.index: g.name for g in body.vertex_groups}
    W = [{names[g.group]: g.weight for g in v.groups} for v in body.data.vertices]

    def flip(n):
        return n.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")

    worst = 0.0
    for i, j in enumerate(pair):
        a, b = W[i], {flip(k): v for k, v in W[j].items()}
        for k in set(a) | set(b):
            worst = max(worst, abs(a.get(k, 0) - b.get(k, 0)))
    report["pesos del cuerpo"] = worst
    return report


def main():
    path = os.path.join(ART, "personajes", "ninja.blend")
    out = args[args.index("--salida") + 1] if "--salida" in args else path
    bpy.ops.wm.open_mainfile(filepath=path)
    arm = bpy.data.objects["ninja_esqueleto"]
    coll = bpy.data.collections.get("ninja_partes")
    old = [o for o in bpy.data.objects if o.type == "MESH"]
    before = sum(len(o.data.polygons) for o in old)
    for o in old:
        _drop(o)
    # La pose de reposo, para modelar sobre ella (las acciones no se tocan).
    action = arm.animation_data.action if arm.animation_data else None
    mats = {
        "traje": material("traje", TRAJE, rough=0.8, sheen=0.25),
        "cinta": material("cinta", CINTA, rough=0.6, sheen=0.3),
        "guante": material("guante", GUANTE, rough=0.65, sheen=0.2),
        "suela": material("suela", SUELA, rough=0.8),
        "ojo": material("ojo", OJO, rough=0.2, coat=0.6),
        "pupila": material("pupila", PUPILA, rough=0.1, coat=1.0),
    }
    for name in ("ceja", "solapa"):
        m = bpy.data.materials.get(name)
        if m and m.users == 0:
            bpy.data.materials.remove(m)
    pieces = build_body() + build_head() + build_belt() + build_hands() + build_feet()
    objs = [make_object(p, arm, coll, mats) for p in pieces]
    if action:
        arm.animation_data.action = action
    after = 0
    for o in objs:
        after += len(o.data.polygons)
        print(f"[ninja_v2] {o.name:24s} {len(o.data.polygons):6d} caras")
    print(f"[ninja_v2] {before} -> {after} caras")
    for k, v in symmetry_error(objs).items():
        print(f"[ninja_v2] simetría {k}: {v:.2e}")
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("[ninja_v2]", out)


if __name__ == "__main__":
    main()
