#!/system/bin/sh
# one-ui-port debugging: run /metadata/oneui_dbg/run.sh if it exists (can be changed without rebuilding the image)
if [ -f /metadata/oneui_dbg/run.sh ]; then
  exec /system/bin/sh /metadata/oneui_dbg/run.sh
fi
D=/metadata/oneui_debug
mkdir -p $D
n=0
while [ $n -lt 8 ]; do
  sleep 15
  n=$((n+1))
  logcat -d -b all -t 20000 > $D/logcat_$n.txt 2>&1
  getprop > $D/props_$n.txt
  sync
done
echo done > $D/done.txt
sync
