#!/system/bin/sh
# Logger v5. /metadata/oneui_debug halka; ADB'yi bu DSU'da açık tutar; uyku/uyanma ve ses satırlarını da yazar.
# --- klee m4 (modül, root, oneuidbg) ---
# 1) AOD arka ışığı: KAPALI->DOZE geçişinde arka ışık 0 kalıyor. DOZE'da 0 görülürse AOD seviyesini (125/16383) yaz; çekirdek kaydını da topla.
( B=/sys/devices/platform/mtk-leds/leds/lcd-backlight/brightness; L=125; O=/data/local/tmp/klee_mod/aodbl.log; prev=""
  while :; do
    s=$(getprop debug.tracing.screen_state)
    if [ "$s" = 3 ] || [ "$s" = 4 ]; then
      if [ "$prev" != 3 ] && [ "$prev" != 4 ]; then
        echo "$(date +%T.%N | cut -c1-12) DOZE basladi bl=$(cat $B)" >> $O
        : # m6: yazma kaldirildi (services.jar OFF->ON->DOZE duzeltmesi); yalniz kayit
      fi
    elif [ "$prev" = 3 ] || [ "$prev" = 4 ]; then
      { echo "$(date +%T.%N | cut -c1-12) DOZE bitti s=$s"; dmesg | grep -E "lcm_setbacklight|panel_doze|lcm_panel_poweron" | tail -8; } >> $O
    fi
    chmod 0666 $O 2>/dev/null; prev=$s; sleep 0.15
  done ) &
# 2) Parmak izi konum dosyası testi: yalnız özel ad alanında; yayılma kapatılamazsa HİÇ çalışmaz.
( P=/data/local/tmp/klee_mod/probe; mkdir -p $P
  while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done; sleep 15
  unshare -m sh -c '
    mount --make-rprivate / || { echo RPRIVATE_FAIL; exit 1; }
    mkdir -p /dev/klee_sc && mount --bind /sys/class /dev/klee_sc && mount --make-private /dev/klee_sc && mount -t tmpfs -o mode=0755 klee_sc /sys/class && echo TMPFS_OK || exit 1
    for d in /dev/klee_sc/*; do n=${d##*/}; mkdir /sys/class/$n && mount --bind $d /sys/class/$n || echo "BIND_FAIL $n"; done
    mkdir -p /sys/class/fingerprint/fingerprint; echo "6.25,0,0,11.59,0,0,0,14.0" > /sys/class/fingerprint/fingerprint/position
    cat /sys/class/fingerprint/fingerprint/position; cat /sys/class/power_supply/battery/capacity; ls /sys/class | wc -l; cat /sys/class/leds/lcd-backlight/max_brightness
  ' > $P/fp_ns_test2.txt 2>&1
  { echo "global /sys/class sayisi: $(ls /sys/class | wc -l)"; cat /sys/class/power_supply/battery/capacity; } >> $P/fp_ns_test2.txt
  chmod -R 0777 $P ) &
# 2) Parmak izi konum dosyasi (GENEL): /sys/class tmpfs kopyasi + fingerprint/fingerprint/position (Samsung AODService okuyor).
#    Zygote'tan once kurulur. Kapatma: /data/local/tmp/klee_mod/nofpfs dosyasi. Denetim basarisizsa geri alinir.
P=/data/local/tmp/klee_mod/probe; mkdir -p $P; F=$P/fpfs.log
if [ ! -e /data/local/tmp/klee_mod/nofpfs ]; then
  { echo "$(date +%T) once: /sys/class=$(ls /sys/class | wc -l) pil=$(cat /sys/class/power_supply/battery/capacity)"
    /system/bin/klee_fpfs apply "6.25,0,0,11.59,0,0,0,14.0"; echo "apply rc=$?"
    c=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null); l=$(cat /sys/class/leds/lcd-backlight/max_brightness 2>/dev/null)
    if [ -z "$c" ] || [ -z "$l" ]; then echo "DENETIM BASARISIZ -> geri aliniyor"; umount -l /sys/class; fi
    echo "$(date +%T) sonra: /sys/class=$(ls /sys/class | wc -l) pil=$c fp=$(cat /sys/class/fingerprint/fingerprint/position 2>&1)"; ls -laZ /sys/class/fingerprint/fingerprint/
  } > $F 2>&1
  ( for t in 20 40 120 300; do sleep $t; /system/bin/klee_fpfs sync x >> $F 2>&1; done ) &
fi
chmod -R 0777 $P
# --- klee m3 sonu ---
D=/metadata/oneui_debug; mkdir -p $D
( while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done
  sleep 5
  settings put global development_settings_enabled 1
  while :; do
    [ "$(settings get global adb_enabled)" = 1 ] || settings put global adb_enabled 1
    case "$(getprop sys.usb.state)" in *adb*) ;; *) setprop persist.sys.usb.config mtp,adb; setprop sys.usb.config mtp,adb; start adbd ;; esac
    { date; getprop | grep -E 'usb|adb'; } > $D/adb_state.txt 2>&1
    sleep 10
  done ) &
i=0
while :; do
  dmesg | tail -n 1500 > $D/dmesg_$i.tmp 2>&1; mv $D/dmesg_$i.tmp $D/dmesg_$i.txt
  logcat -d -v threadtime -b main,system -t 2500 PowerManagerService:I DisplayPowerController:I DisplayManagerService:I WindowManager:I AudioTrack:I AudioFlinger:I "*:W" > $D/logcat_$i.tmp 2>&1; mv $D/logcat_$i.tmp $D/logcat_$i.txt
  logcat -d -v threadtime -b crash > $D/crash.tmp 2>&1; mv $D/crash.tmp $D/crash.txt
  ls -la /data/tombstones > $D/tomb.txt 2>&1
  echo "$(cat /proc/uptime) slot=$i usb=$(getprop sys.usb.state) adbd=$(getprop init.svc.adbd)" > $D/last.txt; sync
  i=$(( (i+1) % 4 )); sleep 2
done
