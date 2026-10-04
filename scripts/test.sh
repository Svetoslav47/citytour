#!/usr/bin/env bash
# Run the local unit tests and the source guards; exit non-zero on any failure.
# `hvigorw test` exits 0 even when tests fail (docs/ARCHITECTURE.md §11.1), so this script
# parses the result file instead of trusting the exit code.
# Usage: scripts/test.sh            (from anywhere inside the repo)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

RESULT="entry/.test/default/intermediates/test/coverage_data/test_result.txt"
fail() { echo "TESTS: FAIL ($*)"; exit 1; }

# 1. Guards (cheap, run first).
# The common HAR (contracts/, core/, control/TourController, app/LogEvents + Clock) must stay pure: the local test
# runner cannot load system APIs, and the tests import everything through the common/Index.ets barrel.
if grep -rnE "@kit\.|@ohos\." common/src/main/ets common/Index.ets 2>/dev/null; then
  fail "@kit/@ohos import in the common HAR (it must stay pure)"
fi
# State Management V2 only: reject V1 decorators (@ComponentV2, @ObservedV2, @Provider, @Consumer pass).
# One temporary exemption: pages/Index.ets while it is still byte-identical to the DevEco
# "Empty Ability" scaffold (git blob below). Task B4 replaces that page; any edit to it ends the exemption.
SCAFFOLD_INDEX="entry/src/main/ets/pages/Index.ets"
SCAFFOLD_INDEX_BLOB="55f76030d37ad705b262acdb3cbc8dc49a5d0af4"
V1_HITS="$(grep -rnE '@(Component|State|Prop|Link|ObjectLink|Observed|Track|Watch|Provide|Consume|StorageLink|StorageProp)([^A-Za-z0-9_]|$)' entry/src/main/ets common/src/main/ets)"
if [ -f "$SCAFFOLD_INDEX" ] && [ "$(git hash-object "$SCAFFOLD_INDEX")" = "$SCAFFOLD_INDEX_BLOB" ]; then
  echo "test.sh: V1 guard skips $SCAFFOLD_INDEX (unmodified DevEco scaffold, replaced by task B4)"
  V1_HITS="$(printf '%s\n' "$V1_HITS" | grep -v "^$SCAFFOLD_INDEX:")"
fi
# ArkTS cards support state management V2 only from API 23 (doc arkts-v1-v2-migration-card); the app's minimum is
# API 20, so the home-screen card page (B14) stays on V1 (@Entry(LocalStorage) + @Component + @LocalStorageProp).
V1_HITS="$(printf '%s\n' "$V1_HITS" | grep -v '^entry/src/main/ets/widget/pages/' || true)"
if [ -n "$V1_HITS" ]; then
  printf '%s\n' "$V1_HITS"
  fail "V1 state-management decorator found (use V2: @ComponentV2, @Local, @Param, @ObservedV2, @Trace ...)"
fi

# 2. Dependencies (oh_modules is gitignored, so a fresh worktree needs an install).
if [ ! -d oh_modules/@ohos/hypium ]; then
  echo "test.sh: installing ohpm dependencies"
  PATH="$DEVECO_NODE_BIN:$PATH" "$OHPM" install --all >/dev/null || fail "ohpm install"
fi

# 3. ArkTS local unit tests. Delete the old result first: a stale file would fake a pass.
rm -f "$RESULT"
LOG="$(mktemp -t citytour-test.XXXXXX)"
PATH="$DEVECO_NODE_BIN:$PATH" "$HVIGORW" test -p module=entry -p coverage=false --no-daemon >"$LOG" 2>&1
HV_EXIT=$?
if [ ! -f "$RESULT" ]; then
  tail -n 40 "$LOG"
  fail "no result file $RESULT (hvigorw exit=$HV_EXIT, full log: $LOG)"
fi
SUMMARY="$(grep -E 'Tests run: [0-9]+' "$RESULT" | tail -n 1)"
[ -n "$SUMMARY" ] || { cat "$RESULT"; fail "no 'Tests run:' line in $RESULT"; }
num() { echo "$SUMMARY" | sed -nE "s/.*$1: ([0-9]+).*/\1/p"; }
RUN="$(num 'Tests run')"; FAILURES="$(num Failure)"; ERRORS="$(num Error)"
echo "ArkTS: $SUMMARY"
if [ "${RUN:-0}" -eq 0 ] || [ "${FAILURES:-1}" -ne 0 ] || [ "${ERRORS:-1}" -ne 0 ]; then
  # Print each failing case as "<suite> <test>: <message>"; fall back to the raw file.
  awk '/^class=/{c=substr($0,7)} /^test=/{t=substr($0,6)} /^Error in /{print "  FAILED " c " " t ": " substr($0,10); n++}
       END{exit n==0}' "$RESULT" || cat "$RESULT"
  fail "run=$RUN failure=$FAILURES error=$ERRORS"
fi
rm -f "$LOG"

# 4. Node pipeline tests, once any exist (explicit file list: works on every Node version).
PACK_TESTS=()
while IFS= read -r t; do PACK_TESTS+=("$t"); done < <(find scripts/pack scripts/voice scripts/demo -name '*.test.mjs' 2>/dev/null | sort)
if [ "${#PACK_TESTS[@]}" -gt 0 ]; then
  node --test "${PACK_TESTS[@]}" || fail "node --test scripts/pack scripts/voice scripts/demo (${#PACK_TESTS[@]} files)"
  echo "Pipeline: ${#PACK_TESTS[@]} node test file(s) passed"
fi

echo "TESTS: PASS n=$RUN"
