#!/bin/bash
# kullanim: build_services_mod.sh [ad]  (ad: services | secinputdev-service; smali work/re/<kisa>) -> work/mods/m3/system/framework/<ad>.jar
set -e; cd "$(dirname "$(realpath "$0")")/.."; N=${1:-services}; case $N in services) RD=work/re/services;; secinputdev-service) RD=work/re/secinput;; *) echo "bilinmeyen $N"; exit 2;; esac; T=${TMPDIR:-/tmp}/svc_$N; rm -rf $T; mkdir -p $T
java -jar tools/port/apktool.jar b $RD -o $T/new.jar >/dev/null 2>&1
(cd $T && unzip -q -o new.jar 'classes*.dex')
python3 -I - work/o9-45/root/system/framework/$N.jar $T/out.jar $T <<'P'
import sys,zipfile,os
src,dst,d=sys.argv[1:4]; zi=zipfile.ZipFile(src); zo=zipfile.ZipFile(dst,'w')
for i in zi.infolist():
    data=open(os.path.join(d,i.filename),'rb').read() if i.filename.startswith('classes') and i.filename.endswith('.dex') else zi.read(i)
    n=zipfile.ZipInfo(i.filename,date_time=i.date_time); n.compress_type=i.compress_type; n.external_attr=i.external_attr; zo.writestr(n,data)
zo.close()
P
~/Android/Sdk/build-tools/37.0.0/zipalign -f -p 4 $T/out.jar work/mods/m3/system/framework/$N.jar; chmod 644 work/mods/m3/system/framework/$N.jar; stat -c %s work/mods/m3/system/framework/$N.jar
