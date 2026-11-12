#!/bin/bash
# Kullanım: dsu_cycle.sh <iter_dizini> <log_adı> : imajı DSU'ya kurar, yeni açılışı bekler, pstore'u alır. Yalnızca /data/gsi'ye yazar.
S=${ADB_SERIAL:?set ADB_SERIAL to your adb serial}; I="$(realpath "$1")"; D="$I/../../logs/$2"; mkdir -p "$D"; L="$D/usb.log"; : > "$L"
SZ=$(stat -c %s "$I/system.img")
r(){ timeout 20 adb -s $S shell "su -c '$1'" 2>/dev/null | tr -d '\r'; }
[ "$(r 'getprop ro.boot.slot_suffix')" = _b ] || { echo "slot _b degil"; exit 9; }
BID=$(r 'cat /proc/sys/kernel/random/boot_id'); echo "boot_id=$BID" >> "$L"
r 'gsi_tool wipe' >> "$L"; r 'gsi_tool status | head -2' >> "$L"
adb -s $S exec-in "su -c 'cat | gsi_tool install --gsi-size $SZ --userdata-size 34359738368 >/dev/null 2>&1'" < "$I/system.img" & 
end=$((SECONDS+570)); last=""
while [ $SECONDS -lt $end ]; do
  u=$(lsusb | grep -iE '0e8d|2717|18d1' | cut -d' ' -f6- | tr '\n' ';'); st=$(timeout 4 adb -s $S get-state 2>/dev/null); cur="$u|$st"; [ "$cur" != "$last" ] && { echo "$(date +%T) $cur" >> "$L"; last="$cur"; }
  if [ "$st" = device ]; then b=$(timeout 8 adb -s $S shell cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '\r'); if [ -n "$b" ] && [ "$b" != "$BID" ]; then echo "$(date +%T) yeni boot $b" >> "$L"; break; fi; fi
  sleep 2
done
sleep 3
for f in console-ramoops-0 pmsg-ramoops-0; do timeout 40 adb -s $S exec-out "su -c 'cat /sys/fs/pstore/$f'" > "$D/$f.txt" 2>/dev/null; done
{ for p in ro.boot.slot_suffix ro.gsid.image_running sys.boot.reason.last sys.boot_completed ro.build.version.oneui ro.product.system.model; do echo "$p=$(r "getprop $p")"; done; r 'uptime'; } | tee -a "$L"; wc -c "$D"/*.txt; cat "$L"
