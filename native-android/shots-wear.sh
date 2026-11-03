#!/bin/bash
# Скриншоты часов из эмулятора Wear OS
set -x
cd "$(dirname "$0")"
mkdir -p build/shots
adb install -r ../pary-wear.apk
for S in "now|2026-10-29 13:20" "now|2026-10-29 10:05" "now|2026-10-29 18:30" "day|2026-10-29 13:20"; do
  IFS='|' read -r PG NOW <<< "$S"
  HM=${NOW#* }; HM=${HM/:/}
  adb shell am start -S -W -n by.cdn2041.pary/.wear.WearActivity --es shot_page "$PG" --es shot_now "\"$NOW\""
  sleep 5
  adb exec-out screencap -p > "build/shots/wear-$PG-$HM.png"
done
adb logcat -d -s AndroidRuntime:E > build/shots/wear-crash.txt || true
