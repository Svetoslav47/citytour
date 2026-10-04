#!/bin/bash
# Emulator capture helpers for the demo video.
#   cap.sh snap <name>                 one screenshot -> shots/<name>.jpeg
#   cap.sh burst <name> <seconds>      on-device screenshot loop (~7 fps), frames named by device ns time
#   cap.sh pull <name>                 copy a burst's frames to shots/<name>/
#   cap.sh tap <x> <y> | swipe x1 y1 x2 y2 ms | key <Key> | id <componentId>
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
S=127.0.0.1:5555
V="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$V/shots"
cmd="$1"; shift
case "$cmd" in
  snap)
    "$HDC" -t $S shell "snapshot_display -f /data/local/tmp/one.jpeg" >/dev/null
    "$HDC" -t $S file recv /data/local/tmp/one.jpeg "$V/shots/$1.jpeg" >/dev/null && echo "shots/$1.jpeg"
    ;;
  burst)
    name="$1"; secs="$2"
    "$HDC" -t $S shell "rm -rf /data/local/tmp/b_$name; mkdir -p /data/local/tmp/b_$name; end=\$((\$(date +%s)+$secs)); while [ \$(date +%s) -lt \$end ]; do snapshot_display -f /data/local/tmp/b_$name/\$(date +%s%N).jpeg >/dev/null 2>&1; done; ls /data/local/tmp/b_$name | wc -l"
    ;;
  pull)
    name="$1"; mkdir -p "$V/shots/$name"
    "$HDC" -t $S file recv /data/local/tmp/b_$name "$V/shots/" >/dev/null
    if [ -d "$V/shots/b_$name" ]; then rm -rf "$V/shots/$name"; mv "$V/shots/b_$name" "$V/shots/$name"; fi
    ls "$V/shots/$name" | wc -l
    ;;
  tap) "$HDC" -t $S shell uitest uiInput click "$1" "$2" >/dev/null ;;
  swipe) "$HDC" -t $S shell uitest uiInput swipe "$1" "$2" "$3" "$4" "${5:-600}" >/dev/null ;;
  key) "$HDC" -t $S shell uitest uiInput keyEvent "$1" >/dev/null ;;
  id) source /Users/svetoslaviliev/Documents/GitHub/citytour/scripts/env.sh >/dev/null 2>&1; devecocli ui click --device "Pura 90" --id "$1" 2>&1 | tail -1 ;;
  sh) "$HDC" -t $S shell "$@" ;;
  *) echo "unknown $cmd"; exit 1 ;;
esac
