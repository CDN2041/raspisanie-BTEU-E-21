#!/bin/bash
# Скриншоты из симулятора: iPhone и iPad, разные экраны
set -eo pipefail
cd "$(dirname "$0")"
mkdir -p build/shots
APP=build/iphonesimulator/Payload/Pary.app
NOW="${SHOT_NOW:-2026-10-29 13:20}"
pick() {
  xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]; want=sys.argv[1]; bad=sys.argv[2]
c=[(k,x) for k,v in d.items() if "iOS" in k for x in v if want in x["name"] and (not bad or bad not in x["name"])]
c.sort(key=lambda t:(t[0],t[1]["name"]))
print(c[-1][1]["udid"] if c else "")' "$1" "$2"
}
shoot() { # устройство, префикс, экраны...
  local U=$1 P=$2; shift 2
  xcrun simctl boot "$U" || true
  xcrun simctl bootstatus "$U" -b >/dev/null
  xcrun simctl status_bar "$U" override --time "${NOW#* }" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  xcrun simctl install "$U" "$APP"
  # Проверка: видит ли система виджет приложения
  { echo "== $P pluginkit"; xcrun simctl spawn "$U" pluginkit -m -A -D -v -p com.apple.widgetkit-extension 2>&1 | grep -i -A2 pary || echo "не найден"
    echo "== appex"; ls -la "$APP/PlugIns/ParyWidget.appex"; codesign -d --entitlements - "$APP/PlugIns/ParyWidget.appex" 2>&1 | tail -5
    echo "== otool"; otool -l "$APP/PlugIns/ParyWidget.appex/ParyWidget" | grep -A3 LC_MAIN; nm "$APP/PlugIns/ParyWidget.appex/ParyWidget" | grep -i "_main\|NSExtensionMain" | head; } >> build/shots/diag.txt 2>&1
  for S in "$@"; do
    local SC=${S%%:*} TH=${S#*:}
    xcrun simctl ui "$U" appearance $([ "$TH" = light ] && echo light || echo dark)
    SIMCTL_CHILD_SHOT_SCREEN=$SC SIMCTL_CHILD_SHOT_NOW="$NOW" SIMCTL_CHILD_SHOT_THEME=$TH \
      xcrun simctl launch --terminate-running-process "$U" by.cdn2041.pary >/dev/null
    sleep 6
    xcrun simctl io "$U" screenshot "build/shots/$P-$SC-$TH.png" >/dev/null 2>&1
    echo "shot $P-$SC-$TH"
  done
  # Экран «Домой»: иконка в светлой и тёмной теме
  xcrun simctl terminate "$U" by.cdn2041.pary || true
  for TH in light dark; do
    xcrun simctl ui "$U" appearance $TH; sleep 3
    xcrun simctl io "$U" screenshot "build/shots/$P-springboard-$TH.png" >/dev/null 2>&1
  done
  xcrun simctl shutdown "$U" || true
}
PH=$(pick "iPhone" "Max"); PH=${PH:-$(pick "iPhone" "")}
PAD=$(pick "iPad Pro 11" ""); PAD=${PAD:-$(pick "iPad" "mini")}
echo "iPhone $PH, iPad $PAD"
shoot "$PH" phone editor:dark
[ -n "$PAD" ] && shoot "$PAD" ipad home:dark
ls build/shots
