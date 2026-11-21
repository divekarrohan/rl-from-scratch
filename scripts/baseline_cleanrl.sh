#!/usr/bin/env bash
# CleanRL PPO baseline: 3 tasks x 5 seeds, run in parallel on all CPU cores.
# Env vars: TOTAL_STEPS (default 1000000), ENVS, SEEDS, JOBS (default: cores the container may use).
set -euo pipefail
WS="${WORKSPACE:-/workspace}"
CLEANRL_DIR="${CLEANRL_DIR:-/root/cleanrl}"
TOTAL_STEPS="${TOTAL_STEPS:-1000000}"
ENVS="${ENVS:-Hopper-v4 HalfCheetah-v4 Walker2d-v4}"
SEEDS="${SEEDS:-1 2 3 4 5}"
if [ -z "${VIRTUAL_ENV:-}" ] && [ -f /root/venv/bin/activate ]; then source /root/venv/bin/activate; fi
if [ ! -f "$CLEANRL_DIR/cleanrl/ppo_continuous_action.py" ] || ! python -c "import gymnasium, mujoco, torch" 2>/dev/null; then
  echo "Not set up: CleanRL or the Python packages are missing. Run: bash scripts/setup_pod.sh"; exit 1
fi
# nproc shows the host's cores; the container's real share is its cgroup quota.
cores() { { read -r q p < /sys/fs/cgroup/cpu.max; } 2>/dev/null && [ "$q" != max ] && echo $(( q / p )) || nproc; }
JOBS="${JOBS:-$(cores)}"
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1   # one thread per run; parallelism comes from running many runs
echo "running $(echo $ENVS | wc -w) env(s) x $(echo $SEEDS | wc -w) seed(s), $JOBS at a time, $TOTAL_STEPS steps each"
LOCAL="${LOCAL_ROOT:-/root}/runs/cleanrl"   # write locally: the volume is object storage
mkdir -p "$LOCAL"
cd "$LOCAL"   # CleanRL writes runs/<name> relative to the working directory

for env in $ENVS; do for seed in $SEEDS; do echo "$env $seed"; done; done |
  xargs -P "$JOBS" -L 1 bash -c \
    'echo "start $0 seed $1"; python "'"$CLEANRL_DIR"'/cleanrl/ppo_continuous_action.py" --env-id "$0" --seed "$1" \
       --total-timesteps '"$TOTAL_STEPS"' --no-cuda > "logs_$0_$1.txt" 2>&1 && echo "done $0 seed $1" || { echo "FAILED $0 seed $1, last lines of logs_$0_$1.txt:"; tail -5 "logs_$0_$1.txt"; exit 1; }' \
  && STATUS=0 || STATUS=1   # keep going: copy whatever finished even if a run failed
mkdir -p "$WS/runs/cleanrl"
cp -r "$LOCAL/." "$WS/runs/cleanrl/"
echo "results copied to $WS/runs/cleanrl (TensorBoard: tensorboard --logdir $WS/runs/cleanrl/runs)"
exit "$STATUS"
