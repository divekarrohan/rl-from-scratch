#!/usr/bin/env bash
# One-time setup on a RunPod pod. Everything lives on the attached volume (default /workspace),
# so later sessions only need: source /workspace/venvs/rl/bin/activate
set -euo pipefail
WS="${WORKSPACE:-/workspace}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

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

echo "[2/4] Creating a Python 3.11 environment at $WS/venvs/rl..."
[ -d "$WS/venvs/rl" ] || uv venv -p 3.11 "$WS/venvs/rl"
# shellcheck disable=SC1091
source "$WS/venvs/rl/bin/activate"

echo "[3/4] Installing packages (PyTorch is large; this can take a few minutes)..."
uv pip install -r "$REPO_DIR/requirements.txt"

echo "[4/4] Fetching CleanRL..."
[ -d "$WS/cleanrl" ] || git clone --depth 1 https://github.com/vwxyzjn/cleanrl "$WS/cleanrl"

python -c "import gymnasium, mujoco, torch; print('Setup OK:', 'gymnasium', gymnasium.__version__, '| mujoco', mujoco.__version__, '| torch', torch.__version__)"
echo "Next session, start with: source $WS/venvs/rl/bin/activate"
