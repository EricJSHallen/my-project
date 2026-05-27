#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"

# Robust runtime setup for invoking the Spectre binary directly from a non-Cadence shell.
# The previous version added common library folders, but on this installation the required
# libSpectreEH_sh.so may live in a less obvious directory. This script searches the install
# tree once and prepends every directory containing Cadence/Spectre shared libraries.

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
TOOLS_HOME="$(cd "$SPECTRE_HOME/.." && pwd)"
INSTALL_ROOT="$(cd "$TOOLS_HOME/.." && pwd)"

prepend_path() {
  [ -n "${1:-}" ] || return 0
  [ -d "$1" ] || return 0
  case ":${PATH:-}:" in
    *":$1:"*) ;;
    *) export PATH="$1:${PATH:-}" ;;
  esac
}

prepend_ld() {
  [ -n "${1:-}" ] || return 0
  [ -d "$1" ] || return 0
  case ":${LD_LIBRARY_PATH:-}:" in
    *":$1:"*) ;;
    *) export LD_LIBRARY_PATH="$1:${LD_LIBRARY_PATH:-}" ;;
  esac
}

export SPECTRE_BIN
prepend_path "$SPECTRE_BIN_DIR"

# First add the usual library directories.
for d in \
  "$SPECTRE_HOME/lib/64bit" \
  "$SPECTRE_HOME/lib" \
  "$SPECTRE_HOME/tools/64bit/lib" \
  "$SPECTRE_HOME/tools/lib" \
  "$TOOLS_HOME/lib/64bit" \
  "$TOOLS_HOME/lib" \
  "$INSTALL_ROOT/lib/64bit" \
  "$INSTALL_ROOT/lib" \
  "/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/lib/64bit" \
  "/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/lib" \
  "/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/spectre/lib/64bit" \
  "/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/spectre/lib"; do
  prepend_ld "$d"
done

# Then explicitly search for the failing runtime library and related Spectre/Cadence .so files.
# Limit to the install root to avoid scanning all of /projects.
if [ -d "$INSTALL_ROOT" ]; then
  while IFS= read -r lib; do
    prepend_ld "$(dirname "$lib")"
  done < <(find "$INSTALL_ROOT" \( -name 'libSpectreEH_sh.so' -o -name 'libcds*.so' -o -name 'liboa*.so' -o -name 'libdd*.so' \) -type f 2>/dev/null | sort -u)
fi

# Final diagnostic. This does not fail the source step; it only records unresolved libs in worker logs.
check_spectre_runtime() {
  if command -v ldd >/dev/null 2>&1; then
    ldd "$SPECTRE_BIN" 2>/dev/null | grep -i "not found" || true
  fi
}
export -f check_spectre_runtime 2>/dev/null || true
