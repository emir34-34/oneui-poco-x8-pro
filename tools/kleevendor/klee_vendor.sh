#!/system/bin/sh
# klee: Xiaomi vendor RIL yamaları (m26-m30: SMS fwk-ready, SMSC biçimi, MMS profil/protokol, gelen arama URC'leri).
# DSU yalnız system'i değiştirir; yamalı vendor kütüphaneleri /system/etc/klee_vendor'dan rild başlamadan önce bağlanır.
for f in /system/etc/klee_vendor/lib64/*.so; do
  t=/vendor/lib64/${f##*/}
  [ -f "$t" ] && mount -o bind "$f" "$t"
done
