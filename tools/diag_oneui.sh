#!/bin/bash
# Kullanım: diag_oneui.sh <cikti_dizini> : One UI DSU açıkken salt okunur tanı toplar (cihazda hiçbir şey değiştirmez).
S=${ADB_SERIAL:?set ADB_SERIAL to your adb serial}; D="$1"; mkdir -p "$D"
o=$(timeout 10 adb -s $S shell getprop ro.build.version.oneui | tr -d '\r'); [ "$o" = 90000 ] || { echo "One UI acik degil ($o)"; exit 1; }
a(){ timeout 60 adb -s $S shell "$1" > "$D/$2" 2>&1; }
a 'logcat -d -b all -v monotonic' logcat_all.txt
a 'logcat -d -b crash' crash.txt
a 'logcat -d -b events' events.txt
a 'logcat -d -b kernel -v monotonic' kernel.txt
a 'dumpsys display' display.txt
a 'dumpsys overlay' overlay.txt
a 'dumpsys sensorservice' sensors.txt
a 'getprop' props.txt
a 'settings list system; settings list secure; settings list global' settings.txt
a 'pm list packages -d; pm list packages -u' pkgs.txt
grep -E 'boot_progress_(start|enable_screen)' "$D/events.txt"
grep -cE 'Wait loading global de key' "$D/kernel.txt"
grep -E "took [0-9]{4,}ms" "$D/kernel.txt" | cut -c1-200 | head
grep -iE 'MappingStrategy|setUpAutoBrightness|isValidMapping|x\.length|prevX' "$D/logcat_all.txt" | head -20
grep -nE 'Mapper for mode|PhysicalMappingStrategy|SimpleMappingStrategy|mUseAutoBrightness' "$D/display.txt" | head
grep -E 'Process:' "$D/crash.txt" | awk '{print $NF,$(NF-2)}' | sort | uniq -c | sort -rn | head -20
