#!/usr/bin/env bash
# Emulator smoke run: build, install and launch on a device, then check the app's own log.
# Skeleton from task T1; task A11 adds the Demo walk steps (docs/ARCHITECTURE.md §11.2).
# Usage: scripts/smoke.sh                 (device "Pura 90")
#        DEVICE=sdk24 scripts/smoke.sh    (any device name or serial from `devecocli device list`)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

DEVICE="${DEVICE:-Pura 90}"
BUNDLE="com.hackyeah.citytour"
OUT="${SMOKE_OUT:-$(mktemp -d -t citytour-smoke.XXXXXX)}"
fail() { echo "SMOKE: FAIL ($*; logs in $OUT)"; exit 1; }

# 0. Clear the device log buffer so an APP_START from an earlier run can't fake a pass.
#    (We can't filter by time: the emulator clock runs in CST, 6 h ahead of CEST, so `--from` drops every line.)
SERIAL="$(devecocli device list 2>/dev/null | awk -v d="$DEVICE" 'index($0,d)==1 || $2==d {for(i=1;i<=NF;i++) if ($i ~ /^[0-9.]+:[0-9]+$/) print $i}' | head -1)"
if [ -n "${HDC:-}" ] && [ -n "$SERIAL" ]; then "$HDC" -t "$SERIAL" shell hilog -r >/dev/null 2>&1 || true; fi

# 1. Build + install + launch. devecocli's own check prints "Smoke: PASS" (no crash, not blank).
echo "smoke.sh: devecocli run --device \"$DEVICE\""
devecocli run --device "$DEVICE" 2>&1 | tee "$OUT/run.log"
RUN_EXIT=${PIPESTATUS[0]}
grep -q "Smoke: PASS" "$OUT/run.log" || fail "devecocli run did not print Smoke: PASS (exit=$RUN_EXIT)"

# 2. App log: APP_START (app/Log.ets, domain 0xC17A, tag CityTour; emitted by EntryAbility from task T0).
sleep 3
devecocli log --device "$DEVICE" --bundle-name "$BUNDLE" --keyword CityTour --tail 500 >"$OUT/app.log" 2>&1
if grep -q "APP_START" "$OUT/app.log"; then
  echo "APP_START: found"
elif ! grep -rqs "APP_START" entry/src/main/ets; then
  # Self-activating: becomes mandatory as soon as the source emits APP_START.
  echo "APP_START: SKIP (not emitted by this build yet; EntryAbility logs it once task T0 lands)"
else
  fail "APP_START not found in the CityTour log"
fi

# 3. Demo walk (task A11): tap btnDemoWalk, wait, then require PACK_LOAD, ROUTE_PLAN algo=heldkarp,
#    LOC_SOURCE kind=demo, POI_ENTER and STORY_START in the log (docs/ARCHITECTURE.md §11.2).

echo "SMOKE: PASS device=$DEVICE (logs in $OUT)"
