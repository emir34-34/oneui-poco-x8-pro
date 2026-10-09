#!/bin/bash
# Rebuilds the One UI DSU image and (optionally) installs it on the phone.
# Usage: tools/build_oneui.sh [--jar services] [--install]
#   --jar <name> : repacks the fw/jars/<name> smali folder into /system/framework/<name>.jar
#                (the old oat/arm64/<name>.{odex,vdex,art} files are removed)
#   --install  : pushes the image to the phone and installs it as DSU with gsi_tool
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$ROOT/fw/build"
J="$ROOT/fw/jars"
T="$ROOT/tools"
JARS=(); INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --jar) JARS+=("$2"); shift 2 ;;
    --install) INSTALL=1; shift ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done

for name in "${JARS[@]}"; do
  echo ">> repacking $name.jar"
  rm -f "$J/$name.patched.jar" "$J/$name.aligned.jar"
  java -jar "$T/apktool.jar" b -o "$J/$name.patched.jar" "$J/$name" >/dev/null
  # Keep the original jar, replace only the dex files; align stored entries to 4 bytes
  python3 - "$J/$name.orig.jar" "$J/$name.patched.jar" "$J/$name.aligned.jar" <<'EOF'
import sys, zipfile, struct
orig, new, out_path = sys.argv[1:4]
o = zipfile.ZipFile(orig); n = zipfile.ZipFile(new)
ct = next(i.compress_type for i in o.infolist() if i.filename.endswith('.dex'))
entries = [(i, o.read(i.filename)) for i in o.infolist() if not i.filename.endswith('.dex')]
for name in sorted(x for x in n.namelist() if x.endswith('.dex')):
    zi = zipfile.ZipInfo(name, date_time=(2008, 1, 1, 0, 0, 0)); zi.compress_type = ct
    entries.append((zi, n.read(name)))
with zipfile.ZipFile(out_path, 'w') as out:
    for i, data in entries:
        zi = zipfile.ZipInfo(i.filename, date_time=i.date_time)
        zi.compress_type = i.compress_type; zi.external_attr = i.external_attr
        if zi.compress_type == zipfile.ZIP_STORED:
            pad = (-(out.fp.tell() + 30 + len(zi.filename.encode()))) % 4
            if pad:
                pad += 4
                zi.extra = b'\xd9\x35' + (pad - 4).to_bytes(2, 'little') + b'\x00' * (pad - 4)
        out.writestr(zi, data)
z = zipfile.ZipFile(out_path)
assert z.testzip() is None
for i in z.infolist():
    if i.filename.endswith('.dex'):
        z.fp.seek(i.header_offset); h = z.fp.read(30); nl, el = struct.unpack('<HH', h[26:30])
        assert (i.header_offset + 30 + nl + el) % 4 == 0, i.filename
print("   dex:", [i.filename for i in z.infolist() if i.filename.endswith('.dex')], "aligned")
EOF
  unshare --map-auto --map-root-user bash -c "
    install -o 0 -g 0 -m 0644 '$J/$name.aligned.jar' '$B/root/system/framework/$name.jar'
    rm -f '$B/root/system/framework/oat/arm64/$name.odex' '$B/root/system/framework/oat/arm64/$name.vdex' '$B/root/system/framework/oat/arm64/$name.art'"
done

echo ">> building the erofs image"
cd "$B"
rm -f oneui_system_debug.img
unshare --map-auto --map-root-user "$T/erofs/bin/mkfs.erofs" -zlz4hc,9 --file-contexts=file_contexts \
  --mount-point=/ -T 1640995200 oneui_system_debug.img root >/dev/null
SZ=$(stat -c %s oneui_system_debug.img); PS=$(( (SZ + 48*1024*1024 + 4095) / 4096 * 4096 ))
echo ">> AVB hashtree footer"
python3 "$T/avbtool.py" add_hashtree_footer --image oneui_system_debug.img --partition_name system \
  --partition_size $PS --hash_algorithm sha256 --algorithm SHA256_RSA4096 --key "$T/testkey_rsa4096.pem" \
  --do_not_generate_fec --prop com.android.build.system.os_version:16
ln -sf oneui_system_debug.img system.img
python3 "$T/avbtool.py" verify_image --image oneui_system_debug.img | tail -1
rm -f system.img

if [ $INSTALL = 1 ]; then
  echo ">> installing on the phone"
  adb shell su -c 'rm -rf /metadata/oneui_debug /data/local/tmp/oneui_debug; rm -f /sdcard/Download/oneui.img'
  adb push oneui_system_debug.img /sdcard/Download/oneui.img | tail -1
  SZ=$(stat -c %s oneui_system_debug.img)
  adb shell su -c "gsi_tool wipe; gsi_tool install --gsi-size $SZ --userdata-size 8589934592 < /sdcard/Download/oneui.img >/dev/null 2>&1; echo EXIT=\$?; gsi_tool status | head -2"
fi
date +%T
