#!/bin/bash
# Klee NavFull Xposed (Vector/LSPosed) modülü derleme (Gradle'siz).
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-~/Android/Sdk}; BT=$(ls -d $SDK/build-tools/* | sort -V | tail -1); AJ=$SDK/platforms/android-36/android.jar
XA=${XPOSED_API:-~/xposed/api-82.jar}
[ -f "$XA" ] || { mkdir -p "$(dirname "$XA")"; curl -fsSL -o "$XA" https://api.xposed.info/de/robv/android/xposed/api/82/api-82.jar; }
rm -rf build; mkdir -p build/classes build/res build/apk
$BT/aapt2 compile --dir res -o build/res.zip
$BT/aapt2 link -o build/base.apk --manifest AndroidManifest.xml -I $AJ build/res.zip -A assets
javac --release 17 -Xlint:-options -cp $AJ:$XA -d build/classes $(find src -name '*.java')
# Xposed API yalnız derleme için: dex'e girmez (Vector çalışma anında sağlar).
$BT/d8 --release --min-api 33 --lib $AJ --classpath $XA --output build/apk $(find build/classes -name '*.class')
cp build/base.apk build/unsigned.apk
(cd build/apk && zip -q ../unsigned.apk classes.dex)
$BT/zipalign -f -p 4 build/unsigned.apk build/aligned.apk
[ -f kleenavfull.jks ] || keytool -genkeypair -keystore kleenavfull.jks -alias k -storepass kleenavfull -keypass kleenavfull -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=KleeNavFull" >/dev/null 2>&1
$BT/apksigner sign --ks kleenavfull.jks --ks-pass pass:kleenavfull --ks-key-alias k --out build/KleeNavFull.apk build/aligned.apk
ls -la build/KleeNavFull.apk
