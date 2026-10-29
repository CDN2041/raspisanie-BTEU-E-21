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
fail() { grep -E "error:" "$1" | sort -u | head -40 | while IFS= read -r l; do echo "::error::${l#*native/}"; done; exit 1; }
xcrun --sdk "$PLAT" swiftc -O -parse-as-library -sdk "$SDK" -target "$TGT" Sources/*.swift -o "$APP/Pary" > "$OUT/build.log" 2>&1 || fail "$OUT/build.log"
# Виджет: отдельная программа внутри приложения, общие файлы модели и вида
WX="$APP/PlugIns/ParyWidget.appex"
mkdir -p "$WX"
xcrun --sdk "$PLAT" swiftc -O -parse-as-library -application-extension -sdk "$SDK" -target "$TGT" \
  Widget/*.swift Sources/Model.swift Sources/Theme.swift Sources/Shared.swift Sources/WidgetState.swift Sources/WidgetViews.swift \
  -o "$WX/ParyWidget" > "$OUT/widget.log" 2>&1 || fail "$OUT/widget.log"
cp Widget/Info.plist "$WX/Info.plist"
plutil -replace CFBundleVersion -string "${BUILD_N:-1}" "$WX/Info.plist"
cp ../schedule.json build/fonts/*.ttf "$WX/"
cp Info.plist "$APP/Info.plist"
plutil -replace CFBundleVersion -string "${BUILD_N:-1}" "$APP/Info.plist"
if [ "$PLAT" = iphonesimulator ]; then
  for P in "$APP/Info.plist" "$WX/Info.plist"; do
    plutil -replace CFBundleSupportedPlatforms -json '["iPhoneSimulator"]' "$P"
    plutil -replace DTPlatformName -string iphonesimulator "$P"
  done
fi
cp ../schedule.json "$APP/"
cp build/fonts/*.ttf "$APP/"
xcrun actool AppIcon.icon Assets.xcassets --compile "$APP" --platform "$PLAT" --minimum-deployment-target 16.0 \
  --app-icon AppIcon --target-device iphone --target-device ipad --output-partial-info-plist "$OUT/partial.plist" > "$OUT/icon.log" 2>&1 \
  || { sed 's/^/::error::/' "$OUT/icon.log" | head -20; exit 1; }
/usr/libexec/PlistBuddy -c "Merge $OUT/partial.plist" "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
# Подпись без сертификата, но с общей группой: Sideloadly перенесёт её в свою подпись
codesign -f -s - --entitlements ent.plist "$WX" >/dev/null
codesign -f -s - --entitlements ent.plist "$APP" >/dev/null
if [ "$PLAT" = iphoneos ]; then (cd "$OUT" && zip -qr ../../pary-native.ipa Payload); fi
echo "built $PLAT"
