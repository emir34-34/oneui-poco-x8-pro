#!/usr/bin/env python3
"""Yeniden derlenmis (apktool b + zipalign) bir APK'ya ORIJINAL APK'nin imza blogunu (APK Sig Block 42) takar.

Neden: sistem bolumundeki paketlerde PM imza blogundaki sertifikayi okur, icerik ozetini karsilastirmaz
(bkz. apk_swap_entry.py). apk_swap_entry yalniz var olan girdileri degistirir; yeni kaynak (res/raw/...) eklemek
icin resources.arsc yeniden derlenmeli -> bu arac yeni APK'nin tum girdilerini alip imza blogunu CD'nin onune koyar.
Kullanim: apk_graft_sig.py yeni_hizali.apk orijinal.apk cikti.apk
"""
import sys, struct

new, orig, dst = sys.argv[1:4]
o = open(orig, 'rb').read()
ec = o.rfind(b'PK\x05\x06')
cd_off = struct.unpack('<I', o[ec + 16:ec + 20])[0]
assert o[cd_off - 16:cd_off] == b'APK Sig Block 42', 'orijinalde imza blogu yok'
sb_size = struct.unpack('<Q', o[cd_off - 24:cd_off - 16])[0]
sig = o[cd_off - (sb_size + 8):cd_off]

d = open(new, 'rb').read()
ec = d.rfind(b'PK\x05\x06')
cd_size, cd_off = struct.unpack('<II', d[ec + 12:ec + 20])
assert d[cd_off - 16:cd_off] != b'APK Sig Block 42', 'yeni APK zaten imzali'
body, cd, eocd = d[:cd_off], d[cd_off:cd_off + cd_size], bytearray(d[ec:])
eocd[16:20] = struct.pack('<I', len(body) + len(sig))  # CD girdilerinin yerel ofsetleri degismez
open(dst, 'wb').write(body + sig + cd + eocd)
print(f'tamam {dst}: {len(body + sig + cd + eocd)} bayt, imza blogu {len(body):#x}')
