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
# nproc and free show the host; the pod's real share is its cgroup limits.
CG="${CGROUP_DIR:-/sys/fs/cgroup}"
cpu_milli() { local q p; { read -r q p < "$CG/cpu.max"; } 2>/dev/null || { echo $(( $(nproc) * 1000 )); return; }
  [ "$q" = max ] && echo $(( $(nproc) * 1000 )) || echo $(( q * 1000 / p )); }
mem_mb() { local m; m=$(cat "$CG/memory.max" 2>/dev/null || echo max)
  if [ "$m" = max ]; then awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo; else echo $(( m / 1048576 )); fi; }
CPU_M=$(cpu_milli); MEM=$(mem_mb)
BY_CPU=$(( CPU_M / 1000 )); BY_MEM=$(( MEM / 800 ))   # one run peaks at ~0.7 GB of RAM and uses one core
AUTO=$(( BY_CPU < BY_MEM ? BY_CPU : BY_MEM ))
echo "pod resources: $(( CPU_M / 1000 )).$(( CPU_M % 1000 / 100 )) cores, $MEM MB RAM"
if [ -z "${JOBS:-}" ] && [ "$AUTO" -lt 1 ]; then
  echo "This pod is too small: each run needs one full core and about 0.8 GB of RAM."
  echo "Stop it and pick a CPU pod with at least 4 vCPUs and 8 GB (more cores = faster), or set JOBS=1 to run anyway."
  exit 1
fi
JOBS="${JOBS:-$AUTO}"
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
