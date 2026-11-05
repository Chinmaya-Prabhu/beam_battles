# Voxel clash pad (not used by the game yet): same look as the altar, same stand height as Play.clashPad (3.05).
import sys, os, math, json
OUT = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, OUT)
import numpy as np, bpy, vox
V = 0.4
N, H = 32, 24
ORIGIN = (-N * V / 2, -0.15, -N * V / 2)     # -0.15: layer 7's top lands on 3.05 exactly
PAL = [None, (0.030, 0.034, 0.070), (0.055, 0.060, 0.115), (0.090, 0.098, 0.170), (0.150, 0.160, 0.250), (0.330, 0.340, 0.430),
       (1, 1, 1), (0.72, 0.72, 0.72), (1, 1, 1), (0.42, 0.42, 0.42)]
STONE, TRIM, GLOW = 1, 2, 3
KIND = {1: STONE, 2: STONE, 3: STONE, 4: STONE, 5: STONE, 6: TRIM, 7: TRIM, 8: GLOW, 9: GLOW}
g = np.zeros((N, H, N), dtype=np.int16)
def hsh(a, b, c): return ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 1023
for i in range(N):
    for j in range(N):
        x, z = (i - N / 2 + .5) * V, (j - N / 2 + .5) * V
        r = math.hypot(x, z); a = abs(x)
        # dais (radii in studs, from Play.clashPad)
        for k in range(8):
            R = 5.25 if k < 3 else (4.5 if k < 6 else (4.1 if k == 6 else 3.8))
            if r <= R:
                blk = hsh(int((abs(x) + (k // 3) * .8) // 1.6), int((z + 9 + (k // 3) * .8) // 1.6), k // 3) % 3
                c = (1 + (blk == 1)) if k < 3 else (2 + (blk == 1))
                if k == 6: c = 6
                if k == 7:
                    c = 4
                    if r >= 3.3: c = 8                     # glowing rim
                    elif r <= 0.95: c = 8                  # the seal
                    elif 2.1 <= r <= 2.7 and (min(a, abs(z)) < 0.45 or abs(a - abs(z)) < 0.5): c = 9   # eight rune strokes
                    elif r < 3.3: c = 3
                g[i, k, j] = c
        # the front step, toward the opponent (-Z)
        if a <= 2.1 and -6.2 <= z < -4.6:
            for k in range(0, 3): g[i, k, j] = 5 if k == 2 else 2
        if a <= 1.6 and -5.1 <= z < -3.8:
            for k in range(3, 6): g[i, k, j] = 5 if k == 5 else 3
        # two slim pillars beside the fighter (never behind: the clash camera sits there)
        for sx in (-1, 1):
            p = max(abs(x - sx * 4.3), abs(z - 0.8))
            if p <= 0.8:
                for k in range(3, 18):
                    w = 0.8 if k in (3, 4, 15, 16, 17) else 0.4
                    if p <= w:
                        g[i, k, j] = 6 if k in (4, 15, 17) else (7 if k in (3, 16) else 2)
            # a small gem over it
            gem = (0.2, 0.6, 0.6, 0.2, 0.2)
            for n, w in enumerate(gem):
                if p <= w: g[i, 19 + n, j] = 8
print("mirror x", bool((g == g[::-1]).all()), "top layer y", ORIGIN[1] + 8 * V)
kind = np.vectorize(lambda c: KIND.get(int(c), 0))(g).astype(np.int8)
cols = [None] + [c for c in PAL[1:]]
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
obs, tris = {}, {}
for name, k in (("PadStone", STONE), ("PadTrim", TRIM), ("PadGlow", GLOW)):
    v, f, c = vox.greedy(g, kind, k, cols, V, ORIGIN)
    obs[name] = vox.mesh(name, v, f, c); tris[name] = len(obs[name].data.polygons)
print("STATS", tris, sum(tris.values()))
vox.export(OUT + "/pad_pilot.glb", list(obs.values()))
ys = np.nonzero(g.any(axis=(1, 2)))[0]
xs = np.nonzero(g.any(axis=(0, 1)))[0]
print("bbox z", ORIGIN[2] + xs.min() * V, ORIGIN[2] + (xs.max() + 1) * V, "y", ORIGIN[1] + ys.min() * V, ORIGIN[1] + (ys.max() + 1) * V)
# with the altar, at the game's spacing
sc, cam = vox.stage()
vox.ground(0)
BLUE, RED, GOLD = (0.06, 0.30, 1.0), (1.0, 0.08, 0.06), (1.0, 0.70, 0.12)
def dress(o, tint):
    o.data.materials.clear()
    n = o.name
    if "Stone" in n: o.data.materials.append(vox.vcol_material("s"))
    elif "Trim" in n: o.data.materials.append(vox.vcol_material("t", 0, GOLD))
    else: o.data.materials.append(vox.vcol_material("g", 1.15, tint))
pair = []
for side, x, rot, tint in ((1, -17, -90, BLUE), (2, 17, 90, RED)):
    for o in obs.values():
        c = o.copy(); c.data = o.data.copy(); c.name = o.name + str(side); sc.collection.objects.link(c)
        c.location = (x, 0, 0); c.rotation_euler = (0, 0, math.radians(rot)); dress(c, tint); pair.append(c)
for o in obs.values(): bpy.data.objects.remove(o)
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=OUT + "/altar_pilot.glb")
for o in set(bpy.data.objects) - before:
    if o.type == "MESH":
        o.data.color_attributes[0].name = "Col"; dress(o, GOLD)
vox.shoot(sc, cam, OUT + "/pad_with_altar.png", (0, -58, 26), (0, 0, 4), (1400, 700), 45)
vox.shoot(sc, cam, OUT + "/pad_close.png", (-30, -17, 11), (-17, 0, 3.5), (1100, 750), 40)
print("DONE")
