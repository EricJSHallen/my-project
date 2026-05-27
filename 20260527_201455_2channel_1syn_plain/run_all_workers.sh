#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./RUNINFO.txt

mkdir -p logs worker_state
for j in $(seq 0 $((NUM_JOBS - 1))); do
  ./run_spectre_worker.sh "$j" &
  echo $! > "worker_state/job_${j}.pid"
done
wait
