# Voxel drop altar pilot (not used by the game). Run: blender -b --factory-startup --python altar.py
import sys, os, math, json
import numpy as np, bpy
OUT = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.expanduser("~/.claude/skills/fwjelaa-blender-modeling/scripts"))
V = 0.4                       # one voxel, studs: 3 layers = one BRICK tier, so the stand height matches the game
N, H = 50, 34                 # grid: 20 studs wide, 13.6 tall
EMPTY = 0
PAL = {                       # id: (mesh, colour)
    1: ("stone", (0.030, 0.034, 0.070)), 2: ("stone", (0.055, 0.060, 0.115)), 3: ("stone", (0.090, 0.098, 0.170)),
    4: ("stone", (0.150, 0.160, 0.250)), 5: ("stone", (0.330, 0.340, 0.430)),
    6: ("trim", (1, 1, 1)), 7: ("trim", (0.72, 0.72, 0.72)), 8: ("trim", (0.46, 0.46, 0.46)),
    9: ("glow", (1, 1, 1)),
}
g = np.zeros((N, N, H), dtype=np.int8)
def h(a, b, c):               # symmetric hash
    return ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 1023
def put(i, j, k, c):
    if 0 <= k < H:
        g[i, j, k] = c
def each():
    for i in range(N):
        for j in range(N):
            x, y = abs(i - N / 2 + .5), abs(j - N / 2 + .5)
            yield i, j, x, y
def oct_(x, y):               # a square with cut corners
    return max(x, y, (x + y) * 0.60)
