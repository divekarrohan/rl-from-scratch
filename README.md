# rl-from-scratch

PPO written from scratch in PyTorch and benchmarked against [CleanRL](https://github.com/vwxyzjn/cleanrl)
on Gymnasium MuJoCo tasks. Month 1 of my learning plan; demos at https://divekarrohan.github.io.

**Status:** setup. Headline result pending (gate: Dec 20, 2026).

## Results

| Task | CleanRL PPO (5 seeds) | My PPO (5 seeds) |
| --- | --- | --- |
| Hopper-v4 | pending | pending |
| HalfCheetah-v4 | pending | pending |
| Walker2d-v4 | pending | pending |

## Environment

Python 3.11, `gymnasium==0.29.1`, `mujoco==2.3.3`: the versions CleanRL pins. CleanRL's PPO script does not run
on Gymnasium 1.x, and MuJoCo 2.3.3 has no wheels for Python 3.12+, so both implementations use this
environment and the `-v4` tasks.

PPO on these tasks is CPU-bound (small networks, one environment per run), so the baseline runs on CPU cores.
A many-core CPU pod is the cheapest place to run it.

## Run on a RunPod pod

The pod's volume (`/workspace`) is a RunPod Global volume: object storage with no file locking or atomic
rename. So code and the Python environment live on the pod's local disk (`/root`, wiped when the pod
stops), and only finished results and logs are copied to `/workspace`.

Each session, in the pod's web terminal:

```sh
cd /root && git clone https://github.com/divekarrohan/rl-from-scratch && cd rl-from-scratch
VENV_DIR=/root/venv CLEANRL_DIR=/root/cleanrl bash scripts/setup_pod.sh   # a few minutes
source /root/venv/bin/activate
export CLEANRL_DIR=/root/cleanrl
TOTAL_STEPS=20000 SEEDS=1 ENVS=Hopper-v4 NO_STOP=1 \
  bash scripts/run_and_stop.sh bash scripts/baseline_cleanrl.sh   # 1-minute smoke test
bash scripts/run_and_stop.sh bash scripts/baseline_cleanrl.sh     # full baseline, then the pod stops itself
```

Results land in `/workspace/runs/cleanrl`, logs in `/workspace/logs`.
