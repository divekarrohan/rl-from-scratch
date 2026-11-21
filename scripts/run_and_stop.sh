#!/usr/bin/env bash
# Run a command, log it to the volume, then stop the pod so idle time costs nothing.
# Usage: scripts/run_and_stop.sh <command> [args...]     (set NO_STOP=1 to keep the pod running)
set -uo pipefail
WS="${WORKSPACE:-/workspace}"
mkdir -p "$WS/logs"
LOG="$WS/logs/$(date +%Y%m%d-%H%M%S).log"
echo "logging to $LOG"
"$@" 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
echo "exit status $STATUS" | tee -a "$LOG"
if [ -z "${NO_STOP:-}" ] && [ -n "${RUNPOD_POD_ID:-}" ]; then
  runpodctl pod stop "$RUNPOD_POD_ID" || runpodctl stop pod "$RUNPOD_POD_ID"
fi
exit "$STATUS"
