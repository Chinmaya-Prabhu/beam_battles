# Shared voxel tools for the art/voxel_pilot scripts (run inside Blender): greedy meshing and renders.
import math, numpy as np, bpy
from mathutils import Vector

def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

def greedy(g, own, chunk, cols, V, origin):
    """Faces of the voxels in `own == chunk`, culled against the WHOLE grid (no hidden faces at chunk seams).
    Grid axes are x, y(up), z in Roblox space; Blender gets (x, -z, y) so glTF comes out as Roblox axes."""
    verts, faces, fcol = [], [], []
    size = g.shape
    for ax in range(3):
        u, v = [a for a in range(3) if a != ax]
        for sgn in (1, -1):
            for s in range(size[ax]):
                cur = np.take(g, s, axis=ax)
                mine = np.take(own, s, axis=ax) == chunk
                if not mine.any():
                    continue
                n = s + sgn
                nb = np.take(g, n, axis=ax) if 0 <= n < size[ax] else np.zeros_like(cur)
                mask = np.where(mine & (nb == 0), cur, 0)
                done = np.zeros(mask.shape, dtype=bool)
                A, B = mask.shape
                for a, b in np.argwhere(mask):
                    if done[a, b]:
                        continue
                    c = mask[a, b]
                    w = 1
                    while b + w < B and mask[a, b + w] == c and not done[a, b + w]:
                        w += 1
                    h = 1
                    while a + h < A and (mask[a + h, b:b + w] == c).all() and not done[a + h, b:b + w].any():
                        h += 1
                    done[a:a + h, b:b + w] = True
                    q = []
                    for da, db in ((0, 0), (h, 0), (h, w), (0, w)):
                        t = [0, 0, 0]
                        t[ax] = s + (1 if sgn > 0 else 0); t[u] = a + da; t[v] = b + db
                        X = origin[0] + t[0] * V; Y = origin[1] + t[1] * V; Z = origin[2] + t[2] * V
                        q.append((X, -Z, Y))
                    # (x, y, z) -> (x, -z, y) is a proper rotation, so the grid's winding carries over: u x v
                    # points along +ax, except ax 1 (x cross z is -y)
                    if (sgn > 0) == (ax == 1):
                        q = q[::-1]
                    f = len(verts); verts += q; faces.append((f, f + 1, f + 2, f + 3)); fcol.append(cols[int(c)])
    return verts, faces, fcol

def mesh(name, verts, faces, fcol):
    """Welds the quads and adds every vertex lying on a quad's edge to that edge: no T-junctions, so no sparkle
    cracks along seams. Then triangulates."""
    import bmesh
    key = lambda p: tuple(round(a * 1000) for a in p)
    index, pts = {}, []
    for p in verts:
        k = key(p)
        if k not in index:
            index[k] = len(pts); pts.append(p)
    lines = {}
    for k in index:
        for ax in range(3):
            lines.setdefault((ax, k[(ax + 1) % 3], k[(ax + 2) % 3]), []).append(k[ax])
    for v in lines.values():
        v.sort()
    import bisect
    out = []
    for quad in faces:
        ks = [key(verts[q]) for q in quad]
        ring = []
        for e in range(4):
            a, b = ks[e], ks[(e + 1) % 4]
            ax = [t for t in range(3) if a[t] != b[t]][0]
            on = lines[(ax, a[(ax + 1) % 3], a[(ax + 2) % 3])]
            lo, hi = sorted((a[ax], b[ax]))
            mid = on[bisect.bisect_right(on, lo):bisect.bisect_left(on, hi)]
            if a[ax] > b[ax]:
                mid = mid[::-1]
            ring.append(a)
            for t in mid:
                w = list(a); w[ax] = t; ring.append(tuple(w))
        out.append([index[r] for r in ring])
    me = bpy.data.meshes.new(name); me.from_pydata(pts, [], out); me.update()
    a = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly, col in zip(me.polygons, fcol):
        for li in poly.loop_indices:
            a.data[li].color = (*col, 1)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces, ngon_method="EAR_CLIP", quad_method="SHORT_EDGE")
    bm.to_mesh(me); bm.free(); me.update()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob

def vcol_material(name="Voxel", emit=0, tint=(1, 1, 1)):
    m = bpy.data.materials.new(name); m.use_nodes = True
    t = m.node_tree; b = next(n for n in t.nodes if n.type == "BSDF_PRINCIPLED")
    at = t.nodes.new("ShaderNodeVertexColor"); at.layer_name = "Col"
    mix = t.nodes.new("ShaderNodeMixRGB"); mix.blend_type = "MULTIPLY"; mix.inputs[0].default_value = 1
    t.links.new(at.outputs[0], mix.inputs[1]); mix.inputs[2].default_value = (*tint, 1)
    t.links.new(mix.outputs[0], b.inputs["Base Color"]); b.inputs["Roughness"].default_value = 0.6
    if emit:
        t.links.new(mix.outputs[0], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = emit
    return m

def stage(ground=(0.13, 0.42, 0.12)):
    sc = bpy.context.scene
    sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
    sc.render.engine = "CYCLES"; sc.cycles.samples = 40; sc.cycles.use_denoising = False
    w = bpy.data.worlds.new("sky"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.68, 1.0, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 2.6; sun.data.color = (1, .95, .85); sun.data.angle = math.radians(4)
    sun.rotation_euler = (math.radians(52), 0, math.radians(35))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam

def shoot(sc, cam, path, loc, look, res=(1200, 800), lens=45):
    cam.location = loc; cam.data.lens = lens; cam.data.clip_end = 3000
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

def ground(z=0, color=(0.13, 0.42, 0.12)):
    bpy.ops.mesh.primitive_plane_add(size=900, location=(0, 0, z)); gr = bpy.context.object
    gm = bpy.data.materials.new("g"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*color, 1)
    gr.data.materials.append(gm); return gr

def export(path, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_vertex_color="ACTIVE", export_apply=True)
