#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$RUN_DIR"
source "$RUN_DIR/RUNINFO.txt"
for j in $(seq 0 $((NUM_JOBS - 1))); do
  ./run_spectre_worker.sh "$j" &
done
wait
