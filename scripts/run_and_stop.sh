#!/usr/bin/env bash
# Run a command, log it to the volume, then stop the pod so idle time costs nothing.
# Usage: scripts/run_and_stop.sh <command> [args...]     (set NO_STOP=1 to keep the pod running)
set -uo pipefail
WS="${WORKSPACE:-/workspace}"
LOCAL_LOGS="${LOCAL_ROOT:-/root}/logs"    # log locally, copy to the volume at the end
mkdir -p "$LOCAL_LOGS" "$WS/logs"
LOG="$LOCAL_LOGS/$(date +%Y%m%d-%H%M%S).log"
echo "logging to $LOG"
"$@" 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
echo "exit status $STATUS" | tee -a "$LOG"
cp "$LOG" "$WS/logs/" && echo "log copied to $WS/logs/$(basename "$LOG")"
if [ -z "${NO_STOP:-}" ] && [ -n "${RUNPOD_POD_ID:-}" ]; then
  # newer runpodctl uses "pod stop", older "stop pod"; try both
  runpodctl pod stop "$RUNPOD_POD_ID" 2>/dev/null || runpodctl stop pod "$RUNPOD_POD_ID"
fi
exit "$STATUS"
