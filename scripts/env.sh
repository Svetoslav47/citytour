# shellcheck shell=bash
# Toolchain environment for the CityTour command-line scripts (source it: `source scripts/env.sh`).
# Paths are the DevEco Studio 6.1.1 defaults on macOS (docs/ARCHITECTURE.md §11.1, docs/PLAN.md §0.2).
# Override DEVECO_HOME before sourcing if DevEco Studio is installed elsewhere.
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
export DEVECO_HOME
export DEVECO_SDK_HOME="$DEVECO_HOME/sdk"
# hvigorw runs on DevEco's bundled Node 18 (ARCHITECTURE §11.1); scripts/test.sh puts DEVECO_NODE_BIN first
# for that one call. Here it is only APPENDED to PATH: devecocli needs a newer Node and fails with a
# regex SyntaxError when Node 18 comes first.
export DEVECO_NODE_BIN="$DEVECO_HOME/tools/node/bin"
case ":$PATH:" in
  *":$DEVECO_NODE_BIN:"*) ;;
  *) export PATH="$PATH:$DEVECO_NODE_BIN" ;;
esac
export HVIGORW="$DEVECO_HOME/tools/hvigor/bin/hvigorw"
export OHPM="$DEVECO_HOME/tools/ohpm/bin/ohpm"
# hdc is not on PATH; use "$HDC -t <serial> shell ..."
export HDC="$DEVECO_SDK_HOME/default/openharmony/toolchains/hdc"
