#!/usr/bin/env bash
# Source this before running plain Spectre workers.
# It sets a broad Cadence runtime library path without relying on GUI startup scripts.

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$this_dir/RUNINFO.txt"

export SPECTRE_BIN="${SPECTRE_BIN:-/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/spectre/bin/64bit/spectre}"
export SPECTRE_CMD="${SPECTRE_CMD:-$SPECTRE_BIN}"
export CADENCE_INSTALL_ROOT="${CADENCE_INSTALL_ROOT:-/projects/bics/cadence/installs}"

append_existing_dir() {
  [ -d "$1" ] || return 0
  case ":${LD_LIBRARY_PATH:-}:" in
    *":$1:"*) ;;
    *) export LD_LIBRARY_PATH="$1${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
  esac
}

# Deliberately broad but deterministic library search set for BICS Cadence installs.
for d in \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/lib" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/spectre/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/spectre/lib" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/dfII/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/dfII/lib" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/oa/lib/linux_rhel60_64/opt" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/oa/lib/linux_rhel60_64/dbg" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/lib" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/dfII/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/dfII/lib" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/oa/lib/linux_rhel60_64/opt" \
  "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/oa/lib/linux_rhel60_64/dbg" \
  "$CADENCE_INSTALL_ROOT/XCELIUM2309/tools.lnx86/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/XCELIUM2309/tools.lnx86/lib" \
  "$CADENCE_INSTALL_ROOT/XCELIUM2309/tools.lnx86/inca/lib/64bit" \
  "$CADENCE_INSTALL_ROOT/XCELIUM2309/tools.lnx86/inca/lib"; do
  append_existing_dir "$d"
done

export PATH="$(dirname "$SPECTRE_BIN"):${PATH:-}"

spectre_runtime_report() {
  if [ ! -x "$SPECTRE_BIN" ]; then
    echo "SPECTRE_BIN is not executable: $SPECTRE_BIN"
    return 1
  fi
  ldd "$SPECTRE_BIN" 2>/dev/null | awk '/not found/{print "  " $1 " => not found"}' || true
}

spectre_runtime_ok() {
  [ -x "$SPECTRE_BIN" ] || return 1
  ! ldd "$SPECTRE_BIN" 2>/dev/null | grep -q 'not found'
}

check_spectre_runtime() {
  local missing
  missing="$(spectre_runtime_report || true)"
  if [ -z "$missing" ]; then
    echo "Spectre runtime OK: $SPECTRE_BIN"
    return 0
  fi
  echo "Runtime missing libs, if any:"
  echo "$missing"
  return 1
}
