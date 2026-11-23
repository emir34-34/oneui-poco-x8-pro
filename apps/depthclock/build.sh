#!/bin/bash
# Derinlik Saati LSPosed modulu (Gradle'siz). Cikti: build/DepthClock.apk
set -e
cd "$(dirname "$0")"
SDK=~/Android/Sdk; BT=$SDK/build-tools/35.0.0; AJ=$SDK/platforms/android-35/android.jar
rm -rf build; mkdir -p build/res build/stubs build/classes build/dex
$BT/aapt2 compile --dir res -o build/res/res.zip
$BT/aapt2 link -o build/unsigned.apk --manifest AndroidManifest.xml -I $AJ -A assets build/res/res.zip
javac --release 11 -cp $AJ -d build/stubs $(find stubs -name '*.java')
javac --release 11 -cp $AJ:build/stubs -d build/classes $(find src -name '*.java')
$BT/d8 --min-api 33 --lib $AJ --classpath build/stubs --output build/dex $(find build/classes -name '*.class')
(cd build/dex && zip -q ../unsigned.apk classes.dex)
$BT/zipalign -f -p 4 build/unsigned.apk build/aligned.apk
[ -f depthclock.jks ] || keytool -genkeypair -keystore depthclock.jks -alias k -storepass depthclock -keypass depthclock -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=DepthClock" >/dev/null 2>&1
$BT/apksigner sign --ks depthclock.jks --ks-pass pass:depthclock --ks-key-alias k --out build/DepthClock.apk build/aligned.apk
ls -la build/DepthClock.apk
