#!/usr/bin/env python3
"""Minimal payload.bin extractor (full OTA). Usage: payx.py payload.bin outdir part1 [part2 ...]"""
import sys, struct, lzma, bz2, os
try:
    import zstandard
except ImportError:
    zstandard = None

def varint(b, i):
    r = s = 0
    while True:
        c = b[i]; i += 1
        r |= (c & 0x7f) << s; s += 7
        if c < 0x80: return r, i

def fields(b):
    i = 0; out = []
    while i < len(b):
        k, i = varint(b, i); f, t = k >> 3, k & 7
        if t == 0: v, i = varint(b, i)
        elif t == 2:
            l, i = varint(b, i); v = b[i:i + l]; i += l
        elif t == 1: v = b[i:i + 8]; i += 8
        elif t == 5: v = b[i:i + 4]; i += 4
        else: raise ValueError(t)
        out.append((f, v))
    return out

pay, outdir, want = sys.argv[1], sys.argv[2], set(sys.argv[3:])
fh = open(pay, 'rb')
hdr = fh.read(24)
assert hdr[:4] == b'CrAU'
ver, msize = struct.unpack('>QQ', hdr[4:20]); sigsize = struct.unpack('>I', hdr[20:24])[0]
man = fh.read(msize)
base = 24 + msize + sigsize
bs = 4096
for f, v in fields(man):
    if f == 3: bs = v
os.makedirs(outdir, exist_ok=True)
for f, v in fields(man):
    if f != 13: continue
    pf = fields(v); name = [x for k, x in pf if k == 1][0].decode()
    if name not in want: continue
    size = 0
    for k, x in pf:
        if k == 7:
            for k2, x2 in fields(x):
                if k2 == 1: size = x2
    o = open(os.path.join(outdir, name + '.img'), 'wb'); o.truncate(size)
    for k, x in pf:
        if k != 8: continue
        op = dict(); ext = []
        for k2, x2 in fields(x):
            if k2 == 6: ext.append({a: b for a, b in fields(x2)})
            else: op[k2] = x2
        typ = op.get(1, 0); off = op.get(2, 0); ln = op.get(3, 0)
        fh.seek(base + off); d = fh.read(ln)
        if typ == 0: pass
        elif typ == 1: d = bz2.decompress(d)
        elif typ == 8: d = lzma.decompress(d)
        elif typ == 14: d = zstandard.ZstdDecompressor().decompressobj().decompress(d)
        elif typ in (6, 7): d = None
        else: raise SystemExit(f'{name}: unsupported op {typ}')
        if d is None: continue
        pos = 0
        for e in ext:
            n = e.get(2, 0) * bs
            o.seek(e.get(1, 0) * bs); o.write(d[pos:pos + n]); pos += n
    o.close(); print(name, size)
