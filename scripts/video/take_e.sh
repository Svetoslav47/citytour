#!/bin/bash
# Take E: Demo walk on Scholars and Saints; mid-story language switch EN -> PL -> ZH driven by the live hilog.
V="$(cd "$(dirname "$0")" && pwd)"
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
S=127.0.0.1:5555
count() { # number of NARR_AUDIO story lines (poi clips) for a language so far
  "$HDC" -t $S shell "hilog -x 2>/dev/null | grep 'NARR_AUDIO src=' | grep 'lang=$1' | grep -c '/poi_wd_'" 2>/dev/null | tr -d '\r '
}
wait_new() { # wait until count(lang) > base, up to $3 seconds
  local lang=$1 base=$2 limit=$3 t0=$(date +%s)
  while [ $(( $(date +%s) - t0 )) -lt $limit ]; do
    c=$(count $lang); [ -n "$c" ] && [ "$c" -gt "$base" ] && return 0; sleep 0.3
  done; return 1
}
en0=$(count en); pl0=$(count pl); zh0=$(count zh)
echo "base en=$en0 pl=$pl0 zh=$zh0"
( "$V/cap.sh" burst E 75 > "$V/shots/E.count" 2>&1 & )
sleep 0.8
"$V/cap.sh" tap 1006 2086         # Demo walk on the Scholars and Saints card
sleep 2.5
if ! "$HDC" -t $S shell "hilog -x | tail -400 | grep -q 'ev=START_TOUR'"; then "$V/cap.sh" tap 937 1600; echo "confirmed end-tour"; fi
echo "demo tap $(date +%T)"
wait_new en $en0 40 && echo "EN story started $(date +%T)" || echo "no EN story"
sleep 2.0
"$V/cap.sh" tap 1208 248; sleep 1.2; "$V/cap.sh" tap 980 947   # menu -> Continue in Polski
echo "PL tap $(date +%T)"
wait_new pl $pl0 25 && echo "PL story started $(date +%T)" || echo "no PL story"
sleep 3.0
"$V/cap.sh" tap 1208 248; sleep 1.2; "$V/cap.sh" tap 962 1115  # menu -> Continue in 中文
echo "ZH tap $(date +%T)"
wait_new zh $zh0 25 && echo "ZH story started $(date +%T)" || echo "no ZH story"
sleep 8
echo done
