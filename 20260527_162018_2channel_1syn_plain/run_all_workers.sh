#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
source "$RUN_DIR/setup_spectre_env.sh"
missing=$(check_spectre_runtime || true)
if [ -n "$missing" ]; then
  echo "ERROR: Spectre runtime libraries are still missing:" >&2
  echo "$missing" >&2
  echo "Run: ./refresh_spectre_runtime.sh" >&2
  exit 1
fi
for j in $(seq 0 $((NUM_JOBS-1))); do
  bash "$RUN_DIR/run_spectre_worker.sh" "$j" > "$RUN_DIR/logs/worker_${j}.launcher.log" 2>&1 &
done
wait
