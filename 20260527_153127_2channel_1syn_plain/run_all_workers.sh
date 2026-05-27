#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
for j in $(seq 0 $((NUM_JOBS-1))); do
  "$RUN_DIR/run_spectre_worker.sh" "$j" > "$RUN_DIR/logs/worker_${j}.launcher.log" 2>&1 &
done
wait
