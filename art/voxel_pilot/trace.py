# Traces the real brick builds (dumped from Studio into src/) into voxels: Colosseum, Summit and each zone's heroes.
# Zones are traced in their own frame, so straight walls stay straight. Run: blender -b --factory-startup --python trace.py
import sys, os, json, glob
OUT = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, OUT)
import numpy as np, bpy, vox
# Voxel size per piece: chunkier on the big plain structures keeps triangles at or under the bricks they replace.
SIZES = {"Colosseum": 0.8, "WalledHero": 0.8, "BlossomHero": 0.6, "Summit": 0.6}
CENTERS = {"BlossomHero": (708, 24, 496), "NinjaHero": (-708, 24, 496), "PirateHero": (708, 24, -496), "WalledHero": (-708, 24, -496)}
FILES = {"Colosseum": "colo_", "Summit": "summit_", "BlossomHero": "BlossomHero_", "NinjaHero": "NinjaHero_",
         "PirateHero": "PirateHero_", "WalledHero": "WalledHero_"}
JADE, JADE_DARK, JADE_LIGHT = (46, 156, 96), (24, 104, 64), (104, 196, 124)
MAX_QUADS = 6000  # about 12-17K triangles after the seams are welded: under Roblox's 20K per mesh
def rgb(p): return tuple(round(x * 255) for x in p["c"])
# RULE (VoxelKit.trace does the same): tagged parts, Neon and invisible parts stay as they are, unbaked.
def live(p): return bool(p["g"]) or p["t"] > 0.5 or p["m"] == "Neon"
def frame(piece):
    if piece not in CENTERS:
        return np.zeros(3), np.eye(3)
    c = np.array(CENTERS[piece], float); f = np.array([-c[0], 0, -c[2]]); f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r); u = np.cross(r, f)
    return c, np.stack([r, u, -f], axis=1)
sc, cam = vox.stage()
mat = vox.vcol_material()
result = {}
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FILES)
for piece in only:
    V = SIZES.get(piece, 0.4)
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        bpy.data.objects.remove(o)
    P = []
    for f in sorted(glob.glob(f"{OUT}/src/{FILES[piece]}[0-9]*.json")):
        P += json.load(open(f))
    # (The round ring wall stays brick: as voxels its curve alone was about 100K triangles.)
    P = [p for p in P if p["p"] != "RingWall"]
    baked = []
    for p in P:
        if piece == "Summit":
            if p["p"] == "Body" and p["s"] == "Block" and p["z"][0] < 0.3 and rgb(p) in (JADE, JADE_LIGHT):
                continue  # the angled flank scales: noise as voxels
            if p["p"] == "Body" and p["z"][0] > 1.5 and p["z"][2] > 1 and rgb(p) == JADE_DARK:
                p["c"] = [x / 255 for x in JADE]
        if not live(p):
            baked.append(p)
    fc, FR = frame(piece)
    parts = []
    for p in baked:
        R = np.array(p["f"][3:12]).reshape(3, 3); c = np.array(p["f"][:3])
        parts.append((FR.T @ (c - fc), FR.T @ R, np.maximum(np.array(p["z"]) / 2, V * 0.55), p))
    lo = np.full(3, 1e9); hi = -lo
    for c, R, h, p in parts:
        e = np.abs(R) @ h; lo = np.minimum(lo, c - e); hi = np.maximum(hi, c + e)
    origin = np.floor(lo / V) * V - V
    dims = np.ceil((hi - origin) / V).astype(int) + 2
    g = np.zeros(dims, dtype=np.int16)
    cols, colid = [None], {}
    def cid(c):
        k = tuple(round(x * 32) for x in c)
        if k not in colid:
            colid[k] = len(cols); cols.append(vox.lin(c))
        return colid[k]
    for c, R, hh, p in parts:
        e = np.abs(R) @ hh
        a = np.maximum(np.floor((c - e - origin) / V).astype(int), 0)
        b = np.minimum(np.ceil((c + e - origin) / V).astype(int) + 1, dims)
        xs, ys, zs = [origin[i] + (np.arange(a[i], b[i]) + .5) * V for i in range(3)]
        X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
        L = (np.stack([X, Y, Z], -1) - c) @ R
        s = p["s"]
        if s == "Ball":
            ins = ((L / hh) ** 2).sum(-1) <= 1
        elif s == "Cylinder":
            ins = (np.abs(L[..., 0]) <= hh[0]) & ((L[..., 1] / hh[1]) ** 2 + (L[..., 2] / hh[2]) ** 2 <= 1)
        else:
            ins = (np.abs(L) <= hh).all(-1)
            if s == "WedgePart":
                ins &= (L[..., 1] + hh[1]) / (2 * hh[1]) <= (L[..., 2] + hh[2]) / (2 * hh[2]) + 0.02
        g[a[0]:b[0], a[1]:b[1], a[2]:b[2]][ins] = cid(p["c"])
    obs = []
    def emit(a, b):
        if not g[a[0]:b[0], a[1]:b[1], a[2]:b[2]].any():
            return
        pa = np.maximum(np.array(a) - 1, 0); pb = np.minimum(np.array(b) + 1, dims)
        sub = g[pa[0]:pb[0], pa[1]:pb[1], pa[2]:pb[2]]
        own = np.zeros(sub.shape, dtype=np.int8)
        ia, ib = np.array(a) - pa, np.array(b) - pa
        own[ia[0]:ib[0], ia[1]:ib[1], ia[2]:ib[2]] = 1
        v, f, c = vox.greedy(sub, own, 1, cols, V, origin + pa * V)
        if len(f) > MAX_QUADS:
            ax = int(np.argmax(np.array(b) - np.array(a))); mid = (a[ax] + b[ax]) // 2
            b1 = list(b); b1[ax] = mid; a2 = list(a); a2[ax] = mid
            emit(a, b1); emit(a2, b); return
        if not f:
            return
        o = vox.mesh(f"{piece}{len(obs) + 1}", v, f, c); o.data.materials.append(mat); obs.append(o)
        assert len(o.data.polygons) < 20000, (o.name, len(o.data.polygons))
    emit([0, 0, 0], list(dims))
    tris = sum(len(o.data.polygons) for o in obs)
    print("PIECE", piece, "parts", len(P), "baked", len(baked), "dims", dims.tolist(), "meshes", len(obs), "tris", tris, flush=True)
    # one picture of the piece, from the side players mostly see
    c = (lo + hi) / 2; d = float(max(hi - lo))
    gr = vox.ground(float(lo[1]) - 0.2)
    look = (float(c[0]), float(-c[2]), float(c[1]) - d * 0.05)
    vox.shoot(sc, cam, f"{OUT}/hero_{piece}.png", (look[0] + d * .55, look[1] - d * 1.05, look[2] + d * .62), look, (800, 560), 40)
    bpy.data.objects.remove(gr)
    vox.export(f"{OUT}/{piece}.glb", obs)
print("DONE")
