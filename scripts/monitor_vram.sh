#!/usr/bin/env bash
# Live VRAM monitor for AMD Radeon Pro 555X on Linux/Omarchy

VRAM_USED_PATH="/sys/class/drm/card1/device/mem_info_vram_used"
VRAM_TOTAL_PATH="/sys/class/drm/card1/device/mem_info_vram_total"

if [ ! -f "$VRAM_USED_PATH" ]; then
    echo "Error: AMD GPU sysfs memory node not found at $VRAM_USED_PATH"
    exit 1
fi

echo "Monitoring AMD Radeon Pro 555X VRAM usage (Press Ctrl+C to stop)..."
watch -n 1 "awk '{printf \"VRAM Usage: %.1f MiB / %.1f MiB (%.1f%%)\n\", \$1/1048576, \$2/1048576, (\$1/\$2)*100}' <(cat $VRAM_USED_PATH $VRAM_TOTAL_PATH | paste - -)"
