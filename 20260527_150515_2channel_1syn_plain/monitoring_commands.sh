#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RUN_DIR/RUNINFO.txt"
cmd="${1:-summary}"
case "$cmd" in
  progress)
    watch -n 10 'echo -n "outputs: "; find cases -name output_signals.txt | wc -l; echo -n "failed cases: "; grep -R "^FAILED case_id=" logs/spectre_worker_*.log 2>/dev/null | wc -l; echo; for f in logs/spectre_worker_*.log; do [ -f "$f" ] || continue; echo "--- $f"; grep -E "^assigned_cases=|^========== case_id=|^DONE |^FAILED case_id=|error while loading shared libraries|ERROR|FATAL|SFE-|SPECTRE-" "$f" | tail -10; done'
    ;;
  summary)
    echo "RUN_DIR=$RUN_DIR"
    echo -n "total cases: "; tail -n +2 cases.csv | wc -l
    echo -n "outputs: "; find cases -name output_signals.txt | wc -l
    echo -n "failed cases: "; grep -R "^FAILED case_id=" logs/spectre_worker_*.log 2>/dev/null | wc -l || true
    echo "worker assignment:"
    grep -H "^assigned_cases=" logs/spectre_worker_*.log 2>/dev/null || true
    ;;
  errors)
    grep -RniE "FAILED case_id|ERROR|FATAL|SFE-|SPECTRE-|Cannot open|Cannot find|error while loading shared libraries" logs cases 2>/dev/null | tail -200 || true
    ;;
  *)
    echo "Usage: $0 {summary|progress|errors}" >&2
    exit 2
    ;;
esac
