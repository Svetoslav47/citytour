#!/usr/bin/env bash
# Emulator smoke run: build, install and launch on a device, check the app's own log, then run the
# SIMULATED Demo walk tour end to end and require its log events (docs/ARCHITECTURE.md §11.2; tasks T1 + A11).
# Usage: scripts/smoke.sh                       (device "Pura 90")
#        DEVICE=sdk24 scripts/smoke.sh          (any device name or serial from `devecocli device list`)
# Options (env):
#        SMOKE_DEMO=0             skip the Demo walk part (step 3): prints only "SMOKE: PASS"
#        The Demo walk part needs the Kraków course already downloaded on the device (the app ships no built-in
#        course: Home > Browse walks > Download once). On a fresh install use SMOKE_DEMO=0.
#        SMOKE_FRESH=1            uninstall first (`devecocli run --uninstall`): fresh install
#        SMOKE_DEMO_TIMEOUT=1500  seconds to wait for "STATE ... to=finished" (the full walk at x8 takes ~10-15 min)
#        SMOKE_OUT=<dir>          where run.log, app.log, demo.log and demo-*.png go (default: a temp dir)
# Prints "SMOKE+DEMO: PASS" when every Demo walk event is found, else "SMOKE+DEMO: FAIL" and the missing events.
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
RUN_ARGS=(--device "$DEVICE")
[ "${SMOKE_FRESH:-0}" = "1" ] && RUN_ARGS+=(--uninstall)
devecocli run "${RUN_ARGS[@]}" 2>&1 | tee "$OUT/run.log"
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

echo "SMOKE: PASS device=$DEVICE (logs in $OUT)"
[ "${SMOKE_DEMO:-1}" = "0" ] && { echo "SMOKE+DEMO: SKIP (SMOKE_DEMO=0)"; exit 0; }

# 3. Demo walk (task A11). DevPanel "Start demo tour" (id btnDevDemoTour) runs setSource(DEMO) -> plan -> x8 -> start
#    on the real TourController (the DevPanel default speed is x8). Then wait for the tour to finish and require
#    PACK_LOAD, ROUTE_PLAN algo=heldkarp, LOC_SOURCE kind=demo, POI_ENTER, STORY_START, UTT_DONE, STATE to=finished.
#    The whole log is captured twice: a --follow stream and --tail snapshots (union), so a rotated buffer or a
#    dropped stream cannot hide an early event. Never `--from`: the emulator clock is 6 h ahead (see step 0).
DEMO_LOG="$OUT/demo.log"
: >"$DEMO_LOG"
FOLLOW_PID=""
stop_follow() { [ -n "$FOLLOW_PID" ] && kill "$FOLLOW_PID" >/dev/null 2>&1; FOLLOW_PID=""; }
trap stop_follow EXIT
snapshot_log() {
  devecocli log --device "$DEVICE" --bundle-name "$BUNDLE" --keyword CityTour --tail 3000 >>"$DEMO_LOG" 2>&1
}

# 3a. A fresh install (SMOKE_FRESH=1 / --uninstall) opens on onboarding (task A12): skip it if it is shown.
#     A plain `devecocli run` keeps the onboardingDone flag, so the button is usually absent; ignore that failure.
if devecocli ui click --device "$DEVICE" --id btnOnbSkip >"$OUT/onboarding-skip.log" 2>&1; then
  echo "smoke.sh: onboarding shown, tapped btnOnbSkip"
  sleep 2
else
  echo "smoke.sh: no onboarding (btnOnbSkip not shown)"
fi

# 3b. Open the developer page (EntryAbility routes `--ps page dev` on hot start via onNewWant).
[ -n "${HDC:-}" ] && [ -n "$SERIAL" ] || fail "no hdc or no serial for \"$DEVICE\" (needed to open the DevPanel)"
"$HDC" -t "$SERIAL" shell aa start -a EntryAbility -b "$BUNDLE" --ps page dev >"$OUT/aa-start.log" 2>&1 \
  || fail "aa start --ps page dev failed (see $OUT/aa-start.log)"
