#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_DIR/bin/vulkan"
MODELS_DIR="$REPO_DIR/models"
MODEL="$MODELS_DIR/Bonsai-8B-Q1_0.gguf"
BIAS="$MODELS_DIR/Bonsai-8B-kv-bias.gguf"

if [ ! -f "$BIN_DIR/llama-cli" ] || [ ! -f "$MODEL" ] || [ ! -f "$BIAS" ]; then
    echo "[!] Prerequisites missing. Running setup first..."
    "$REPO_DIR/scripts/setup.sh"
fi

DEVICE="${DEVICE:-Vulkan0}"
CTX="${CTX:-32768}"

export LD_LIBRARY_PATH="$BIN_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LLAMA_ATTN_ROT_DISABLE=1

# Check if prompt flag was provided to add single-turn mode
ONESHOT=""
for arg in "$@"; do
    case "$arg" in
        -p|--prompt) ONESHOT="-st" ;;
    esac
done

exec "$BIN_DIR/llama-cli" \
  -m "$MODEL" \
  --device "$DEVICE" \
  -ngl 99 \
  -fa on \
  -c "$CTX" \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --kv-mean-center "$BIAS" \
  --temp 0.5 --top-p 0.85 --top-k 20 --min-p 0 \
  --reasoning-budget 0 --reasoning-format none \
  --chat-template-kwargs '{"enable_thinking": false}' \
  $ONESHOT \
  "$@"
