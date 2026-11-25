#!/usr/bin/env bash
# Build GamePadSettings-shortcut.apk.
# Needs: Android SDK with build-tools 34.0.0 + platforms/android-34, and either a JDK
# (javac) or docker (falls back to eclipse-temurin:17-jdk for javac).
set -euo pipefail
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
BT="$SDK/build-tools/34.0.0"
AJ="$SDK/platforms/android-34/android.jar"
KS="${KEYSTORE:-shortcut.keystore}"

rm -rf build && mkdir -p build/classes build/dex
"$BT/aapt2" compile --dir res -o build/res.zip
"$BT/aapt2" link -o build/unsigned.apk -I "$AJ" --manifest AndroidManifest.xml build/res.zip

if command -v javac >/dev/null; then
  javac --release 8 -cp "$AJ" -d build/classes src/uk/karl/gpsettings/Main.java
else
  docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/w" -v "$AJ:/android.jar:ro" -w /w \
    eclipse-temurin:17-jdk javac --release 8 -cp /android.jar -d build/classes src/uk/karl/gpsettings/Main.java
fi

"$BT/d8" --release --min-api 24 --lib "$AJ" --output build/dex build/classes/uk/karl/gpsettings/*.class
(cd build/dex && zip -q ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 build/unsigned.apk build/aligned.apk

[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass android -keypass android \
  -alias key -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=gpsettings"
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --out GamePadSettings-shortcut.apk build/aligned.apk
echo "Built $(pwd)/GamePadSettings-shortcut.apk"