sleep 3
devecocli log --device "$DEVICE" --bundle-name "$BUNDLE" --keyword CityTour --follow >"$OUT/demo-follow.log" 2>&1 &
FOLLOW_PID=$!

# 3c. Tap "Start demo tour".
echo "smoke.sh: devecocli ui click --device \"$DEVICE\" --id btnDevDemoTour"
devecocli ui click --device "$DEVICE" --id btnDevDemoTour >"$OUT/click.log" 2>&1 \
  || fail "ui click --id btnDevDemoTour failed (see $OUT/click.log)"

# 3d. Wait for the end of the tour (or the timeout), with one progress line per poll.
TIMEOUT_S="${SMOKE_DEMO_TIMEOUT:-1500}"
START_S=$(date +%s)
SHOT_TAKEN=0
FINISHED=0
while :; do
  sleep 15
  snapshot_log
  ALL="$(cat "$DEMO_LOG" "$OUT/demo-follow.log" 2>/dev/null)"
  ENTERS="$(printf '%s\n' "$ALL" | grep -o 'POI_ENTER id=[^ ]*' | sort -u | wc -l | tr -d ' ')"
  ELAPSED=$(( $(date +%s) - START_S ))
  echo "smoke.sh: demo t=${ELAPSED}s stops_entered=$ENTERS"
  if [ "$SHOT_TAKEN" = "0" ] && printf '%s\n' "$ALL" | grep -q "STORY_START"; then
    devecocli ui screenshot --device "$DEVICE" --path "$OUT/demo-story.png" >/dev/null 2>&1 && SHOT_TAKEN=1
  fi
  if printf '%s\n' "$ALL" | grep -Eq "STATE .*to=finished"; then FINISHED=1; break; fi
  [ "$ELAPSED" -ge "$TIMEOUT_S" ] && break
done
sleep 5
snapshot_log
stop_follow
devecocli ui screenshot --device "$DEVICE" --path "$OUT/demo-end.png" >/dev/null 2>&1 \
  || echo "smoke.sh: screenshot failed (non-fatal)"
cat "$OUT/demo-follow.log" >>"$DEMO_LOG"

# 3e. Required events (ARCHITECTURE §11.2 + A7 DoD), in one table.
MISSING=()
check() {   # check <label> <extended regex>
  if grep -Eq "$2" "$DEMO_LOG"; then
    printf '  %-26s found (%s distinct lines)\n' "$1" "$(grep -E "$2" "$DEMO_LOG" | sort -u | wc -l | tr -d ' ')"
  else
    printf '  %-26s MISSING\n' "$1"; MISSING+=("$1")
  fi
}
echo "Demo walk events (device=$DEVICE, $(( $(date +%s) - START_S ))s):"
check "PACK_LOAD"                "PACK_LOAD"
check "ROUTE_PLAN algo=heldkarp" "ROUTE_PLAN .*algo=heldkarp"
check "LOC_SOURCE kind=demo"     "LOC_SOURCE .*kind=demo"
check "POI_ENTER"                "POI_ENTER"
check "STORY_START"              "STORY_START"
check "UTT_DONE"                 "UTT_DONE"
check "STATE to=finished"        "STATE .*to=finished"
echo "  stops entered: $(grep -o 'POI_ENTER id=[^ ]*' "$DEMO_LOG" | sort -u | wc -l | tr -d ' ')" \
  "| UNCAUGHT lines: $(grep 'UNCAUGHT' "$DEMO_LOG" | sort -u | wc -l | tr -d ' ')"
if [ "${#MISSING[@]}" -gt 0 ]; then
  [ "$FINISHED" = "0" ] && echo "  (no STATE to=finished within ${TIMEOUT_S}s)"
  echo "SMOKE+DEMO: FAIL device=$DEVICE missing: ${MISSING[*]} (logs in $OUT)"
  exit 1
fi
echo "SMOKE+DEMO: PASS device=$DEVICE (logs + screenshots in $OUT)"
