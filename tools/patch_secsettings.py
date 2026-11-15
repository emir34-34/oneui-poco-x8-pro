#!/usr/bin/env python3
"""SecSettings.apk yerinde dex yamasi (imza blogu korunur).
Sistem bolumundeki paketlerde PM skipVerify=true: v3 imza blogu dogrulanir, icerik ozeti dogrulanmaz.
classes3.dex sikistirilmamis saklandigi icin ayni boyutta bayt degisimi + dex SHA1/adler32 + zip CRC guncellemesi yeter.
Yamalar (o9-53 SecSettings, A066B):
  1) AudioRune.<clinit>: SUPPORT_SOUND_THEME = true (A06'da derleme sabiti false; Galaxy/Retro/Calm/Fun menusu)
  2) NfcSettings.populateViewForOrientation: anten konumu (-1) kontrolunu atla -> NFC ayrinti sayfasi cokmez
Kullanim: patch_secsettings.py girdi.apk cikti.apk
"""
import sys, zipfile, struct, zlib, hashlib
src, dst = sys.argv[1], sys.argv[2]
PATCHES = {'classes3.dex': [
    (0x2f3524, '7120230b10000a00', '1210000000000000'),  # equals(...)->move-result  =>  const/4 v0,1 ; nop x3
    (0x47b2ce, '39015e00', '285e0000'),                  # if-nez v1,+5e  =>  goto +5e ; nop
]}
d = bytearray(open(src, 'rb').read())
z = zipfile.ZipFile(src)
ec = d.rfind(b'PK\x05\x06'); cd = struct.unpack('<I', d[ec+16:ec+20])[0]
for name, plist in PATCHES.items():
    info = z.getinfo(name); assert info.compress_type == 0, 'dex sikistirilmis'
    lh = info.header_offset; n, e = struct.unpack('<HH', d[lh+26:lh+30]); off = lh+30+n+e
    dex = bytearray(d[off:off+info.file_size])
    for a, old, new in plist:
        cur = dex[a:a+len(old)//2].hex()
        if cur == new: continue
        assert cur == old, f'{name}@{a:#x}: beklenmeyen {cur}'
        dex[a:a+len(new)//2] = bytes.fromhex(new)
    dex[12:32] = hashlib.sha1(dex[32:]).digest()
    dex[8:12] = struct.pack('<I', zlib.adler32(bytes(dex[12:])))
    d[off:off+len(dex)] = dex
    crc = zlib.crc32(dex) & 0xffffffff
    d[lh+14:lh+18] = struct.pack('<I', crc)
    q = cd
    while d[q:q+4] == b'PK\x01\x02':
        nl, el, cl = struct.unpack('<HHH', d[q+28:q+34])
        if bytes(d[q+46:q+46+nl]) == name.encode(): d[q+16:q+20] = struct.pack('<I', crc)
        q += 46+nl+el+cl
open(dst, 'wb').write(d)
print('tamam', dst)
