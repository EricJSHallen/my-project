#!/usr/bin/env bash
set -euo pipefail
case "${1:-progress}" in
  progress)
    watch -n 10 'echo -n "outputs: "; find cases -name output_signals.txt 2>/dev/null | wc -l; echo -n "done cases: "; grep -R "^DONE case_id=" logs/spectre_worker_*.log 2>/dev/null | wc -l; echo -n "failed cases: "; grep -R "^FAILED case_id=" logs/spectre_worker_*.log 2>/dev/null | wc -l; echo; for f in logs/spectre_worker_*.log; do [ -f "$f" ] || continue; echo "--- $f"; grep -E "SPECTRE_CMD=|DONE case_id=|FAILED case_id=|ERROR|SFE-|spectre completes|output_signals|export_rc" "$f" | tail -20; done'
    ;;
  count)
    find cases -name output_signals.txt 2>/dev/null | wc -l
    ;;
  *)
    echo "Usage: $0 {progress|count}" >&2
    exit 2
    ;;
esac
