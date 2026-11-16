#!/usr/bin/env python3
"""APK icinde bir girdiyi (or. classes3.dex) FARKLI BOYUTLU yenisiyle degistir; APK Signing Block'u oldugu gibi koru.

Neden: Samsung PM sistem bolumundeki paketlerde imza blogunu (sertifika + imzali veri) dogrular ama icerik ozetini
(chunked SHA-256) karsilastirmaz (bkz. tools/patch_secsettings.py). Bu yuzden icerik degisebilir; yalniz imza blogu
merkezi dizinin (CD) hemen onunde durmali ve EOCD'deki CD ofseti dogru olmali. platform imzasi/sharedUserId korunur.

Yapilan: yerel girdiler sirasiyla yeniden yazilir (degisen girdi STORED, 4 bayt hizali), sonra orijinal imza blogu,
sonra ofsetleri/CRC'leri guncellenmis CD ve EOCD. v1 (META-INF) imzasi dokunulmadan kalir (v3 varken kullanilmaz).
Kullanim: apk_swap_entry.py girdi.apk cikti.apk girdi_adi yeni_dosya [girdi_adi yeni_dosya ...]
"""
import sys, struct, zlib

src, dst = sys.argv[1], sys.argv[2]
repl = {sys.argv[i]: open(sys.argv[i + 1], 'rb').read() for i in range(3, len(sys.argv), 2)}
d = open(src, 'rb').read()

ec = d.rfind(b'PK\x05\x06')
cd_size, cd_off = struct.unpack('<II', d[ec + 12:ec + 20])
sb_magic = d[cd_off - 16:cd_off]
assert sb_magic == b'APK Sig Block 42', 'imza blogu yok'
sb_size = struct.unpack('<Q', d[cd_off - 24:cd_off - 16])[0]
sb_start = cd_off - (sb_size + 8)
assert struct.unpack('<Q', d[sb_start:sb_start + 8])[0] == sb_size, 'imza blogu boyutu tutarsiz'
sig_block = d[sb_start:cd_off]

# CD girdilerini oku
entries = []
q = cd_off
while d[q:q + 4] == b'PK\x01\x02':
    nl, el, cl = struct.unpack('<HHH', d[q + 28:q + 34])
    name = d[q + 46:q + 46 + nl].decode('utf-8')
    entries.append((q, 46 + nl + el + cl, name))
    q += 46 + nl + el + cl
assert q == cd_off + cd_size

out = bytearray()
new_cd = bytearray()
seen = set()
for q, clen, name in entries:
    cdh = bytearray(d[q:q + clen])
    lh = struct.unpack('<I', cdh[42:46])[0]
    n, e = struct.unpack('<HH', d[lh + 26:lh + 30])
    comp_size = struct.unpack('<I', d[lh + 18:lh + 22])[0] or struct.unpack('<I', cdh[20:24])[0]
    data_off = lh + 30 + n + e
    new_lh = len(out)
    if name in repl:
        seen.add(name)
        data = repl[name]
        crc = zlib.crc32(data) & 0xffffffff
        hdr = bytearray(d[lh:lh + 30 + n])
        hdr[6:8] = struct.pack('<H', struct.unpack('<H', hdr[6:8])[0] & ~0x0008)  # veri tanimlayici yok
        hdr[8:10] = struct.pack('<H', 0)  # STORED
        hdr[14:26] = struct.pack('<III', crc, len(data), len(data))
        pad = (-(new_lh + 30 + n)) % 4
        hdr[28:30] = struct.pack('<H', pad)
        out += hdr + b'\0' * pad + data
        cdh[8:10] = hdr[6:8]
        cdh[10:12] = struct.pack('<H', 0)
        cdh[16:28] = struct.pack('<III', crc, len(data), len(data))
    else:
        end = data_off + comp_size
        flags = struct.unpack('<H', d[lh + 6:lh + 8])[0]
        if flags & 0x0008:  # veri tanimlayici
            end += 16 if d[end:end + 4] == b'PK\x07\x08' else 12
        chunk = bytearray(d[lh:end])
        # STORED girdilerde hizalamayi koru (zipalign -p: .so 4096, digerleri 4)
        if struct.unpack('<H', chunk[8:10])[0] == 0:
            al = 4096 if name.endswith('.so') else 4
            pad = (-(new_lh + 30 + n)) % al
            if pad != e:
                chunk = chunk[:28] + struct.pack('<H', pad) + chunk[30:30 + n] + b'\0' * pad + chunk[30 + n + e:]
        out += chunk
    cdh[42:46] = struct.pack('<I', new_lh)
    new_cd += cdh
missing = set(repl) - seen
assert not missing, f'bulunamadi: {missing}'

new_sb_off = len(out)
out += sig_block
new_cd_off = len(out)
out += new_cd
eocd = bytearray(d[ec:])
eocd[12:20] = struct.pack('<II', len(new_cd), new_cd_off)
out += eocd
open(dst, 'wb').write(out)
print(f'tamam {dst}: {len(d)} -> {len(out)} bayt, imza blogu {new_sb_off:#x}, CD {new_cd_off:#x}')
