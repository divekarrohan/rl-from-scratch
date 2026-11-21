#!/usr/bin/env bash
# One-time setup on a RunPod pod. Everything lives on the network volume (/workspace),
# so later sessions only need: source /workspace/venvs/rl/bin/activate
set -euo pipefail
WS="${WORKSPACE:-/workspace}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

command -v uv >/dev/null || pip install -q uv
[ -d "$WS/venvs/rl" ] || uv venv -p 3.11 "$WS/venvs/rl"
# shellcheck disable=SC1091
source "$WS/venvs/rl/bin/activate"
uv pip install -r "$REPO_DIR/requirements.txt"

[ -d "$WS/cleanrl" ] || git clone --depth 1 https://github.com/vwxyzjn/cleanrl "$WS/cleanrl"
python -c "import gymnasium, mujoco, torch; print('ok', gymnasium.__version__, mujoco.__version__, torch.__version__)"
