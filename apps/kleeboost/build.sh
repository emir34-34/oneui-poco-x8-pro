#!/bin/bash
# KleeBoost Vector/LSPosed modulu derleme (Gradle'siz).
# Xposed API stub'lari (stubs/) sadece derleme icin; APK'ya girmez.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_SDK:-~/Android/Sdk}; BT=${BT:-$SDK/build-tools/35.0.0}; AJ=${AJ:-$SDK/platforms/android-36/android.jar}
rm -rf build; mkdir -p build/res build/stubs build/classes build/apk
$BT/aapt2 compile --dir res -o build/res
$BT/aapt2 link -o build/base.apk --manifest AndroidManifest.xml -I $AJ -A assets build/res/*.flat
javac --release 11 -cp $AJ -d build/stubs $(find stubs -name '*.java')
javac --release 11 -Xlint:-options -cp $AJ:build/stubs -d build/classes $(find src -name '*.java')
$BT/d8 --min-api 33 --lib $AJ --classpath build/stubs --output build/apk $(find build/classes -name '*.class')
cp build/base.apk build/unsigned.apk
python3 - <<'PY'
import zipfile
with zipfile.ZipFile('build/unsigned.apk', 'a') as z:
    z.write('build/apk/classes.dex', 'classes.dex')
PY
$BT/zipalign -f -p 4 build/unsigned.apk build/aligned.apk
[ -f kleeboost.jks ] || keytool -genkeypair -keystore kleeboost.jks -alias k -storepass kleeboost -keypass kleeboost -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=KleeBoost" >/dev/null 2>&1
$BT/apksigner sign --ks kleeboost.jks --ks-pass pass:kleeboost --ks-key-alias k --out build/KleeBoost.apk build/aligned.apk
ls -la build/KleeBoost.apk
