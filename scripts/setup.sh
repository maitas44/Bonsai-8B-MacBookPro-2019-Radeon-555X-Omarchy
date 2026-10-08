#!/usr/bin/env bash
set -euo pipefail

# Setup script for Bonsai 8B on AMD Radeon Pro 555X (Omarchy / Arch Linux)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$REPO_DIR/bin/vulkan"
MODELS_DIR="$REPO_DIR/models"
RELEASE_TAG="prism-b10743-adfffbe"
VULKAN_ASSET_URL="https://github.com/PrismML-Eng/llama.cpp/releases/download/${RELEASE_TAG}/llama-${RELEASE_TAG}-bin-ubuntu-vulkan-x64.tar.gz"

echo "=========================================================="
echo " Setting up Bonsai 8B for MacBook Pro 2019 (Radeon 555X)  "
echo "=========================================================="

mkdir -p "$BIN_DIR" "$MODELS_DIR"

# 1. Download PrismML llama.cpp prebuilt Vulkan binaries
if [ ! -f "$BIN_DIR/llama-server" ]; then
    echo "[*] Downloading PrismML Vulkan binaries (${RELEASE_TAG})..."
    TMP_ARCHIVE=$(mktemp)
    curl -L --progress-bar "$VULKAN_ASSET_URL" -o "$TMP_ARCHIVE"
    tar -xzf "$TMP_ARCHIVE" -C "$BIN_DIR" --strip-components=1 2>/dev/null || tar -xzf "$TMP_ARCHIVE" -C "$BIN_DIR"
    rm -f "$TMP_ARCHIVE"
    echo "[✓] Binaries installed to $BIN_DIR"
else
    echo "[✓] Vulkan binaries already present in $BIN_DIR"
fi

# 2. Setup python environment for HuggingFace model download
if [ ! -f "$MODELS_DIR/Bonsai-8B-Q1_0.gguf" ]; then
    echo "[*] Setting up Python environment to download model weights..."
    if command -v uv >/dev/null 2>&1; then
        uv venv "$REPO_DIR/.venv" --quiet
        uv pip install --python "$REPO_DIR/.venv" huggingface-hub --quiet
        PY="$REPO_DIR/.venv/bin/python"
    else
        python3 -m venv "$REPO_DIR/.venv"
        "$REPO_DIR/.venv/bin/pip" install huggingface-hub --quiet
        PY="$REPO_DIR/.venv/bin/python"
    fi

    echo "[*] Downloading Bonsai-8B-Q1_0.gguf from HuggingFace (prism-ml/Bonsai-8B-gguf)..."
    "$PY" -c "
from huggingface_hub import hf_hub_download
import shutil, os

path = hf_hub_download(
    repo_id='prism-ml/Bonsai-8B-gguf',
    filename='Bonsai-8B-Q1_0.gguf'
)
shutil.copy(path, '$MODELS_DIR/Bonsai-8B-Q1_0.gguf')
"
    echo "[✓] Model downloaded to $MODELS_DIR/Bonsai-8B-Q1_0.gguf"
else
    echo "[✓] Model weights already present in $MODELS_DIR/Bonsai-8B-Q1_0.gguf"
fi

# 3. Generate 4-bit KV Cache mean-centering calibration bias
BIAS_FILE="$MODELS_DIR/Bonsai-8B-kv-bias.gguf"
if [ ! -f "$BIAS_FILE" ]; then
    echo "[*] Generating 4-bit KV cache calibration bias (${BIAS_FILE})..."
    CALIB_CORPUS=$(mktemp)
    cat > "$CALIB_CORPUS" << 'EOF'
The quick brown fox jumps over the lazy dog while the seasons change from a
mild spring into a hot, humid summer. Rivers carve valleys over thousands of
years, and glaciers grind mountains into gravel that settles on the sea floor.

def fibonacci(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a

SELECT region, SUM(quantity * unit_price) AS revenue
FROM orders JOIN order_items ON orders.id = order_items.order_id
GROUP BY region ORDER BY revenue DESC;
EOF
    export LD_LIBRARY_PATH="$BIN_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    "$BIN_DIR/llama-kv-mean-center" \
        -m "$MODELS_DIR/Bonsai-8B-Q1_0.gguf" \
        -f "$CALIB_CORPUS" \
        -o "$BIAS_FILE" \
        -ngl 99 \
        -c 512
    rm -f "$CALIB_CORPUS"
    echo "[✓] KV cache calibration bias generated successfully."
else
    echo "[✓] KV cache calibration bias already exists: $BIAS_FILE"
fi

echo ""
echo "=========================================================="
echo " Setup complete! You can now start the server with:      "
echo "   ./scripts/start_server.sh                              "
echo "=========================================================="
