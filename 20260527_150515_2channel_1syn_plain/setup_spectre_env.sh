#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"

if [ -z "${SPECTRE_BIN:-}" ]; then
  if command -v spectre >/dev/null 2>&1; then
    SPECTRE_BIN="$(command -v spectre)"
  else
    SPECTRE_BIN="/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/spectre/bin/64bit/spectre"
  fi
fi

if [ ! -x "$SPECTRE_BIN" ]; then
  echo "ERROR: SPECTRE_BIN is not executable: $SPECTRE_BIN" >&2
  return 1 2>/dev/null || exit 1
fi

SPECTRE_BIN_DIR="$(cd "$(dirname "$SPECTRE_BIN")" && pwd)"
SPECTRE_HOME="$(cd "$SPECTRE_BIN_DIR/../.." && pwd)"
CAD_TOOLS_HOME="$(cd "$SPECTRE_HOME/.." && pwd)"

export SPECTRE_BIN
export PATH="$SPECTRE_BIN_DIR:$PATH"

for d in \
  "$SPECTRE_HOME/lib/64bit" \
  "$SPECTRE_HOME/lib" \
  "$SPECTRE_HOME/tools/64bit/lib" \
  "$CAD_TOOLS_HOME/lib/64bit" \
  "$CAD_TOOLS_HOME/lib" \
  "$CAD_TOOLS_HOME/tools.lnx86/lib/64bit" \
  "$CAD_TOOLS_HOME/tools.lnx86/lib" \
  "/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/lib/64bit" \
  "/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/lib";
do
  if [ -d "$d" ]; then
    case ":${LD_LIBRARY_PATH:-}:" in
      *":$d:"*) ;;
      *) export LD_LIBRARY_PATH="$d:${LD_LIBRARY_PATH:-}" ;;
    esac
  fi
done
