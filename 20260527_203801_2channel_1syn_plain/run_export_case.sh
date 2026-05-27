#!/usr/bin/env bash
set -euo pipefail
case_dir="${1:?usage: run_export_case.sh CASE_DIR}"
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
ocn="$RUN_DIR/ocn/export_psf_to_txt.ocn"
log="$case_dir/export_ocean.log"
mkdir -p "$case_dir"
export CASE_DIR="$case_dir"
if command -v ocean >/dev/null 2>&1; then
  ocean -nograph -restore "$ocn" > "$log" 2>&1
else
  virtuoso_bin="/projects/bics/cadence/installs/IC231/tools.lnx86/dfII/bin/64bit/virtuoso"
  if [ -x "$virtuoso_bin" ]; then
    "$virtuoso_bin" -ocean -nograph -restore "$ocn" > "$log" 2>&1
  else
    echo "ERROR: neither ocean nor $virtuoso_bin is available." > "$log"
    exit 127
  fi
fi
