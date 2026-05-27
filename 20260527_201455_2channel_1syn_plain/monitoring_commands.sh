#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-progress}"
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source ./RUNINFO.txt

case "$MODE" in
  progress)
    watch -n 10 'echo -n "outputs: "; find cases -name output_signals.txt 2>/dev/null | wc -l; echo -n "failed cases: "; cat worker_state/job_*_failed.txt 2>/dev/null | wc -l; echo; for f in logs/spectre_worker_*.log; do [ -f "$f" ] || continue; echo "--- $f"; tail -25 "$f"; done'
    ;;
  once)
    echo -n "outputs: "; find cases -name output_signals.txt 2>/dev/null | wc -l
    echo -n "failed cases: "; cat worker_state/job_*_failed.txt 2>/dev/null | wc -l
    echo -n "DONE cases: "; cat worker_state/job_*_done.txt 2>/dev/null | wc -l
    ;;
  errors)
    grep -RniE 'FAILED|ERROR|FATAL|SPECTRE-|Cannot|not found|export_rc|spectre_rc' logs cases/*/*.log cases/*/spectre.out 2>/dev/null | tail -200 || true
    ;;
  *)
    echo "Usage: ./monitoring_commands.sh [progress|once|errors]" >&2
    exit 2
    ;;
esac
