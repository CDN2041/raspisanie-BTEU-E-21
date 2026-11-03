#!/bin/bash
# Скриншоты из эмулятора: разные экраны, время и темы
set -x
cd "$(dirname "$0")"
mkdir -p build/shots
adb install -r ../pary-native.apk
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
for S in "home|2026-10-29 13:20|dark" "home|2026-10-29 10:05|light" "home|2026-10-29 18:30|dark" \
         "full|2026-10-29 13:20|dark" "full|2026-10-29 13:20|light" "settings|2026-10-29 13:20|dark" \
         "note|2026-10-29 13:20|light" "calendar|2026-10-29 13:20|dark"; do
  IFS='|' read -r SC NOW TH <<< "$S"
  HM=${NOW#* }; HM=${HM/:/}
  adb shell am start -S -W -n by.cdn2041.pary/.MainActivity --es shot_screen "$SC" --es shot_now "\"$NOW\"" --es shot_theme "$TH"
  sleep 5
  adb exec-out screencap -p > "build/shots/android-$SC-$HM-$TH.png"
done
adb logcat -d -s AndroidRuntime:E > build/shots/android-crash.txt || true
ls -la build/shots
