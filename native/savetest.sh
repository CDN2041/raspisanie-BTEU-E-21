#!/bin/bash
# Проверка сохранения из нативного редактора: временный ключ сборки, отдельная ветка, main не трогается
set -o pipefail
cd "$(dirname "$0")"
mkdir -p build/shots
OUT=build/shots/savetest.txt
B=native-savetest
APP=build/iphonesimulator/Payload/Pary.app
git push -f -q origin HEAD:refs/heads/$B || { echo "не удалось создать ветку" > $OUT; exit 0; }
U=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[(k,x) for k,v in d.items() if "iOS" in k for x in v if "iPhone" in x["name"] and "Max" not in x["name"]]
c.sort(key=lambda t:(t[0],t[1]["name"])); print(c[-1][1]["udid"])')
xcrun simctl boot "$U" || true
xcrun simctl bootstatus "$U" -b >/dev/null
xcrun simctl install "$U" "$APP"
SIMCTL_CHILD_SHOT_SCREEN=savetest SIMCTL_CHILD_SHOT_NOW="2026-10-29 13:20" SIMCTL_CHILD_SHOT_THEME=dark \
SIMCTL_CHILD_TEST_TOKEN="$GH_TOKEN" SIMCTL_CHILD_TEST_BRANCH=$B \
  xcrun simctl launch --terminate-running-process "$U" by.cdn2041.pary >/dev/null
sleep 30
xcrun simctl io "$U" screenshot build/shots/phone-savetest.png >/dev/null 2>&1
C=$(xcrun simctl get_app_container "$U" by.cdn2041.pary data)
{ echo "== приложение"; cat "$C/Documents/selftest.txt" 2>/dev/null || echo "нет файла"; } > $OUT
gh api "repos/$GITHUB_REPOSITORY/contents/schedule.json?ref=$B" --jq .content | base64 -d > build/after.json
gh api "repos/$GITHUB_REPOSITORY/commits?sha=$B&per_page=1" --jq '.[0].commit.message + " | " + .[0].commit.author.name' >> $OUT
python3 - ../schedule.json build/after.json >> $OUT <<'PY'
import json,sys,difflib
a=open(sys.argv[1]).read(); b=open(sys.argv[2]).read()
ja=json.loads(a); jb=json.loads(b)
print("== сравнение")
d=[l for l in difflib.unified_diff(a.splitlines(),b.splitlines(),lineterm="",n=0) if not l.startswith(("---","+++","@@"))]
print("\n".join(d))
ja.pop("updated");jb.pop("updated")
cj=jb["changes"].get("2026-10-26",[])
ok=any(c.get("p")==1 and c.get("cancel") for c in cj)
jb["changes"]["2026-10-26"]=[c for c in cj if not (c.get("p")==1 and c.get("cancel"))]
if not jb["changes"]["2026-10-26"]: del jb["changes"]["2026-10-26"]
print("ИТОГ:", "OK" if ok and ja==jb else "РАЗЛИЧИЕ")
PY
git push -q origin --delete $B || true
xcrun simctl shutdown "$U" || true
cat $OUT
