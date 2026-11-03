#!/bin/bash
# Скриншоты часов из эмулятора Wear OS
set -x
cd "$(dirname "$0")"
mkdir -p build/shots
adb install -r ../pary-wear.apk
adb shell svc power stayon true
adb shell settings put system screen_off_timeout 1800000
adb shell settings put global ambient_enabled 0 || true
# Часы после первой загрузки показывают «Starting…»: ждём, пока система освободит экран
for i in $(seq 1 30); do
  adb shell dumpsys window | grep -q "mCurrentFocus.*Starting\|mCurrentFocus=null" || break
  sleep 5
done
sleep 30
adb shell input keyevent KEYCODE_WAKEUP
adb shell dumpsys window | grep mCurrentFocus
for S in "now|2026-10-29 13:20" "now|2026-10-29 10:05" "now|2026-10-29 18:30" "day|2026-10-29 13:20"; do
  IFS='|' read -r PG NOW <<< "$S"
  HM=${NOW#* }; HM=${HM/:/}
  adb shell am start -S -W -n by.cdn2041.pary/.wear.WearActivity --es shot_page "$PG" --es shot_now "\"$NOW\""
  sleep 6
  adb shell input keyevent KEYCODE_WAKEUP
  adb shell dumpsys window | grep mCurrentFocus
  sleep 1
  adb exec-out screencap -p > "build/shots/wear-$PG-$HM.png"
done
adb logcat -d -s AndroidRuntime:E > build/shots/wear-crash.txt || true
