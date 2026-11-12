#!/bin/bash
# Kullanım: push_module.sh <modul.img | --disable> : One UI (DSU) açıkken modülü gönderir, DSU'yu yeniden açar, yükleyici logunu gösterir.
# Yalnızca DSU içindeki /data/local/tmp/klee_mod'a yazar; Infinity X'te sadece `gsi_tool enable -s` (tek açılışlık) çalıştırır.
S=${ADB_SERIAL:?set ADB_SERIAL to your adb serial}
st(){ timeout 15 adb -s $S shell 'echo "$(getprop ro.boot.slot_suffix)|$(getprop ro.build.version.oneui)|$(getprop sys.boot_completed)|$(cut -d. -f1 /proc/uptime)"' 2>/dev/null | tr -d '\r'; }
case "$(st)" in *"|90000|1|"*) ;; *) echo "One UI acik degil: $(st)"; exit 1;; esac
adb -s $S shell 'mkdir -p /data/local/tmp/klee_mod'
if [ "$1" = --disable ]; then adb -s $S shell 'touch /data/local/tmp/klee_mod/disable'; else
  adb -s $S push "$1" /data/local/tmp/klee_mod/mod.img.new >/dev/null && adb -s $S shell 'cd /data/local/tmp/klee_mod && mv mod.img.new mod.img && rm -f disable pending' || exit 1; fi
adb -s $S shell '[ "$(getprop ro.build.version.oneui)" = 90000 ] && reboot'
for i in $(seq 1 120); do sleep 5; x=$(st); case "$x" in "_b||1|"*) [ "${x##*|}" -ge 60 ] && break;; esac; done; echo "$(date +%T) infinity: $x"
[ "${x#_b||1|}" != "$x" ] || { echo "Infinity X'e donmedi"; exit 1; }
timeout 20 adb -s $S shell "su -c 'gsi_tool enable -s'"; timeout 20 adb -s $S shell "su -c 'gsi_tool status'"
timeout 15 adb -s $S shell "su -c '[ -z \"\$(getprop ro.build.version.oneui)\" ] && reboot'"
for i in $(seq 1 150); do sleep 4; x=$(st); case "$x" in *"|90000|1|"*) break;; esac; done; echo "$(date +%T) oneui: $x"
adb -s $S shell 'cat /data/local/tmp/klee_mod/last.log 2>&1; ls -la /data/local/tmp/klee_mod'
