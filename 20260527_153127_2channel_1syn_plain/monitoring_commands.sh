#!/usr/bin/env bash
set -euo pipefail
case "${1:-progress}" in
progress)
  watch -n 10 'echo -n "outputs: "; find cases -name output_signals.txt | wc -l; echo -n "failed cases: "; grep -R "^FAILED case_id=" logs/spectre_worker_*.log 2>/dev/null | wc -l; echo; for f in logs/spectre_worker_*.log; do echo "--- $f"; grep -E "runtime_missing_libs|not found|error while loading shared libraries|assigned_cases|^FAILED case_id=|^DONE" "$f" 2>/dev/null | tail -8; done'
  ;;
*) echo "Usage: $0 progress" ;;
esac
