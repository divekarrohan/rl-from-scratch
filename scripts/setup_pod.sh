#!/usr/bin/env bash
# Setup on a RunPod pod, rerun each time the pod starts. The volume (/workspace) is object storage
# (no chmod, no locking), so the environment, CleanRL and caches go on local disk (/root), which is
# wiped when the pod stops. Only results and logs are kept on /workspace.
set -euo pipefail
WS="${WORKSPACE:-/workspace}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="${VENV_DIR:-/root/venv}"
CLEANRL_DIR="${CLEANRL_DIR:-/root/cleanrl}"
# Set unconditionally: RunPod templates point UV_CACHE_DIR at /workspace, where uv can't set permissions.
export UV_CACHE_DIR=/root/.cache/uv PIP_CACHE_DIR=/root/.cache/pip

if [ -z "${RUNPOD_POD_ID:-}" ] && [ -z "${ALLOW_LOCAL:-}" ]; then
  echo "This looks like your own computer, not a RunPod pod (RUNPOD_POD_ID is not set)."
  echo "Run this script inside a pod. To set up locally anyway (downloads several GB):"
  echo "  ALLOW_LOCAL=1 WORKSPACE=\$HOME/rl-workspace bash scripts/setup_pod.sh"
  exit 1
fi
if [ ! -d "$WS" ] || [ ! -w "$WS" ]; then
  echo "Volume folder $WS is missing or not writable. Check where your volume is mounted,"
  echo "then rerun with: WORKSPACE=<mount path> bash scripts/setup_pod.sh"
  exit 1
fi

echo "[1/4] Installing uv (Python package manager)..."
command -v uv >/dev/null || pip install uv

echo "[2/4] Creating a Python 3.11 environment at $VENV_DIR..."
[ -d "$VENV_DIR" ] || uv venv -p 3.11 "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "[3/4] Installing packages (PyTorch is large; this can take a few minutes)..."
uv pip install -r "$REPO_DIR/requirements.txt"

echo "[4/4] Fetching CleanRL..."
[ -d "$CLEANRL_DIR" ] || git clone --depth 1 https://github.com/vwxyzjn/cleanrl "$CLEANRL_DIR"

python -c "import gymnasium, mujoco, torch; print('Setup OK:', 'gymnasium', gymnasium.__version__, '| mujoco', mujoco.__version__, '| torch', torch.__version__)"
echo "Activate with: source $VENV_DIR/bin/activate"
