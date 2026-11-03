#!/bin/bash
# Скриншоты приложения для часов в симуляторе
set -eo pipefail
cd "$(dirname "$0")"
mkdir -p build/shots
WA=build/iphonesimulator/Payload/Pary.app/Watch/ParyWatch.app
{ echo "== runtimes"; xcrun simctl list runtimes; } > build/shots/watch-diag.txt 2>&1
U=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[(k,x) for k,v in d.items() if "watchOS" in k for x in v]
c.sort(key=lambda t:(t[0], "Series 10" in t[1]["name"], "46" in t[1]["name"]))
print(c[-1][1]["udid"] if c else "")')
if [ -z "$U" ]; then
  RT=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys;r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="watchOS" and x["isAvailable"]];print(r[-1]["identifier"] if r else "")')
  [ -n "$RT" ] || { echo "нет симулятора часов" | tee -a build/shots/watch-diag.txt; exit 1; }
  DT=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys;t=[x for x in json.load(sys.stdin)["devicetypes"] if "Watch Series 10" in x["name"]];print(t[-1]["identifier"] if t else "")')
  U=$(xcrun simctl create "Watch" "$DT" "$RT")
fi
xcrun simctl boot "$U" || true
xcrun simctl bootstatus "$U" -b >/dev/null
xcrun simctl install "$U" "$WA" >> build/shots/watch-diag.txt 2>&1
for S in "now:2026-10-29 13:20" "now:2026-10-29 10:05" "day:2026-10-29 13:20" "now:2026-10-29 18:30"; do
  P=${S%%:*} N=${S#*:}
  SIMCTL_CHILD_SHOT_PAGE=$P SIMCTL_CHILD_SHOT_NOW="$N" xcrun simctl launch --terminate-running-process "$U" by.cdn2041.pary.watchkitapp >/dev/null
  sleep 6
  F="build/shots/watch-$P-${N#* }.png"; F=${F/:/}
  xcrun simctl io "$U" screenshot "$F" >/dev/null 2>&1 && echo "shot $F"
done
