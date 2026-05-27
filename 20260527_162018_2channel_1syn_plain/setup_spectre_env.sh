#!/usr/bin/env bash
RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
if [ -f "$RUN_DIR/support/spectre_runtime.env" ]; then
  source "$RUN_DIR/support/spectre_runtime.env"
fi
export SPECTRE_BIN
check_spectre_runtime() {
  ldd "$SPECTRE_BIN" 2>/dev/null | grep -i 'not found' || true
}
export -f check_spectre_runtime 2>/dev/null || true
