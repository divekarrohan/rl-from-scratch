#!/usr/bin/env bash
# CleanRL PPO baseline: 3 tasks x 5 seeds, run in parallel on all CPU cores.
# Env vars: TOTAL_STEPS (default 1000000), ENVS, SEEDS, JOBS (default: number of cores).
set -euo pipefail
WS="${WORKSPACE:-/workspace}"
CLEANRL_DIR="${CLEANRL_DIR:-$WS/cleanrl}"
TOTAL_STEPS="${TOTAL_STEPS:-1000000}"
ENVS="${ENVS:-Hopper-v4 HalfCheetah-v4 Walker2d-v4}"
SEEDS="${SEEDS:-1 2 3 4 5}"
JOBS="${JOBS:-$(nproc)}"
LOCAL="${LOCAL_ROOT:-/root}/runs/cleanrl"   # write locally: the volume is object storage
mkdir -p "$LOCAL"
cd "$LOCAL"   # CleanRL writes runs/<name> relative to the working directory

for env in $ENVS; do for seed in $SEEDS; do echo "$env $seed"; done; done |
  xargs -P "$JOBS" -L 1 bash -c \
    'python "'"$CLEANRL_DIR"'/cleanrl/ppo_continuous_action.py" --env-id "$0" --seed "$1" \
       --total-timesteps '"$TOTAL_STEPS"' --no-cuda > "logs_$0_$1.txt" 2>&1 && echo "done $0 seed $1"'
mkdir -p "$WS/runs/cleanrl"
cp -r "$LOCAL/." "$WS/runs/cleanrl/"
echo "results copied to $WS/runs/cleanrl (TensorBoard: tensorboard --logdir $WS/runs/cleanrl/runs)"
