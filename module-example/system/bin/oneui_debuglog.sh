#!/system/bin/sh
# A00) o9-47: klasor kabuk tarafindan yazilabilir olsun (temiz /data'da root:700 olusuyordu; modul/cmd.sh konamiyordu)
mkdir -p /data/local/tmp/klee_mod; chown shell:shell /data/local/tmp/klee_mod; chmod 0777 /data/local/tmp/klee_mod
# Logger v5. /metadata/oneui_debug halka; ADB'yi bu DSU'da açık tutar; uyku/uyanma ve ses satırlarını da yazar.
# --- klee m4 (modül, root, oneuidbg) ---
# A) m22 ses: Samsung AIDL dönüşümü MTK OUT_FM portunu tanımıyor -> APM yalnız hoparlör/mikrofonla açılıyor (BT A2DP yok,
#    44,1 kHz tek çıkış -> video ile ses kayması). klee_port.rc'deki init bind'i EACCES ile düşüyor; burada FM'siz +
#    spatializer'sız ayar /vendor/etc üstüne bağlanır. Ses HAL'ı önceden açıldıysa yeniden başlatılır.
( for f in audio_policy_configuration_a2dp_offload_enable_cg_enable_cts.xml audio_policy_configuration.xml; do
    grep -q "FM Tuner" /vendor/etc/$f && mount -o bind /system/etc/klee_audio/$f /vendor/etc/$f && echo "OK $f"
  done
  # m24 BT A2DP DSP offload: bluetooth modülünde yalnız işitme cihazı; A2DP primary modülde (encodedFormats boş, APM yamalı).
  B=bluetooth_a2dp_offload_ums_offload_audio_policy_configuration.xml
  mount -o bind /system/etc/klee_audio/$B /vendor/etc/$B && echo "OK $B"
  setprop persist.bluetooth.a2dp_offload.disabled false
  P=$(pidof android.hardware.audio.service-aidl.mediatek); [ -n "$P" ] && { echo "HAL acikti ($P), yeniden"; kill $P; }
  echo "ses bitti $(cat /proc/uptime)" ) > /data/local/tmp/klee_mod/audio.log 2>&1
# A2) m24 BT: Samsung BT uygulaması offload açık (A2dpServiceHelper/AdapterProperties/codec öncelikleri) +
#     libbluetooth_jni klee7: offload bayrakları + BT çipine offload başlamadan önce 0xfd5d [a0 03] (AOSP coex_buf_count=3;
#     MTK çipi bunu almadan DSP'den paket çekmiyor: fw_qu=0). Arka planda çalışır (açılışı bekletmez).
( A=/apex/com.android.bt/app/Bluetooth@CP2A.260605.016/Bluetooth.apk; J=/apex/com.android.bt/lib64/libbluetooth_jni.so
  # Native kütüphane: zygote'tan önce (PM bunu taramaz).
  for i in $(seq 1 120); do [ -f $J ] && break; sleep 0.25; done
  mount -o bind /system/lib64/klee_bt/libbluetooth_jni.so $J && echo "jni bind ok $(cat /proc/uptime)"
  Z=$(pidof zygote64); [ -n "$Z" ] && nsenter -t $Z -m -- mount -o bind /system/lib64/klee_bt/libbluetooth_jni.so $J && echo "zygote acikti ($Z), jni ona da"
  # APK: PackageManager taramasından SONRA (önce bağlanırsa imza farkı -> paket reddi -> system_server çöküş döngüsü, m24 BROM).
  # BT süreci ilk açıldığında tarama bitmiştir; global + zygote ad alanına bağla, eski dalvik önbelleğini taşı, BT'yi yeniden başlat.
  for i in $(seq 1 600); do P=$(pidof com.android.bluetooth); [ -n "$P" ] && break; sleep 0.5; done
  [ -z "$P" ] && { echo "BT sureci gelmedi, APK baglanmadi"; exit 0; }
  sleep 2
  Z=$(pidof zygote64)
  mount -o bind /system/etc/klee_bt/Bluetooth.apk $A && nsenter -t $Z -m -- mount -o bind /system/etc/klee_bt/Bluetooth.apk $A && echo "apk bind ok (BT $P, zygote $Z) $(cat /proc/uptime)"
  mkdir -p /data/local/tmp/klee_mod/dalvik_old
  for f in /data/dalvik-cache/arm64/apex@com.android.bt@app@Bluetooth*; do [ -e "$f" ] && mv "$f" /data/local/tmp/klee_mod/dalvik_old/; done
  kill $P; echo "BT yeniden ($P)"
  echo "bt bitti" ) > /data/local/tmp/klee_mod/bt.log 2>&1 &
# A3) Telefon: Samsung Ayarlar/TelephonyUI SIM varlığını ril.ICC_TYPE<n>'den okur (Samsung RIL yazar, MTK RIL yazmaz)
#     -> "Mobil ağlar" gizli, SIM yöneticisi SIM'i "takılı değil" gösterir. MTK uicctype -> Samsung ICC tipi (0 yok, 1 SIM, 2 USIM).
( t(){ case "$1" in SIM) echo 1;; USIM) echo 2;; "") echo 0;; *) echo 2;; esac; }
  while :; do
    a=$(t "$(getprop vendor.gsm.ril.uicctype)"); b=$(t "$(getprop vendor.gsm.ril.uicctype.2)")
    [ "$(getprop ril.ICC_TYPE0)" = "$a" ] || setprop ril.ICC_TYPE0 $a
    [ "$(getprop ril.ICC_TYPE1)" = "$b" ] || setprop ril.ICC_TYPE1 $b
    sleep 5
  done ) &
chmod 0666 /data/local/tmp/klee_mod/bt.log 2>/dev/null
chmod 0666 /data/local/tmp/klee_mod/audio.log 2>/dev/null
# 0) m18: SELinux politikası yeniden yüklenir. Fark: mapping/202604.cil'de platform_app_36 -> platform_app_202604, priv_app_36 -> priv_app_202604
#    (Android 17'nin targetSdk<=36 uygulama alanları vendor kurallarının dışında kalıyordu; Xiaomi kamera MiSys/BGService bulamıyordu).
#    Kapatmak: /data/local/tmp/klee_mod/nosepolicy
if [ -f /system/etc/klee_sepolicy ] && [ ! -e /data/local/tmp/klee_mod/nosepolicy ]; then
  if cat /system/etc/klee_sepolicy > /sys/fs/selinux/load 2>/data/local/tmp/klee_mod/sepolicy.err; then echo "$(date +%T) yuklendi" > /data/local/tmp/klee_mod/sepolicy.log
  else echo "$(date +%T) HATA" > /data/local/tmp/klee_mod/sepolicy.log; fi
  dmesg | grep -iE "selinux|policy" | tail -40 >> /data/local/tmp/klee_mod/sepolicy.log
  chmod 0666 /data/local/tmp/klee_mod/sepolicy.* 2>/dev/null
fi
# 0b) m19 GELISTIRME ARACI (Slot A oncesi kaldirilacak): /data/local/tmp/klee_mod/cmd.sh varsa root olarak calistirir,
#     ciktiyi cmd.out'a yazar, dosyayi siler. Yalniz bu DSU'da; adb ile yeniden baslatmadan root komut icin.
( C=/data/local/tmp/klee_mod/cmd.sh; O=/data/local/tmp/klee_mod/cmd.out
  while :; do
    if [ -f $C ]; then mv $C $C.run; { echo "== $(date +%T)"; sh $C.run; echo "== rc=$?"; } > $O 2>&1; rm -f $C.run; chmod 0666 $O; fi
    sleep 1
  done ) &
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
