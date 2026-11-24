#!/usr/bin/env python3
"""Builds a small sparse image that rewrites only the LP metadata of super for the other slot.

Two raw super images built by lpmake with the same partitions (names *_a vs *_b, same sizes, same
order) differ only in the first MiB (geometry + metadata). The output holds that first MiB as a RAW
chunk and DONT_CARE for the rest, so `fastboot flash super super.img` followed by
`fastboot flash super super_slot_a_meta.img` gives the slot A layout without a second 9 GB image.
(Xiaomi fastboot ROMs for this phone flash super in sparse pieces with DONT_CARE the same way.)

Usage: make_slot_meta_patch.py super_a.raw super_b.raw out.img
"""
import struct, sys

a_path, b_path, out = sys.argv[1:4]
MIB = 1 << 20
with open(a_path, 'rb') as a, open(b_path, 'rb') as b:
    head = a.read(MIB)
    assert head != b.read(MIB), 'first MiB identical: nothing to patch'
    while True:
        x, y = a.read(64 * MIB), b.read(64 * MIB)
        assert x == y, 'images differ after the first MiB: not only metadata'
        if not x:
            break
    size = a.seek(0, 2)
assert size % 4096 == 0
total, hb = size // 4096, MIB // 4096
with open(out, 'wb') as o:
    o.write(struct.pack('<IHHHHIIII', 0xed26ff3a, 1, 0, 28, 12, 4096, total, 2, 0))
    o.write(struct.pack('<HHII', 0xCAC1, 0, hb, 12 + MIB)); o.write(head)
    o.write(struct.pack('<HHII', 0xCAC3, 0, total - hb, 12))
print(f'{out}: {hb} blocks raw, {total - hb} blocks dont-care')
