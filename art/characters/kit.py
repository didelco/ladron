"""Herramientas para modelar los personajes por script en Blender.

Los personajes se construyen igual que se esculpe en arcilla: se juntan formas
sencillas (esferas, cápsulas, cajas redondeadas), se funden en un solo volumen
con un remallado de vóxeles y se suavizan. Después se pintan por zonas (camisa,
pantalón, piel) y se les añaden las piezas duras (gorra, hebilla, linterna).

Convenciones (las de art/export.py): 1 unidad = 1 m, los pies en z = 0, el
frente mirando a -Y.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector


# --- Escena ------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


def _link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj)
    return obj


def _select_only(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


# --- Materiales ----------------------------------------------------------------

_mats = {}


def mat(name, colour, rough=0.6, metal=0.0, sheen=0.0, coat=0.0, emit=0.0):
    """Material de principled. colour en hex ("#rrggbb")."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = hex_rgb(colour)
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
        b.inputs["Sheen Roughness"].default_value = 0.5
    if coat:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.15
    if emit:
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*c, 1)
    _mats[name] = m
    return m


def hex_rgb(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in srgb)


def paint(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def paint_regions(obj, rules, default):
    """Pinta cada cara con el primer material cuya regla acepte su centro
    (en coordenadas de mundo) y su normal: rules = [(material, fn(c, n)), ...]."""
    mats = [default] + [m for m, _ in rules]
    obj.data.materials.clear()
    for m in mats:
        obj.data.materials.append(m)
    mw = obj.matrix_world
    rot = mw.to_3x3()
    for p in obj.data.polygons:
        c = mw @ p.center
        n = (rot @ p.normal).normalized()
        p.material_index = 0
        for i, (_, fn) in enumerate(rules):
            if fn(c, n):
                p.material_index = i + 1
                break
    return obj


# --- Formas sueltas ---------------------------------------------------------------

def _mesh_obj(name, bm, coll=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _link(bpy.data.objects.new(name, me), coll)


def _place(bm, loc=(0, 0, 0), size=(1, 1, 1), rot=(0, 0, 0)):
    m = Matrix.Translation(loc) @ euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def euler(rot):
    from mathutils import Euler
    return Euler(rot, "XYZ")


def sphere(name, loc, size, rot=(0, 0, 0), coll=None, segs=96):
    """Elipsoide de semiejes size."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=1)
    _place(bm, loc, size, rot)
    return _mesh_obj(name, bm, coll)


def capsule(name, a, b, r, rb=None, coll=None):
    """Cápsula (o cono redondeado) de a a b, radios r y rb."""
    rb = r if rb is None else rb
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    d = b - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    rings = 64
    for i, (c, rr) in enumerate(((a, r), (b, rb))):
        s = bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=rr)
        bmesh.ops.translate(bm, vec=c, verts=s["verts"])
    cone = bmesh.ops.create_cone(bm, cap_ends=True, segments=rings, radius1=r, radius2=rb, depth=d.length)
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), verts=cone["verts"])
    return _mesh_obj(name, bm, coll)


def box(name, loc, size, rot=(0, 0, 0), bevel=0.0, coll=None, segs=3):
    """Caja de medidas totales size, con los cantos redondeados."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    _place(bm, (0, 0, 0), size)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=segs, affect="EDGES", profile=0.5)
    _place(bm, loc, (1, 1, 1), rot)
    return _mesh_obj(name, bm, coll)


def cylinder(name, loc, r, depth, rot=(0, 0, 0), r2=None, segs=32, bevel=0.0, coll=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    if bevel:
        rims = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.z) != abs(e.link_faces[1].normal.z)]
        bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=3, affect="EDGES", profile=0.5)
    _place(bm, loc, (1, 1, 1), rot)
    return _mesh_obj(name, bm, coll)


def lathe(name, profile, loc=(0, 0, 0), size=(1, 1, 1), rot=(0, 0, 0), segs=48, coll=None):
    """Sólido de revolución de un perfil [(radio, z), ...] de abajo arriba."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in profile]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=segs, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _place(bm, loc, size, rot)
    return _mesh_obj(name, bm, coll)


def slab(name, outline, depth, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, coll=None):
    """Pieza plana: un contorno [(x, z), ...] extruido depth en Y."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -depth / 2, z)) for x, z in outline]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, depth, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES", profile=0.5, clamp_overlap=True)
    _place(bm, loc, (1, 1, 1), rot)
    return _mesh_obj(name, bm, coll)