def brick(x, y, k, base):     # chunky stone blocks with mortar shade, not noise
    row = k // 3
    bx = int((x + (row % 2) * 2.5) // 5); by = int((y + (row % 2) * 2.5) // 5)
    s = h(bx, by, row) % 3
    return base + (s if s < 2 else 0)
for i, j, x, y in each():
    d = oct_(x, y)
    for k in range(12):
        tier = k // 3
        half = (20, 17.5, 12.5, 8.75)[tier]
        if d <= half:
            edge = d > half - 1.2
            if tier == 0:
                c = 1 if k == 0 else brick(x, y, k, 1)
            elif tier == 1:
                c = brick(x, y, k, 2)
            elif tier == 2:
                c = (6 if edge else 3) if k == 8 else (7 if k == 7 else (8 if k == 6 else 3))
            else:
                c = 6 if (k == 9) else 2
                if k == 11:
                    c = 4
            put(i, j, k, c)
    # the top: a glowing ring and four rays (the fighter stands on this)
    if d <= 8.75:
        r = math.hypot(x, y)
        if 6.2 <= r <= 7.6:
            put(i, j, 11, 9)
        elif abs(x - y) < 0.6 and r < 6.2 and r > 2.2:
            put(i, j, 11, 6)
        elif r <= 2.2:
            put(i, j, 11, 6)
    # steps on all four sides
    for side in (x, y):
        other = y if side is x else x
        if other <= 7.5:
            if 20 <= side <= 22.5:
                for k in range(0, 2): put(i, j, k, 5 if k == 1 else 2)
            if 17.5 <= side < 20:
                for k in range(3, 5): put(i, j, k, 5 if k == 4 else 3)
            if 12.5 <= side < 17.5:
                for k in range(6, 8): put(i, j, k, 5 if k == 7 else 4)
    # corner pillars: slim, grounded, a glowing seam on the outer faces
    px, py = abs(x - 15), abs(y - 15)
    p = max(px, py)
    if p <= 3.5:
        for k in range(0, 18):
            w = 3.5 if k < 6 else (2.5 if k < 15 else 3.5)
            if p <= w:
                c = 6 if k in (5, 15, 17) else (7 if k == 16 else brick(x, y, k, 2))
                if 6 <= k < 15 and p > 1.6 and min(px, py) < 0.6 and (x > 15 or y > 15):
                    c = 9
                put(i, j, k, c)
    # a tall crystal over each pillar
    gem = (0.6, 1.6, 2.6, 2.6, 1.6, 1.6, 1.6, 0.6, 0.6, 0.6)  # a stepped gem, widest low down
    for n, w in enumerate(gem):
        if max(px, py) <= w:
            put(i, j, 20 + n, 9)

def greedy(ids):
    verts, faces, cols = [], [], []
    m = np.isin(g, ids)
    for ax in range(3):
        u, v = [a for a in range(3) if a != ax]
        size = g.shape
        for sgn in (1, -1):
            for s in range(size[ax]):
                cur = np.take(g, s, axis=ax)
                n = s + sgn
                nb = np.take(g, n, axis=ax) if 0 <= n < size[ax] else np.zeros_like(cur)
                cm = np.take(m, s, axis=ax)
                mask = np.where(cm & ~np.take(m, n, axis=ax) if 0 <= n < size[ax] else cm, cur, 0)
                done = np.zeros_like(mask, dtype=bool)
                A, B = mask.shape
                for a in range(A):
                    for b in range(B):
                        c = mask[a, b]
                        if c == 0 or done[a, b]:
                            continue
                        w = 1
                        while b + w < B and mask[a, b + w] == c and not done[a, b + w]:
                            w += 1
                        hh = 1
                        while a + hh < A and (mask[a + hh, b:b + w] == c).all() and not done[a + hh, b:b + w].any():
                            hh += 1
                        done[a:a + hh, b:b + w] = True
                        p = [0, 0, 0]
                        p[ax] = s + (1 if sgn > 0 else 0)
                        q = []
                        for da, db in ((0, 0), (hh, 0), (hh, w), (0, w)):
                            t = list(p); t[u] = a + da; t[v] = b + db
                            q.append(((t[0] - N / 2) * V, (t[1] - N / 2) * V, t[2] * V))
                        if (sgn > 0) == (ax == 1):
                            q = q[::-1]
                        f = len(verts); verts += q; faces.append((f, f + 1, f + 2, f + 3))
                        cols += [PAL[int(c)][1]] * 4
    return verts, faces, cols

def mesh(name, ids):
    v, f, c = greedy(ids)
    import bmesh
    key = lambda p: tuple(round(a / V) for a in p)
    index, pts = {}, []
    for p in v:
        kk = key(p)
        if kk not in index:
            index[kk] = len(pts); pts.append(p)
    # every vertex lying on a quad's edge joins that edge, so the mesh has no T-junctions and closes up
    lines = {}
    for kk in index:
        for ax in range(3):
            lines.setdefault((ax, kk[(ax + 1) % 3], kk[(ax + 2) % 3]), []).append(kk[ax])
    faces, fcol = [], []
    for fi, quad in enumerate(f):
        ring = []
        ks = [key(v[q]) for q in quad]
        for e in range(4):
            a, b = ks[e], ks[(e + 1) % 4]
            ax = [t for t in range(3) if a[t] != b[t]][0]
            on = lines[(ax, a[(ax + 1) % 3], a[(ax + 2) % 3])]
            lo, hi = sorted((a[ax], b[ax]))
            mid = sorted(t for t in on if lo < t < hi)
            if a[ax] > b[ax]:
                mid.reverse()
            ring.append(a)
            for t in mid:
                w = list(a); w[ax] = t; ring.append(tuple(w))
        faces.append([index[r] for r in ring]); fcol.append(c[quad[0]])
    me = bpy.data.meshes.new(name); me.from_pydata(pts, [], faces); me.update()
    a = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly, col in zip(me.polygons, fcol):
        for li in poly.loop_indices:
            a.data[li].color = (*col, 1)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces, ngon_method="EAR_CLIP", quad_method="SHORT_EDGE")
    bm.to_mesh(me); bm.free(); me.update()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob, len(me.polygons) / 2

