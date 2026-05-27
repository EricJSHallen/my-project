#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
case "${1:-progress}" in
  progress)
    watch -n 10 'echo -n "outputs: "; find cases -name output_signals.txt | wc -l; echo -n "failed cases: "; grep -R "^FAILED case_id=" logs/spectre_worker_*.log 2>/dev/null | wc -l; echo; for f in logs/spectre_worker_*.log; do [ -f "$f" ] || continue; echo "--- $f"; grep -E "assigned_cases|DONE |FAILED case_id=|runtime_missing_libs|not found|error while loading shared libraries" "$f" | tail -20; done'
    ;;
  count)
    find cases -name output_signals.txt | wc -l
    ;;
  *)
    echo "Usage: $0 {progress|count}" >&2; exit 2;;
esac
