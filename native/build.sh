#!/bin/bash
# Сборка без Xcode-проекта: swiftc + actool. $1 = iphoneos (IPA) или iphonesimulator (для скриншотов)
set -eo pipefail
cd "$(dirname "$0")"
PLAT=$1
OUT=build/$PLAT
APP=$OUT/Payload/Pary.app
rm -rf "$OUT"; mkdir -p "$APP"
SDK=$(xcrun --sdk "$PLAT" --show-sdk-path)
if [ "$PLAT" = iphoneos ]; then TGT=arm64-apple-ios16.0; else TGT=arm64-apple-ios16.0-simulator; fi
if ! xcrun --sdk "$PLAT" swiftc -O -parse-as-library -sdk "$SDK" -target "$TGT" Sources/*.swift -o "$APP/Pary" > "$OUT/build.log" 2>&1; then
  grep -E "error:" "$OUT/build.log" | sort -u | head -40 | while IFS= read -r l; do echo "::error::${l#*native/}"; done
  exit 1
fi
cp Info.plist "$APP/Info.plist"
plutil -replace CFBundleVersion -string "${BUILD_N:-1}" "$APP/Info.plist"
if [ "$PLAT" = iphonesimulator ]; then
  plutil -replace CFBundleSupportedPlatforms -json '["iPhoneSimulator"]' "$APP/Info.plist"
  plutil -replace DTPlatformName -string iphonesimulator "$APP/Info.plist"
fi
cp ../schedule.json "$APP/"
cp build/fonts/*.ttf "$APP/"
xcrun actool ../ios/AppIcon.icon Assets.xcassets --compile "$APP" --platform "$PLAT" --minimum-deployment-target 16.0 \
  --app-icon AppIcon --target-device iphone --target-device ipad --output-partial-info-plist "$OUT/partial.plist" > "$OUT/icon.log" 2>&1 \
  || { sed 's/^/::error::/' "$OUT/icon.log" | head -20; exit 1; }
/usr/libexec/PlistBuddy -c "Merge $OUT/partial.plist" "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
if [ "$PLAT" = iphonesimulator ]; then codesign -f -s - "$APP" >/dev/null 2>&1; fi
if [ "$PLAT" = iphoneos ]; then (cd "$OUT" && zip -qr ../../pary-native.ipa Payload); fi
echo "built $PLAT"
