#!/usr/bin/env bash
# Builds the offline Kraków city pack (task B2) into entry/src/main/resources/rawfile/packs/krakow/.
#
# Reads only committed inputs (data/raw/**, data/tours/royal-route.json); the network is disabled inside the
# build (scripts/pack/90-emit.mjs). Deterministic: running it twice gives byte-identical files (no clock, stable
# sorts, fixed number formatting). The fetch scripts (scripts/pack/*-fetch-*.mjs, task B1) are NOT run here;
# re-fetching raw data is a separate, deliberate step (data/raw/SOURCES.md).
#
# Usage: scripts/pack/build-pack.sh [--out DIR]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
node -e 'if (Number(process.versions.node.split(".")[0]) < 22) { console.error(`build-pack: Node 22+ required, found ${process.version}`); process.exit(1); }'
exec node scripts/pack/90-emit.mjs "$@"