def mat(name, tint, emit=0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    t = m.node_tree; b = next(n for n in t.nodes if n.type == "BSDF_PRINCIPLED")
    at = t.nodes.new("ShaderNodeVertexColor"); at.layer_name = "Col"
    mix = t.nodes.new("ShaderNodeMixRGB"); mix.blend_type = "MULTIPLY"; mix.inputs[0].default_value = 1
    t.links.new(at.outputs[0], mix.inputs[1]); mix.inputs[2].default_value = (*tint, 1)
    t.links.new(mix.outputs[0], b.inputs["Base Color"]); b.inputs["Roughness"].default_value = 0.55
    if emit:
        t.links.new(mix.outputs[0], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = emit
    return m

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
parts = {}
stats = {}
for name, ids in (("AltarStone", [1, 2, 3, 4, 5]), ("AltarTrim", [6, 7, 8]), ("AltarGlow", [9])):
    parts[name], q = mesh(name, ids); stats[name] = {"quads": q, "tris": q * 2}
print("MIRROR", bool((g == g[::-1, :, :]).all()), bool((g == g[:, ::-1, :]).all()))
print("STATS", json.dumps(stats), "total tris", sum(s["tris"] for s in stats.values()), "voxels", int((g > 0).sum()))

TIERS = {"Bronze": (0.80, 0.45, 0.18), "Gold": (1.0, 0.70, 0.12), "Diamond": (0.35, 0.85, 1.0), "Celestial": (1.0, 0.40, 0.85)}
sc = bpy.context.scene
sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
sc.render.engine = "CYCLES"; sc.cycles.samples = 48; sc.cycles.use_denoising = False
w = bpy.data.worlds.new("sky"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.68, 1.0, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
sc.world = w
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 2.6; sun.data.color = (1, .95, .85); sun.data.angle = math.radians(4); sun.rotation_euler = (math.radians(52), 0, math.radians(35))
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0)); gr = bpy.context.object
gm = bpy.data.materials.new("g"); gm.use_nodes = True
next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.13, 0.42, 0.12, 1); gr.data.materials.append(gm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
def shoot(path, loc, look, res=(1200, 800), lens=45):
    cam.location = loc; cam.data.lens = lens
    d = np.array(look) - np.array(loc)
    from mathutils import Vector
    cam.rotation_euler = Vector(d.tolist()).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
def tint(obs, name):
    for o in obs:
        o.data.materials.clear()
        n = o.name.split(".")[0]
        c = TIERS[name]
        o.data.materials.append(mat(n + name, (1.0, 1.0, 1.0) if "Stone" in n else c, 1.15 if "Glow" in n else 0))
base = list(parts.values())
tint(base, "Gold")
shoot(OUT + "/altar_hero.png", (24, -32, 20), (0, 0, 4))
# the current altar, from Play.altar's numbers, for a fair comparison in the same light
def box(x, y, z, sx, sy, sz, col):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2)); o = bpy.context.object
    o.scale = (sx, sy, sz); m = bpy.data.materials.new("c"); m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*col, 1)
    o.data.materials.append(m); return o
LG, GR, TAN, GD = (0.55, 0.55, 0.55), (0.32, 0.32, 0.33), (0.72, 0.6, 0.42), (1.0, 0.7, 0.12)
B = 1.2
cur = [box(0, 0, 0, 16, 16, B, GR), box(0, 0, B, 14, 14, B, LG), box(0, 0, 2 * B, 10, 10, B, GD), box(0, 0, 3 * B, 7, 7, B, TAN)]
for dx, dy in ((0, -8.5), (0, 8.5), (-8.5, 0), (8.5, 0)):
    cur.append(box(dx, dy, 0, 6 if dy else 1, 1 if dy else 6, B, LG))
for cx in (-6, 6):
    for cy in (-6, 6):
        cur += [box(cx, cy, 2 * B, 2, 2, 3 * B, GD), box(cx, cy, 5 * B, 2, 2, 0.4, (1, .78, .2)), box(cx, cy, 5 * B + 0.4, 2.4, 2.4, 0.8, (1, .78, .2))]
for o in cur: o.location.x -= 13
for o in base: o.location.x = 13
shoot(OUT + "/altar_before_after.png", (0, -52, 26), (0, 0, 4), (1400, 700), 50)
for o in cur: bpy.data.objects.remove(o)
for o in base: o.location.x = 0
for o in base: o.location.x = -400
copies = []
for idx, name in enumerate(("Bronze", "Diamond", "Celestial")):
    grp = []
    for o in base:
        c = o.copy(); c.data = o.data.copy(); c.name = o.name + "." + name; sc.collection.objects.link(c); c.location.x = -22 + 22 * idx; grp.append(c)
    tint(grp, name); copies += grp
tint(base, "Gold")
shoot(OUT + "/altar_tiers.png", (0, -84, 40), (0, 0, 4), (1400, 620), 50)
for c in copies: bpy.data.objects.remove(c)
for o in base: o.location.x = 0
try:
    import fwjelaa_bpy as lf
    for o in base:
        p, fails, rep = lf.gate(o, "medium", symmetric="X")
        print("GATE", o.name, p, fails)
except Exception as e:
    print("GATEERR", repr(e))
bpy.ops.object.select_all(action="DESELECT")
for o in base: o.select_set(True)
bpy.context.view_layer.objects.active = base[0]
bpy.ops.export_scene.gltf(filepath=OUT + "/altar_pilot.glb", use_selection=True, export_vertex_color="ACTIVE", export_apply=True)
print("DONE")
