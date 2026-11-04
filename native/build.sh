#!/bin/bash
# Сборка без Xcode-проекта: swiftc + actool. $1 = iphoneos (IPA) или iphonesimulator (для скриншотов)
set -eo pipefail
cd "$(dirname "$0")"
PLAT=$1
OUT=build/$PLAT
APP=$OUT/Payload/Pary.app
rm -rf "$OUT"; mkdir -p "$APP"
SDK=$(xcrun --sdk "$PLAT" --show-sdk-path)
if [ "$PLAT" = iphoneos ]; then TGT=arm64-apple-ios16.2; else TGT=arm64-apple-ios16.2-simulator; fi
fail() { grep -E "error:" "$1" | sort -u | head -40 | while IFS= read -r l; do echo "::error::${l#*native/}"; done; exit 1; }
xcrun --sdk "$PLAT" swiftc -O -parse-as-library -sdk "$SDK" -target "$TGT" Sources/*.swift -o "$APP/Pary" > "$OUT/build.log" 2>&1 || fail "$OUT/build.log"
# Виджет: отдельная программа внутри приложения, общие файлы модели и вида
WX="$APP/PlugIns/ParyWidget.appex"
mkdir -p "$WX"
xcrun --sdk "$PLAT" swiftc -O -parse-as-library -application-extension -sdk "$SDK" -target "$TGT" \
  Widget/*.swift Sources/Model.swift Sources/Theme.swift Sources/Shared.swift Sources/WidgetState.swift Sources/WidgetViews.swift Sources/LiveState.swift Sources/LiveViews.swift \
  -Xlinker -e -Xlinker _NSExtensionMain -Xlinker -rpath -Xlinker @executable_path/../../Frameworks \
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
cp ../schedule.json format.js "$APP/"
cp build/fonts/*.ttf "$APP/"
xcrun actool AppIcon.icon Assets.xcassets --compile "$APP" --platform "$PLAT" --minimum-deployment-target 16.2 \
  --app-icon AppIcon --target-device iphone --target-device ipad --output-partial-info-plist "$OUT/partial.plist" > "$OUT/icon.log" 2>&1 \
  || { sed 's/^/::error::/' "$OUT/icon.log" | head -20; exit 1; }
/usr/libexec/PlistBuddy -c "Merge $OUT/partial.plist" "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
# Часы: отдельное приложение внутри Watch/, ставится с айфона
WA="$APP/Watch/ParyWatch.app"
mkdir -p "$WA"
if [ "$PLAT" = iphoneos ]; then WS=watchos; WT="arm64_32-apple-watchos10.0 arm64-apple-watchos10.0"; else WS=watchsimulator; WT="arm64-apple-watchos10.0-simulator"; fi
WSDK=$(xcrun --sdk $WS --show-sdk-path)
for T in $WT; do
  xcrun --sdk $WS swiftc -O -parse-as-library -sdk "$WSDK" -target "$T" Watch/*.swift Sources/Model.swift Sources/WidgetState.swift \
    -o "$OUT/ParyWatch-$T" > "$OUT/watch.log" 2>&1 || fail "$OUT/watch.log"
done
xcrun lipo -create "$OUT"/ParyWatch-* -output "$WA/ParyWatch"
cp Watch/Info.plist "$WA/Info.plist"
plutil -replace CFBundleVersion -string "${BUILD_N:-1}" "$WA/Info.plist"
if [ "$WS" = watchsimulator ]; then
  plutil -replace CFBundleSupportedPlatforms -json '["WatchSimulator"]' "$WA/Info.plist"
  plutil -replace DTPlatformName -string watchsimulator "$WA/Info.plist"
fi
plutil -replace DTSDKName -string "$WS$(xcrun --sdk $WS --show-sdk-version)" "$WA/Info.plist"
plutil -replace DTPlatformVersion -string "$(xcrun --sdk $WS --show-sdk-version)" "$WA/Info.plist"
cp ../schedule.json build/fonts/GolosText.ttf build/fonts/JetBrainsMono.ttf "$WA/"
xcrun actool Watch/Assets.xcassets --compile "$WA" --platform $WS --minimum-deployment-target 10.0 \
  --app-icon AppIcon --target-device watch --output-partial-info-plist "$OUT/wpartial.plist" > "$OUT/wicon.log" 2>&1 \
  || { sed 's/^/::error::/' "$OUT/wicon.log" | head -20; exit 1; }
/usr/libexec/PlistBuddy -c "Merge $OUT/wpartial.plist" "$WA/Info.plist"
printf 'APPL????' > "$WA/PkgInfo"
codesign -f -s - "$WA" >/dev/null
# Подпись без сертификата, но с общей группой: Sideloadly перенесёт её в свою подпись
codesign -f -s - --entitlements ent.plist "$WX" >/dev/null
codesign -f -s - --entitlements ent.plist "$APP" >/dev/null
if [ "$PLAT" = iphoneos ]; then (cd "$OUT" && zip -qr ../../pary-native.ipa Payload); fi
echo "built $PLAT"
