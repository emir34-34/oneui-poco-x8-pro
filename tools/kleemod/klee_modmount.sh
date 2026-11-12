#!/system/bin/sh
# klee modül yükleyici (GELİŞTİRME ARACI; Slot A öncesi kaldırılacak).
# post-fs-data'da, zygote'tan önce çalışır. /data/local/tmp/klee_mod/mod.img (erofs, file_contexts etiketli)
# içindeki mod.list'te yazan her klasörü overlayfs ile orijinalin üstüne bindirir.
# Açılış döngüsü koruması: modülle başlayan açılış boot_completed'a ulaşmazsa sonraki açılışta modül atlanır.
D=/data/local/tmp/klee_mod; M=/mnt/klee_mod; LOG=$D/last.log
[ -d $D ] || exit 0
exec > $LOG 2>&1
echo "klee_modmount $(cat /proc/uptime)"
if [ -e $D/disable ]; then echo "disable dosyasi var, atlandi"; exit 0; fi
if [ -e $D/pending ]; then
  echo "onceki acilis tamamlanmadi -> modul devre disi"; mv $D/pending $D/disable; exit 0
fi
[ -f $D/mod.img ] || { echo "mod.img yok"; exit 0; }
mkdir -p $M
L=$(losetup -f --show -r $D/mod.img) || { echo "losetup hata"; exit 0; }
mount -t erofs -o ro $L $M || { echo "erofs mount hata"; losetup -d $L; exit 0; }
[ -f $M/mod.list ] || { echo "mod.list yok"; umount $M; losetup -d $L; exit 0; }
cat $M/mod.prop 2>/dev/null
touch $D/pending
while read -r p; do
  case "$p" in ''|\#*) continue;; esac
  t="/$p"; s="$M/$p"
  if [ ! -d "$t" ] || [ ! -d "$s" ]; then echo "ATLA $p (hedef/kaynak klasor yok)"; continue; fi
  if mount -t overlay overlay -o "ro,lowerdir=$s:$t" "$t"; then echo "OK $p"; else echo "HATA $p"; fi
done < $M/mod.list
echo "bitti $(cat /proc/uptime)"
