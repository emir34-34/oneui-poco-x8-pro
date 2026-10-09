#!/system/bin/sh
# Log collector v2, editable from Axion (runs while One UI boots)
D=/metadata/oneui_debug
mkdir -p $D
echo "start $(cat /proc/uptime)" > $D/status.txt; sync
n=0
while [ $n -lt 10 ]; do
  sleep 6
  n=$((n+1))
  logcat -d -b main,system,crash,events -t 12000 > $D/logcat_$n.txt 2>&1
  dmesg > $D/dmesg_$n.txt 2>&1
  ps -A -o PID,PPID,STIME,TIME,S,NAME > $D/ps_$n.txt 2>&1
  getprop | grep -E "init.svc|boot|zygote" > $D/props_$n.txt
  echo "iter $n $(cat /proc/uptime)" >> $D/status.txt
  sync
done
getprop > $D/props_full.txt
echo done >> $D/status.txt
sync
