#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$RUN_DIR/RUNINFO.txt"
mkdir -p "$RUN_DIR/support" "$RUN_DIR/logs"
LOG="$RUN_DIR/logs/refresh_spectre_runtime.log"
: > "$LOG"

# Try to find a non-ELF wrapper first. If present, it is preferable to raw ELF.
for cand in \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools/bin/spectre" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/bin/spectre" \
  "$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/bin/spectre" \
  "$(command -v spectre 2>/dev/null || true)"; do
  if [ -n "$cand" ] && [ -x "$cand" ] && ! file "$cand" 2>/dev/null | grep -qi 'ELF'; then
    {
      echo "export SPECTRE_CMD='$cand'"
      echo "export PATH='$(dirname "$cand")':\${PATH:-}"
    } > "$RUN_DIR/support/spectre_runtime.env"
    echo "Using Spectre wrapper: $cand" | tee -a "$LOG"
    exit 0
  fi
done

# Otherwise build a broad runtime path for raw Spectre.
SPECTRE_RAW="${SPECTRE_CMD:-$CADENCE_INSTALL_ROOT/SPECTRE231/tools.lnx86/spectre/bin/64bit/spectre}"
if [ ! -x "$SPECTRE_RAW" ]; then
  echo "ERROR: no executable Spectre found." | tee -a "$LOG" >&2
  exit 1
fi

needed="$(ldd "$SPECTRE_RAW" 2>/dev/null | awk '/not found/{print $1}' | sort -u || true)"
libdirs=""
for lib in $needed; do
  found="$(find "$CADENCE_SEARCH_ROOT" -name "$lib" -type f -print 2>/dev/null | head -1 || true)"
  if [ -n "$found" ]; then
    d="$(dirname "$found")"
    case ":$libdirs:" in *":$d:"*) ;; *) libdirs="$libdirs:$d" ;; esac
    echo "$lib -> $found" >> "$LOG"
  else
    echo "$lib -> NOT FOUND" >> "$LOG"
  fi
done
# Include common roots as well.
common="$(find "$CADENCE_INSTALL_ROOT" -type d \( -path '*/tools.lnx86/lib' -o -path '*/tools.lnx86/lib/64bit' -o -path '*/tools.lnx86/spectre/lib' -o -path '*/tools.lnx86/spectre/lib/64bit' -o -path '*/tools.lnx86/dfII/lib' -o -path '*/tools.lnx86/dfII/lib/64bit' \) -print 2>/dev/null | paste -sd: || true)"
cat > "$RUN_DIR/support/spectre_runtime.env" <<EOF_ENV
export SPECTRE_CMD='$SPECTRE_RAW'
export LD_LIBRARY_PATH='${libdirs#:}:$common:\${LD_LIBRARY_PATH:-}'
export PATH='$(dirname "$SPECTRE_RAW")':\${PATH:-}
EOF_ENV

echo "Wrote $RUN_DIR/support/spectre_runtime.env" | tee -a "$LOG"
