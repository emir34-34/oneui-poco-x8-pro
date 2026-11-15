#!/bin/bash
# KleeToys APK derleme (Gradle'siz). Xiaomi dosyalari xiaomi/ altinda yerel; repoya girmez.
set -e
cd "$(dirname "$0")"
SDK=~/Android/Sdk; BT=$SDK/build-tools/35.0.0; AJ=$SDK/platforms/android-36/android.jar
NDK=$SDK/ndk/27.3.13750724/toolchains/llvm/prebuilt/linux-x86_64/bin
rm -rf build; mkdir -p build/classes build/apk/lib/arm64-v8a build/apk/assets
$BT/aapt2 link -o build/base.apk --manifest AndroidManifest.xml -I $AJ
javac --release 11 -cp $AJ -d build/classes $(find src -name '*.java') 2>&1 | grep -v -i 'warning' || true
$BT/d8 --min-api 33 --lib $AJ --output build/apk $(find build/classes -name '*.class')
$NDK/aarch64-linux-android33-clang -shared -fPIC -O2 -o build/apk/lib/arm64-v8a/libxled.so jni/xled.c -llog -ldl
if [ -f xiaomi/libmis_audioled.so ]; then cp xiaomi/libmis_audioled.so build/apk/lib/arm64-v8a/; fi
if [ -f xiaomi/mis_audioled_configs.bin ]; then cp xiaomi/mis_audioled_configs.bin build/apk/assets/; fi
cp build/base.apk build/unsigned.apk
python3 - <<'PY'
import zipfile, os
z = zipfile.ZipFile('build/unsigned.apk', 'a')
for root, _, files in os.walk('build/apk'):
    for f in files:
        full = os.path.join(root, f); arc = os.path.relpath(full, 'build/apk')
        z.write(full, arc, compress_type=zipfile.ZIP_STORED if arc.endswith('.so') else zipfile.ZIP_DEFLATED)
z.close()
PY
$BT/zipalign -f -p 4 build/unsigned.apk build/aligned.apk
[ -f kleetoys.jks ] || keytool -genkeypair -keystore kleetoys.jks -alias k -storepass kleetoys -keypass kleetoys -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=KleeToys" >/dev/null 2>&1
$BT/apksigner sign --ks kleetoys.jks --ks-pass pass:kleetoys --ks-key-alias k --out build/KleeToys.apk build/aligned.apk
ls -la build/KleeToys.apk
