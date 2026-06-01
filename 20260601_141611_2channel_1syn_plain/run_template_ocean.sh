#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$RUN_DIR/RUNINFO.txt"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/cadence_template_project"
if ! command -v ocean >/dev/null 2>&1; then
  echo "ocean not found in this shell. Use ciw_template_command.il in CIW instead." >&2
  exit 127
fi
CAD_REPO_DIR="$REPO_DIR" \
CAD_EXP_DIR="$EXP_DIR" \
CAD_SPIKE_DIR="$SPIKE_DIR" \
CAD_TEMPLATE_DIR="$RUN_DIR/manual_template_ocean_result" \
CAD_PROJECT_DIR="$RUN_DIR/cadence_template_project" \
CAD_BATCH_EXIT=1 \
ocean -nograph -restore "$RUN_DIR/ocn/make_spectre_template_reorg_v2.ocn" > "$RUN_DIR/logs/template_ocean.log" 2>&1
