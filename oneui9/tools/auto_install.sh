#!/bin/bash
# Kullanım: auto_install.sh <iter> <log_adi> : telefon bağlanınca (One UI'de ise önce tanı) DSU kurulumu yapar. Yalnızca /data/gsi'ye yazar.
S=${ADB_SERIAL:?set ADB_SERIAL to your adb serial}; P="$(dirname "$(realpath "$0")")/.."; cd "$P"; I=$1; N=$2
st(){ timeout 15 adb -s $S shell 'echo "$(getprop ro.boot.slot_suffix)|$(getprop ro.build.version.oneui)|$(getprop sys.boot_completed)|$(cut -d. -f1 /proc/uptime)"' 2>/dev/null | tr -d '\r'; }
until x=$(st); [ -n "$x" ] && [ "${x%%|*}" != "$x" ] && case "$x" in *"|1|"*) true;; *) false;; esac; do sleep 20; done
echo "$(date +%T) baglandi: $x"
case "$x" in *"|90000|"*) tools/diag_oneui.sh logs/diag-before-$N; timeout 15 adb -s $S shell '[ "$(getprop ro.build.version.oneui)" = 90000 ] && reboot';; esac
for i in $(seq 1 120); do sleep 5; x=$(st); case "$x" in "_b||1|"*) [ "${x##*|}" -ge 240 ] && break;; esac; done; echo "$(date +%T) infinity: $x"
tools/dsu_cycle.sh work/$I $N > logs/$N.cycle.txt 2>&1; echo "$(date +%T) dsu_cycle rc=$?"
for i in $(seq 1 200); do x=$(st); case "$x" in *"|90000|1|"*) break;; esac; sleep 3; done; echo "$(date +%T) oneui: $x"
timeout 60 adb -s $S shell '[ "$(getprop ro.build.version.oneui)" = 90000 ] || exit 1; pm disable-user com.sec.android.app.SecSetupWizard; pm disable-user com.google.android.setupwizard; settings put global device_provisioned 1; settings put secure user_setup_complete 1; input keyevent 3; locksettings set-pin 1234; echo set rc=$?'
sleep 60; tools/diag_oneui.sh logs/diag-$N
