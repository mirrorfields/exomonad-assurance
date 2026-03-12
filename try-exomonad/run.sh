#!/usr/bin/env bash
# run.sh: One-command entry point for ExoMonad on any GitHub repo.
#
# Usage:
#   ./try-exomonad/run.sh <github-repo-url>
#
# Auth is provided by mounting credential files from the host (read-only).
# No API keys needed — uses your existing subscription/credentials.
#
# Environment (optional):
#   GITHUB_TOKEN  — enables gh CLI + PR workflows
set -euo pipefail

REPO_URL="${1:?Usage: ./try-exomonad/run.sh <github-repo-url>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# ---- Build volume mount args ----
# Full directory mounts (rw) — Claude Code writes settings, session history,
# and projects metadata into ~/.claude/. The binary is at ~/.local/bin/claude
# (outside ~/.claude/) so the mount doesn't clobber it.
mkdir -p "$HOME/.claude" "$HOME/.gemini"

MOUNTS=(
    -v "$HOME/.claude:/home/exo/.claude"
    -v "$HOME/.gemini:/home/exo/.gemini"
)

# Claude state file (auth tokens, onboarding flags, trust dialog state).
# Must be rw — claude writes to this after trust dialog acceptance and hangs if read-only.
if [ -f "$HOME/.claude.json" ]; then
    MOUNTS+=(-v "$HOME/.claude.json:/home/exo/.claude.json")
fi

# ---- Stage WASM artifacts ----
echo "Staging WASM artifacts..."
mkdir -p try-exomonad/artifacts

WASM_SRC=".exo/wasm/wasm-guest-devswarm.wasm"

if [ ! -f "$WASM_SRC" ]; then
    echo "ERROR: Missing artifact: $WASM_SRC" >&2
    echo "Run 'just install-all-dev' first to build all artifacts." >&2
    exit 1
fi

cp "$WASM_SRC" try-exomonad/artifacts/wasm-guest-devswarm.wasm

# ---- Build Docker image ----
echo "Building Docker image (cached after first run)..."
docker build -t exomonad-try -f try-exomonad/Dockerfile .

# ---- Launch container ----
echo "Launching container with $REPO_URL ..."
docker run -it --rm \
    "${MOUNTS[@]}" \
    -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    exomonad-try \
    bash -c "
        git clone '$REPO_URL' /workspace/project && \
        exomonad-bootstrap /workspace/project
    "
