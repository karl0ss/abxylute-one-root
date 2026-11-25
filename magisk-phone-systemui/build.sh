#!/usr/bin/env bash
# Build both RRO overlays and package the Magisk module zip (phonesystemui-vN.zip).
# Needs Android SDK build-tools 34.0.0 + platforms/android-34.
set -euo pipefail
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$HOME/android-sdk}"
BT="$SDK/build-tools/34.0.0"; AJ="$SDK/platforms/android-34/android.jar"
KS="${KEYSTORE:-overlay.keystore}"
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass android -keypass android \
  -alias key -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=phonesystemui"

build() { # src-dir out-apk
  local s=$1 out=$2
  rm -rf "$s/build"; mkdir -p "$s/build"
  "$BT/aapt2" compile --dir "$s/res" -o "$s/build/res.zip"
  # --no-resource-deduping keeps the values-television copies (they are identical to the defaults)
  "$BT/aapt2" link -o "$s/build/u.apk" -I "$AJ" --manifest "$s/AndroidManifest.xml" "$s/build/res.zip" \
    --no-resource-removal --no-resource-deduping
  "$BT/zipalign" -f 4 "$s/build/u.apk" "$s/build/a.apk"
  mkdir -p "$(dirname "$out")"
  "$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --v4-signing-enabled false --out "$out" "$s/build/a.apk"
}
build overlay-src           system/product/overlay/PhoneSystemUIOverlay/PhoneSystemUIOverlay.apk
build framework-overlay-src system/product/overlay/PhoneSystemUIFrameworkOverlay/PhoneSystemUIFrameworkOverlay.apk
v=$(grep '^version=' module.prop | cut -d= -f2)
rm -f "phonesystemui-$v.zip"; zip -q -r "phonesystemui-$v.zip" module.prop service.sh uninstall.sh system
echo "Built $(pwd)/phonesystemui-$v.zip"
