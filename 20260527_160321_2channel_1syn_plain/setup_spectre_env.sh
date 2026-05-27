#!/usr/bin/env bash
# Source this file before invoking the direct Spectre binary.
# v6 searches both SPECTRE231 and IC231/other Cadence install trees for the
# shared libraries that the direct Spectre binary needs.

RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"

if [ -z "${SPECTRE_BIN:-}" ]; then
  SPECTRE_BIN="/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/spectre/bin/64bit/spectre"
fi
if [ ! -x "$SPECTRE_BIN" ]; then
  echo "ERROR: SPECTRE_BIN not executable: $SPECTRE_BIN" >&2
  return 1 2>/dev/null || exit 1
fi

prepend_path() {
  [ -d "${1:-}" ] || return 0
  case ":${PATH:-}:" in *":$1:"*) ;; *) export PATH="$1:${PATH:-}" ;; esac
}
prepend_ld() {
  [ -d "${1:-}" ] || return 0
  case ":${LD_LIBRARY_PATH:-}:" in *":$1:"*) ;; *) export LD_LIBRARY_PATH="$1:${LD_LIBRARY_PATH:-}" ;; esac
}

SPECTRE_BIN_DIR="$(cd "$(dirname "$SPECTRE_BIN")" && pwd)"
SPECTRE_HOME="$(cd "$SPECTRE_BIN_DIR/../.." && pwd)"
SPECTRE_TOOLS="$(cd "$SPECTRE_HOME/.." && pwd)"
SPECTRE_INSTALL="$(cd "$SPECTRE_TOOLS/.." && pwd)"
CADENCE_INSTALL_ROOT="${CADENCE_INSTALL_ROOT:-/projects/bics/cadence/installs}"

export SPECTRE_BIN
prepend_path "$SPECTRE_BIN_DIR"

# High-probability locations first.
for d in \
  "$SPECTRE_HOME/lib/64bit" "$SPECTRE_HOME/lib" \
  "$SPECTRE_TOOLS/lib/64bit" "$SPECTRE_TOOLS/lib" \
  "$SPECTRE_TOOLS/spectre/lib/64bit" "$SPECTRE_TOOLS/spectre/lib" \
  "$SPECTRE_INSTALL/lib/64bit" "$SPECTRE_INSTALL/lib" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/lib" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/dfII/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/dfII/lib" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/oa/lib/linux_rhel70_gcc93x_64/opt" \
  "$CADENCE_INSTALL_ROOT/IC231/oa_v22.61.002/lib/linux_rhel70_gcc93x_64/opt" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/oa_v22.61.002/lib/linux_rhel70_gcc93x_64/opt"; do
  prepend_ld "$d"
done

# Resolve known missing direct-Spectre libraries from anywhere under the
# Cadence install tree. This is the important v5 fix.
if [ -d "$CADENCE_INSTALL_ROOT" ]; then
  while IFS= read -r lib; do
    prepend_ld "$(dirname "$lib")"
  done < <(find "$CADENCE_INSTALL_ROOT" \
    \( -name 'libSpectreEH_sh.so' -o -name 'libfmc.so' -o -name 'libvisadev.so' -o -name 'libabv.so' -o -name 'libcds*.so' -o -name 'liboa*.so' -o -name 'libdd*.so' \) \
    -type f 2>/dev/null | sort -u)
fi

check_spectre_runtime() {
  if command -v ldd >/dev/null 2>&1; then
    ldd "$SPECTRE_BIN" 2>/dev/null | grep -i 'not found' || true
  fi
}
export -f check_spectre_runtime 2>/dev/null || true
