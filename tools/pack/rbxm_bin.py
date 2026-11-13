"""Binary .rbxm helpers. Rojo only reads model files with ONE top-level instance; Toolbox exports often hold several
(a body plus loose morph models). wrap() puts them all under one new Folder so Rojo can convert the file."""
import struct

import lz4.block


def chunks(data):
    i = 32
    while i < len(data):
        name = data[i:i + 4]
        cl, ul = struct.unpack_from("<II", data, i + 4)
        i += 16
        if cl == 0:
            body = data[i:i + ul]
            i += ul
        else:
            raw = data[i:i + cl]
            i += cl
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                import zstandard

                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ul)
            else:
                body = lz4.block.decompress(raw, uncompressed_size=ul)
        yield name, body
        if name == b"END\x00":
            break


def _ints(b, n):
    out = []
    for k in range(n):
        v = (b[k] << 24) | (b[n + k] << 16) | (b[2 * n + k] << 8) | b[3 * n + k]
        out.append((v >> 1) ^ -(v & 1))
    return out


def _refs(b, n):
    acc, out = 0, []
    for v in _ints(b, n):
        acc += v
        out.append(acc)
    return out


def _enc_refs(vals):
    deltas, prev = [], 0
    for v in vals:
        deltas.append(v - prev)
        prev = v
    z = [((v << 1) ^ (v >> 31)) & 0xFFFFFFFF for v in deltas]
    return bytes([(x >> 24) & 255 for x in z] + [(x >> 16) & 255 for x in z] + [(x >> 8) & 255 for x in z] + [x & 255 for x in z])


def _chunk(name, body):
    return name + struct.pack("<III", 0, len(body), 0) + body


def wrap(src, dst):
    """Writes `src` to `dst` with every top-level instance moved under one new Folder (or Configuration, if the
    file already uses Folder) named "Pack"."""
    data = open(src, "rb").read()
    head = bytearray(data[:32])
    ncls, ninst = struct.unpack_from("<ii", head, 16)
    cs = list(chunks(data))
    classnames, maxref = [], -1
    for n, b in cs:
        if n == b"INST":
            L, = struct.unpack_from("<I", b, 4)
            classnames.append(b[8:8 + L].decode())
            p = 8 + L + 1
            c, = struct.unpack_from("<I", b, p)
            maxref = max(maxref, *_refs(b[p + 4:p + 4 + 4 * c], c))
    cls = "Folder" if "Folder" not in classnames else "Configuration"
    assert cls not in classnames
    cid, ref = ncls, maxref + 1
    inst = struct.pack("<II", cid, len(cls)) + cls.encode() + b"\x00" + struct.pack("<I", 1) + _enc_refs([ref])
    prop = struct.pack("<II", cid, 4) + b"Name\x01" + struct.pack("<I", 4) + b"Pack"
    names = [n for n, _ in cs]
    last_i = max(i for i, n in enumerate(names) if n == b"INST")
    last_p = max(i for i, n in enumerate(names) if n == b"PROP")
    out = []
    for i, (n, b) in enumerate(cs):
        if n == b"PRNT":
            c, = struct.unpack_from("<I", b, 1)
            ch, pa = _refs(b[5:5 + 4 * c], c), _refs(b[5 + 4 * c:5 + 8 * c], c)
            pa = [ref if p == -1 else p for p in pa]
            ch.append(ref)
            pa.append(-1)
            b = b"\x00" + struct.pack("<I", len(ch)) + _enc_refs(ch) + _enc_refs(pa)
        out.append(_chunk(n, b))
        if i == last_i:
            out.append(_chunk(b"INST", inst))
        if i == last_p:
            out.append(_chunk(b"PROP", prop))
    struct.pack_into("<ii", head, 16, ncls + 1, ninst + 1)
    open(dst, "wb").write(bytes(head) + b"".join(out))
