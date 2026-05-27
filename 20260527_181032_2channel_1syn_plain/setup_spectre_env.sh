#!/usr/bin/env bash

export SPECTRE_BIN="${SPECTRE_BIN:-/projects/bics/cadence/installs/SPECTRE231/tools.lnx86/spectre/bin/64bit/spectre}"
export CADENCE_INSTALL_ROOT="${CADENCE_INSTALL_ROOT:-/projects/bics/cadence/installs}"

# Broad but deterministic Cadence runtime library path.
# This is intentionally wider than before because direct spectre depends on
# shared libraries spread across SPECTRE231, IC231, and sometimes XCELIUM.
_extra_libs="$(
  find "$CADENCE_INSTALL_ROOT" \
    \( -type d \( \
      -path "*/tools.lnx86/lib" -o \
      -path "*/tools.lnx86/lib/64bit" -o \
      -path "*/tools.lnx86/spectre/lib" -o \
      -path "*/tools.lnx86/spectre/lib/64bit" -o \
      -path "*/tools.lnx86/dfII/lib" -o \
      -path "*/tools.lnx86/dfII/lib/64bit" -o \
      -path "*/tools.lnx86/oa/lib/linux_rhel60_64/opt" -o \
      -path "*/tools.lnx86/oa/lib/linux_rhel60_64/dbg" -o \
      -path "*/tools.lnx86/inca/lib" -o \
      -path "*/tools.lnx86/inca/lib/64bit" \
    \) \) -print 2>/dev/null | awk '!seen[$0]++' | paste -sd:
)"

export LD_LIBRARY_PATH="${_extra_libs}:${LD_LIBRARY_PATH:-}"
export PATH="$(dirname "$SPECTRE_BIN"):${PATH}"

check_spectre_runtime() {
  if [ ! -x "$SPECTRE_BIN" ]; then
    echo "SPECTRE_BIN not executable: $SPECTRE_BIN"
    return 1
  fi

  ldd "$SPECTRE_BIN" | grep "not found" || true
}
