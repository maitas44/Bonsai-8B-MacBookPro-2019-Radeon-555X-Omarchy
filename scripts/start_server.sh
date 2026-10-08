#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_DIR/bin/vulkan"
MODELS_DIR="$REPO_DIR/models"
MODEL="$MODELS_DIR/Bonsai-8B-Q1_0.gguf"
BIAS="$MODELS_DIR/Bonsai-8B-kv-bias.gguf"

if [ ! -f "$BIN_DIR/llama-server" ] || [ ! -f "$MODEL" ] || [ ! -f "$BIAS" ]; then
    echo "[!] Prerequisites missing. Running setup first..."
    "$REPO_DIR/scripts/setup.sh"
fi

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
DEVICE="${DEVICE:-Vulkan0}"
CTX="${CTX:-32768}"

export LD_LIBRARY_PATH="$BIN_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LLAMA_ATTN_ROT_DISABLE=1

echo "=========================================================="
echo " Starting Bonsai 8B Server on AMD Radeon Pro 555X        "
echo "=========================================================="
echo "  Device:      $DEVICE"
echo "  Context:     $CTX tokens"
echo "  KV Cache:    4-bit (q4_0) with mean-centering bias"
echo "  Listening:   http://$HOST:$PORT"
echo "=========================================================="

exec "$BIN_DIR/llama-server" \
  -m "$MODEL" \
  --device "$DEVICE" \
  -ngl 99 \
  -fa on \
  -c "$CTX" \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --kv-mean-center "$BIAS" \
  --host "$HOST" \
  --port "$PORT" \
  --temp 0.5 --top-p 0.85 --top-k 20 --min-p 0 \
  --reasoning-budget 0 --reasoning-format none \
  --chat-template-kwargs '{"enable_thinking": false}' \
  "$@"
