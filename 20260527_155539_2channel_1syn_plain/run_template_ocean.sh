#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
CAD_TEMPLATE_RUN_DIR="$RUN_DIR/template_ocean_run" CAD_BATCH_EXIT=1 ocean -nograph -restore "$RUN_DIR/ocn/make_spectre_template_v1.ocn" > "$RUN_DIR/logs/template_ocean.log" 2>&1
