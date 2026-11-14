#!/bin/bash
# Kullanım: dsu_install_file.sh <iter_dizini> : imajı telefona kopyalar, IX'te cihaz içinde (nohup, pipe) gsi_tool install --no-reboot. 
# exec-in akışı yarıda kesiliyordu ("no bytes left in stream"); gsid shell_data_file'ı fd olarak okuyamıyor -> cat | pipe.
S=${ANDROID_SERIAL:?set ANDROID_SERIAL};  I="$(realpath "$1")/system.img"; SZ=$(stat -c %s "$I")
adb -s $S push "$I" /data/local/tmp/dsu_new.img || exit 1
adb -s $S shell "su -c 'nohup sh -c \"cat /data/local/tmp/dsu_new.img | gsi_tool install --gsi-size $SZ --userdata-size 34359738368 --no-reboot > /data/local/tmp/dsu_inst.out 2>&1; echo EXIT=\\\$? >> /data/local/tmp/dsu_inst.out; rm -f /data/local/tmp/dsu_new.img\" >/dev/null 2>&1 &'"
until adb -s $S shell "su -c 'grep -a EXIT /data/local/tmp/dsu_inst.out'" 2>/dev/null | grep -q EXIT; do sleep 8; done
adb -s $S shell "su -c 'grep -a EXIT /data/local/tmp/dsu_inst.out; gsi_tool status 2>&1 | grep -v libbinder | head -2'"
