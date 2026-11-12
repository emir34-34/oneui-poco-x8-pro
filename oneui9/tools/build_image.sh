#!/bin/bash
# Kullanım: build_image.sh <iter_dizini> [--jar] ; root + file_contexts -> system.img (EROFS + AVB footer)
ROOT="${ROOT:-$(dirname "$(realpath "$0")")/..}"  # proje kökü: tools/port (apktool, erofs, avbtool) burada
set -e
I="$(realpath "$1")"; T="$ROOT/tools/port"; O="$ROOT/tools/port/services.orig.jar"
if [ "$2" = --jar ]; then
python3 -I - "$O" "$I/jars/services.hooked.jar" "$I/jars/services.aligned.jar" <<'EOF'
import sys,zipfile,struct
orig,new,out=sys.argv[1:4]; o=zipfile.ZipFile(orig); n=zipfile.ZipFile(new)
ct=next(i.compress_type for i in o.infolist() if i.filename.endswith('.dex'))
e=[(i,o.read(i.filename)) for i in o.infolist() if not i.filename.endswith('.dex')]
for x in sorted(y for y in n.namelist() if y.endswith('.dex')):
    z=zipfile.ZipInfo(x,date_time=(2008,1,1,0,0,0)); z.compress_type=ct; e.append((z,n.read(x)))
with zipfile.ZipFile(out,'w') as w:
    for i,d in e:
        z=zipfile.ZipInfo(i.filename,date_time=i.date_time); z.compress_type=i.compress_type; z.external_attr=i.external_attr
        if z.compress_type==zipfile.ZIP_STORED:
            p=(-(w.fp.tell()+30+len(z.filename.encode())))%4
            if p: p+=4; z.extra=b'\xd9\x35'+(p-4).to_bytes(2,'little')+b'\0'*(p-4)
        w.writestr(z,d)
z=zipfile.ZipFile(out); assert z.testzip() is None
print('dex',[i.filename for i in z.infolist() if i.filename.endswith('.dex')])
EOF
unshare --map-auto --map-root-user install -o 0 -g 0 -m 0644 "$I/jars/services.aligned.jar" "$I/root/system/framework/services.jar"
fi
cd "$I"; rm -f system.img
unshare --map-auto --map-root-user "$T/erofs/bin/mkfs.erofs" -zlz4hc,9 --file-contexts=file_contexts --mount-point=/ -T 1640995200 system.img root 2>&1 | tail -3
S=$(stat -c %s system.img); PS=$(( (S+S/100+16*1024*1024+4095)/4096*4096 ))
python3 "$T/avbtool.py" add_hashtree_footer --image system.img --partition_name system --partition_size $PS --hash_algorithm sha256 --algorithm SHA256_RSA4096 --key "$T/testkey_rsa4096.pem" --do_not_generate_fec --prop com.android.build.system.os_version:16
python3 "$T/avbtool.py" verify_image --image system.img | tail -1; stat -c '%s %n' system.img; sha256sum system.img
