#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
OUT="$RUN_DIR/support/spectre_runtime.env"
TMP="$OUT.tmp"
: > "$TMP"
echo "# generated $(date -Is)" >> "$TMP"
echo "export SPECTRE_BIN=\"$SPECTRE_BIN\"" >> "$TMP"
declare -a DIRS=()
add_dir() { [ -d "$1" ] && DIRS+=("$1"); }
SPECTRE_BIN_DIR="$(cd "$(dirname "$SPECTRE_BIN")" && pwd)"
add_dir "$SPECTRE_BIN_DIR"
add_dir "$(cd "$SPECTRE_BIN_DIR/../.." 2>/dev/null && pwd)/lib/64bit"
add_dir "$(cd "$SPECTRE_BIN_DIR/../.." 2>/dev/null && pwd)/lib"
add_dir "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/spectre/lib/64bit"
add_dir "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/spectre/lib"
add_dir "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/lib/64bit"
add_dir "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/lib"
add_dir "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/lib/64bit"
add_dir "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/lib"
add_dir "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/dfII/lib/64bit"
add_dir "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/dfII/lib"
add_dir "$CADENCE_INSTALL_ROOT/IC231/tools.lnx86/oa/lib/linux_rhel70_gcc93x_64/opt"
add_dir "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/oa/lib/linux_rhel70_gcc93x_64/opt"

# Resolve missing libraries iteratively, but only during refresh, never during worker startup.
for pass in 1 2 3 4; do
  export LD_LIBRARY_PATH="$(IFS=:; echo "${DIRS[*]}"):${LD_LIBRARY_PATH:-}"
  missing=$(ldd "$SPECTRE_BIN" 2>/dev/null | awk '/not found/{print $1}' | sort -u || true)
  [ -z "$missing" ] && break
  while read -r lib; do
    [ -z "$lib" ] && continue
    found=$(find "$CADENCE_INSTALL_ROOT" -name "$lib" -type f -print -quit 2>/dev/null || true)
    if [ -n "$found" ]; then
      DIRS+=("$(dirname "$found")")
    fi
  done <<< "$missing"
done
# de-duplicate while preserving order
LD=""
for d in "${DIRS[@]}"; do
  [ -d "$d" ] || continue
  case ":$LD:" in *":$d:"*) ;; *) LD="$d${LD:+:$LD}" ;; esac
done
echo "export PATH=\"$SPECTRE_BIN_DIR:\${PATH:-}\"" >> "$TMP"
echo "export LD_LIBRARY_PATH=\"$LD:\${LD_LIBRARY_PATH:-}\"" >> "$TMP"
mv "$TMP" "$OUT"
echo "Wrote $OUT"
source "$OUT"
echo "Missing after refresh, if any:"
ldd "$SPECTRE_BIN" 2>/dev/null | grep 'not found' || echo "none"