def ribbon(name, points, widths, thickness, up=(0, 0, 1), side=None, coll=None):
    """Cinta a lo largo de una polilínea: points, anchos por punto. El ancho
    queda perpendicular a la dirección y a up; o a lo largo de side si se da."""
    pts = [Vector(p) for p in points]
    up = Vector(up)
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if side is not None:
            sv = Vector(side)
            across = (sv - t * sv.dot(t)).normalized()
        else:
            across = t.cross(up).normalized()
        w = widths[i] / 2
        rows.append([bm.verts.new(p + across * w), bm.verts.new(p - across * w)])
    for i in range(len(rows) - 1):
        bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
    obj = _mesh_obj(name, bm, coll)
    sol = obj.modifiers.new("solidify", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 0
    sub = obj.modifiers.new("subsurf", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    apply_mods(obj)
    return obj


def chain(name, points, radii, coll=None):
    """Salchicha orgánica por una serie de puntos con radios: para cejas,
    bigotes, dedos. Se funde después con blob()."""
    parts = []
    for i in range(len(points) - 1):
        parts.append(capsule(f"{name}_{i}", points[i], points[i + 1], radii[i], radii[i + 1], coll))
    return parts


# --- Fundir y suavizar ----------------------------------------------------------

def apply_mods(obj):
    _select_only([obj])
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def join(objs, name):
    _select_only(objs)
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def blob(name, parts, voxel=0.006, smooth=6, factor=0.6):
    """Funde las piezas en un único volumen continuo y lo suaviza: primero
    redondea las uniones (smooth) y luego quita el escalonado de los vóxeles
    sin encoger la forma (laplaciano)."""
    o = join(parts, name)
    r = o.modifiers.new("remesh", "REMESH")
    r.mode = "VOXEL"
    r.voxel_size = voxel
    r.adaptivity = 0.0
    s = o.modifiers.new("smooth", "SMOOTH")
    s.iterations = smooth
    s.factor = factor
    # El escalonado de los vóxeles: muchas pasadas suaves, en proporción al
    # tamaño del vóxel, y el laplaciano para no encoger la forma.
    lap = o.modifiers.new("laplacian", "LAPLACIANSMOOTH")
    lap.iterations = 10
    lap.lambda_factor = 0.8
    lap.lambda_border = 0.0
    lap.use_volume_preserve = True
    lap.use_normalized = True
    apply_mods(o)
    smooth_shade(o)
    return o


def smooth_shade(obj):
    me = obj.data
    me.shade_smooth()
    for name in ("sharp_face", "sharp_edge"):
        if name in me.attributes:
            me.attributes.remove(me.attributes[name])
    return obj


def decimate(obj, ratio):
    d = obj.modifiers.new("decimate", "DECIMATE")
    d.ratio = ratio
    apply_mods(obj)
    return obj


def delete_faces(obj, fn):
    """Borra las caras cuyo centro (mundo) cumple fn(c)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mw = obj.matrix_world
    kill = [f for f in bm.faces if fn(mw @ f.calc_center_median())]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


# --- Pegar cosas a una superficie -------------------------------------------------

def hit(obj, origin, direction=(0, 1, 0)):
    """Punto y normal (mundo) donde un rayo desde origin toca obj."""
    bpy.context.view_layer.update()
    mw = obj.matrix_world
    inv = mw.inverted()
    o = inv @ Vector(origin)
    d = (inv.to_3x3() @ Vector(direction)).normalized()
    ok, loc, nor, _ = obj.ray_cast(o, d)
    if not ok:
        raise ValueError(f"el rayo no toca {obj.name} desde {origin}")
    return mw @ loc, (mw.to_3x3() @ nor).normalized()


def on_surface(target, x, z, lift=0.0, from_y=-2.0):
    """Punto de la cara frontal de target a la altura (x, z), despegado lift
    por la normal, y un giro que alinea +Y local con la normal hacia dentro."""
    p, n = hit(target, (x, from_y, z))
    q = Vector((0, -1, 0)).rotation_difference(n)
    return p + n * lift, q


def orient(obj, loc, quat, extra=(0, 0, 0)):
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = quat @ euler(extra).to_quaternion()
    obj.location = loc
    return obj


def parent_all(root, objs):
    for o in objs:
        o.parent = root
    return root


def empty(name, coll=None):
    e = bpy.data.objects.new(name, None)
    return _link(e, coll)


# --- Formas de contorno controlado ------------------------------------------------
#
# En vez de fundir bolas (que deja todo hinchado), el cuerpo se levanta por
# secciones: anillos superelípticos (entre elipse y rectángulo redondeado) a
# distintas alturas, unidos y suavizados con subdivisión. Cada anillo es una
# medida que se ajusta a mano: hombros, cintura, cadera.

def _superellipse(rx, ry, e, segs):
    pts = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c, s = math.cos(a), math.sin(a)
        x = math.copysign(abs(c) ** (2 / e), c) * rx
        y = math.copysign(abs(s) ** (2 / e), s) * ry
        pts.append((x, y))
    return pts


def _subsurf(obj, levels=2):
    m = obj.modifiers.new("subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    apply_mods(obj)
    return smooth_shade(obj)


def loft(name, rings, segs=24, levels=2, coll=None):
    """Sólido por secciones: rings = [(z, cx, cy, rx, ry, e), ...] de abajo
    arriba (e = 2 elipse; más, más cuadrado). Cerrado arriba y abajo."""
    bm = bmesh.new()
    loops = []
    for z, cx, cy, rx, ry, e in rings:
        loops.append([bm.verts.new((cx + x, cy + y, z)) for x, y in _superellipse(rx, ry, e, segs)])
    for a, b in zip(loops, loops[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for ring, top in ((loops[0], False), (loops[-1], True)):
        c = sum((v.co for v in ring), Vector()) / len(ring)
        cv = bm.verts.new(c)
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((ring[j], ring[i], cv) if not top else (ring[i], ring[j], cv))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _subsurf(_mesh_obj(name, bm, coll), levels)


def tube(name, points, radii, e=2.0, segs=16, levels=2, coll=None, up=(0, -1, 0)):
    """Tubo por una polilínea con secciones superelípticas: brazos, piernas,
    mangas. radii = [(rx, ry), ...] por punto; los extremos se cierran
    redondeados con dos anillos que menguan."""
    pts = [Vector(p) for p in points]
    ups = Vector(up)
    bm = bmesh.new()
    loops = []

    def ring(p, t, rx, ry):
        side = t.cross(ups).normalized()
        fwd = side.cross(t).normalized()
        return [bm.verts.new(p + side * x + fwd * y) for x, y in _superellipse(rx, ry, e, segs)]

    def tangent(i):
        return (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()

    t0, t1 = tangent(0), tangent(len(pts) - 1)
    rx0, ry0 = radii[0]
    rx1, ry1 = radii[-1]
    loops.append(ring(pts[0] - t0 * rx0 * 0.55, t0, rx0 * 0.55, ry0 * 0.55))
    for i, p in enumerate(pts):
        loops.append(ring(p, tangent(i), *radii[i]))
    loops.append(ring(pts[-1] + t1 * rx1 * 0.55, t1, rx1 * 0.55, ry1 * 0.55))
    for a, b in zip(loops, loops[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for ring_, top in ((loops[0], False), (loops[-1], True)):
        c = sum((v.co for v in ring_), Vector()) / len(ring_)
        cv = bm.verts.new(c)
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((ring_[j], ring_[i], cv) if not top else (ring_[i], ring_[j], cv))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _subsurf(_mesh_obj(name, bm, coll), levels)


def superellipsoid(name, loc, size, e=2.6, rot=(0, 0, 0), coll=None, segs=64):
    """Esfera «cuadrada»: e = 2 es una esfera, más es un cubo redondeado."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=1)
    p = 2 / e
    for v in bm.verts:
        v.co = Vector(tuple(math.copysign(abs(c) ** p, c) for c in v.co))
    _place(bm, loc, size, rot)
    return smooth_shade(_mesh_obj(name, bm, coll))


# --- Calcas: piezas planas que siguen una superficie -------------------------------
#
# Ojos, cejas, bigote: se dibuja el contorno en 2D, se proyecta de frente sobre
# la cara (sigue su curva, no flota encima) y se le da grosor y un poco de
# abombado. Queda como una pieza incrustada, no como una bola pegada.

def _inside(pt, poly):
    x, y = pt
    ins = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1:
            ins = not ins
    return ins


def decal(name, outline, targets, at=(0, 0), scale=1.0, lift=0.002, thickness=0.006, dome=0.0,
          res=48, rot=0.0, coll=None, direction=(0, 1, 0)):
    """Calca: outline [(x, z), ...] (unidades de scale, centrada en 0), puesta
    en at = (x, z) sobre la parte delantera de targets. dome abomba el centro
    (en metros); rot gira el contorno en su plano."""
    targets = targets if isinstance(targets, (list, tuple)) else [targets]
    ca, sa = math.cos(rot), math.sin(rot)
    poly = [((x * ca - z * sa) * scale, (x * sa + z * ca) * scale) for x, z in outline]
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    step = max(x1 - x0, z1 - z0) / res
    # Rejilla dentro del contorno y el borde exacto, triangulados juntos.
    bm = bmesh.new()
    nx = int((x1 - x0) / step) + 1
    nz = int((z1 - z0) / step) + 1
    grid = {}
    for i in range(nx + 1):
        for k in range(nz + 1):
            p = (x0 + i * step, z0 + k * step)
            if _inside(p, poly):
                grid[(i, k)] = p
    # Triangulación del contorno + puntos interiores (Delaunay de mathutils).
    from mathutils.geometry import delaunay_2d_cdt
    border = []
    for (xa, za), (xb, zb) in zip(poly, poly[1:] + poly[:1]):
        n = max(1, int(math.hypot(xb - xa, zb - za) / step))
        for s in range(n):
            border.append((xa + (xb - xa) * s / n, za + (zb - za) * s / n))
    verts2 = [Vector(p) for p in border] + [Vector(p) for p in grid.values()]
    edges = [(i, (i + 1) % len(border)) for i in range(len(border))]
    out_v, _, out_f, _, _, _ = delaunay_2d_cdt(verts2, edges, [], 1, 1e-7)
    cx, cz = at
    radius = max(x1 - x0, z1 - z0) / 2
    mid = ((x0 + x1) / 2, (z0 + z1) / 2)
    placed = []
    for v in out_v:
        x, z = cx + v.x, cz + v.y
        best = None
        for t in targets:
            try:
                p, n = hit(t, (x, -2, z), direction)
            except ValueError:
                continue
            if best is None or p.y < best[0].y:
                best = (p, n)
        if best is None:
            raise ValueError(f"la calca {name} se sale de la superficie en ({x:.3f}, {z:.3f})")
        r = min(1.0, math.hypot(v.x - mid[0], v.y - mid[1]) / radius)
        placed.append(best[0] + best[1] * (lift + dome * (1 - r * r)))
    bmv = [bm.verts.new(p) for p in placed]
    for f in out_f:
        try:
            bm.faces.new([bmv[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Que la cara buena mire hacia fuera (hacia -Y, hacia la cámara).
    if sum(f.normal.y for f in bm.faces) > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    obj = _mesh_obj(name, bm, coll)
    s = obj.modifiers.new("grosor", "SOLIDIFY")
    s.thickness = thickness
    s.offset = -1
    s.use_even_offset = False
    apply_mods(obj)
    # Cantos suaves: una pasada de suavizado sólo en el borde.
    sm = obj.modifiers.new("suave", "SMOOTH")
    sm.iterations = 2
    sm.factor = 0.4
    apply_mods(obj)
    return smooth_shade(obj)


def band(name, z, half, rx, ry, e, cy=0.0, grow=0.012, segs=48):
    """Una tira alrededor de una sección (cinturón, cinta): la misma forma
    superelíptica que el cuerpo en esa altura, algo más gruesa, con cantos
    redondeados."""
    rings = []
    for dz, g in ((-half, 0.4), (-half * 0.75, 0.9), (0, 1.0), (half * 0.75, 0.9), (half, 0.4)):
        rings.append((z + dz, 0.0, cy, rx + grow * g, ry + grow * g, e))
    return loft(name, rings, segs=segs, levels=1)


def ellipse(rx, rz, n=40):
    return [(rx * math.cos(2 * math.pi * i / n), rz * math.sin(2 * math.pi * i / n)) for i in range(n)]


def stroke(length, w_in, w_out, arch=0.0, tilt=0.0, side=1, n=16):
    """Contorno de un trazo de pincel (cejas): de dentro (x < 0) a fuera, con
    un grosor que pasa de w_in a w_out, arqueado arch hacia arriba, girado
    tilt (positivo sube la punta de fuera) y con los extremos redondeados.
    side = -1 lo refleja para el lado izquierdo de la cara."""
    centre, normals, widths = [], [], []
    for i in range(n + 1):
        t = i / n
        x = -length / 2 + length * t
        z = arch * (1 - (2 * x / length) ** 2)
        dz = arch * (-8 * x / length ** 2)
        nl = math.hypot(1, dz)
        centre.append((x, z))
        normals.append((-dz / nl, 1 / nl))
        widths.append((w_in + (w_out - w_in) * t) / 2)
    top = [(c[0] + nm[0] * w, c[1] + nm[1] * w) for c, nm, w in zip(centre, normals, widths)]
    bot = [(c[0] - nm[0] * w, c[1] - nm[1] * w) for c, nm, w in zip(centre, normals, widths)]

    def cap(c, nm, w, forward):
        # Medio círculo que une arriba y abajo por el extremo.
        a0 = math.atan2(nm[1], nm[0])
        pts = []
        for k in range(1, 8):
            a = a0 - math.pi * k / 8 if forward else a0 + math.pi * k / 8
            pts.append((c[0] + math.cos(a) * w, c[1] + math.sin(a) * w))
        return pts

    outline = top + cap(centre[-1], normals[-1], widths[-1], True) + bot[::-1] + \
        [(p[0], p[1]) for p in cap(centre[0], (-normals[0][0], -normals[0][1]), widths[0], True)]
    ca, sa = math.cos(tilt), math.sin(tilt)
    outline = [(x * ca - z * sa, x * sa + z * ca) for x, z in outline]
    if side < 0:
        outline = [(-x, z) for x, z in reversed(outline)]
    return outline
