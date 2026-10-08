# Bonsai 8B Binary for MacBook Pro Intel 2019 (Radeon 555X, Omarchy)

Complete guide and turnkey deployment scripts for running the **Bonsai 1 (1-bit binary) 8B LLM** with a **32k context window** and **4-bit KV cache** on an **Apple MacBook Pro (Intel 2019, T2)** running **Omarchy (Arch Linux)**, forcing 100% of the display and compute workload onto the **AMD Radeon Pro 555X** while permanently disabling the Intel integrated graphics.

---

## Hardware & System Specifications

| Component | Specification |
| :--- | :--- |
| **Model** | Apple MacBook Pro 15-inch (2019, MacBookPro15,1 / T2 Chip) |
| **Processor** | Intel Core i7-9750H @ 2.60GHz (6 Cores / 12 Threads) |
| **Integrated GPU (iGPU)** | Intel UHD Graphics 630 (*Permanently disabled & purged*) |
| **Discrete GPU (dGPU)** | **AMD Radeon Pro 555X / Polaris 11 (Baffin, 4096 MiB VRAM)** |
| **OS Distribution** | **Omarchy** (Arch Linux with T2 kernel `7.2.7-arch1-Watanare-T2-2-t2`) |
| **Graphics Stack** | Mesa 26.2.2 (RADV Polaris11, Vulkan 1.4, ACO compiler) |
| **LLM Runtime** | PrismML llama.cpp fork (`prism-b10743-adfffbe`, Vulkan backend) |

---

## Part 1: Force Omarchy 100% to Radeon 555X & Permanently Delete Intel Graphics

On dual-GPU MacBook Pros running Linux, the system can default to or attempt dynamic switching with the integrated Intel UHD 630. To guarantee maximum stability, eliminate Intel driver crashes, and force all Vulkan compute and Wayland/X11 rendering to the discrete Radeon 555X, apply the following configuration.

### 1. Blacklist Intel Kernel Modules
Prevent the Linux kernel from loading the Intel `i915` and `xe` display drivers:

Create `/etc/modprobe.d/blacklist-intel.conf`:
```ini
# /etc/modprobe.d/blacklist-intel.conf
blacklist i915
blacklist xe
install i915 /bin/false
install xe /bin/false
```

### 2. Lock Apple GMUX to Discrete GPU
Ensure the hardware GMUX switch never connects the internal display to the Intel iGPU:

Create `/etc/modprobe.d/apple-gmux.conf`:
```ini
# /etc/modprobe.d/apple-gmux.conf
options apple-gmux force_igd=0
```

### 3. Add Kernel Bootloader Parameter
Pass the blacklist directly to the kernel at early boot:

* **For Limine Bootloader (Default in Omarchy):**
  Create `/etc/limine-entry-tool.d/radeon-gpu.conf`:
  ```ini
  # /etc/limine-entry-tool.d/radeon-gpu.conf
  KERNEL_CMDLINE[default]+=" module_blacklist=i915,xe"
  ```
  Then regenerate boot entries:
  ```bash
  sudo limine-entry-tool
  ```

* **For GRUB (if using GRUB):**
  Add `module_blacklist=i915,xe` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then run:
  ```bash
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  ```

### 4. Enable Early KMS for AMD in Initramfs
Ensure `amdgpu` is the only display module packed into the initial ramdisk:

In `/etc/mkinitcpio.conf`, set:
```bash
MODULES=(amdgpu)
```
Then regenerate the initramfs images:
```bash
sudo mkinitcpio -P
```

### 5. Permanently Purge Intel Graphics Drivers
Remove all Intel user-space driver packages so no application or Vulkan loader can fall back to Intel:

```bash
# Remove Intel Vulkan and Xorg video drivers
sudo pacman -Rns vulkan-intel xf86-video-intel intel-media-driver 2>/dev/null || true

# Ensure pure AMD Radeon Vulkan stack is installed
sudo pacman -S --needed vulkan-radeon mesa vulkan-icd-loader vulkan-tools
```

### 6. Force User-Space Environment to Radeon RADV
Create `/etc/environment` to direct all hardware acceleration to RADV:
```bash
# /etc/environment
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
AMD_VULKAN_ICD=RADV
VK_DRIVER_FILES=/usr/share/vulkan/icd.d/radeon_icd.json
```

### 7. Verification
Reboot your machine. Once booted, verify with:
```bash
vulkaninfo --summary
```
You should see **only one** device:
```text
Devices:
========
GPU0:
    deviceName = AMD Radeon RX Series (RADV POLARIS11)
    deviceType = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
    vendorID   = 0x1002
    driverName = radv
```

---

## Part 2: Deploying Bonsai 8B (1-Bit) with 32k Context & 4-Bit KV Cache

### Why Bonsai 8B Binary?
**Bonsai 8B** from PrismML is a 1-bit quantized model (`Q1_0`) based on Qwen 2.5 / 3. Its model weights take up only **1.1 GB** of VRAM while preserving full 8B-class output quality.

### The 4-Bit KV Cache & 32k Context Window
Standard FP16 KV caches require ~140 KiB per token on an 8B model. At 32,768 (32k) tokens, an FP16 cache would demand **~4.5 GB of VRAM**, which would exceed the Radeon 555X's 4 GB capacity.

By quantizing the KV cache to 4-bit (`--cache-type-k q4_0 --cache-type-v q4_0`):
- Memory per token drops to **32 KiB**.
- Total KV cache for 32k context is **~1.2 GB**.
- A small model-specific **mean-centering bias** (`Bonsai-8B-kv-bias.gguf`) generated via `llama-kv-mean-center` eliminates quantization error at zero runtime cost.

### VRAM Budget Breakdown on Radeon Pro 555X (4096 MiB)

| Component | VRAM Consumption |
| :--- | :--- |
| **Model Weights (`Bonsai-8B-Q1_0.gguf`)** | ~1,100 MiB (~1.1 GiB) |
| **4-Bit KV Cache (32,768 Context Window)** | ~1,300 MiB (~1.3 GiB) |
| **Mesa RADV Vulkan State & Display Buffers** | ~800 MiB (~0.8 GiB) |
| **Total VRAM Allocated** | **~3,438 MiB (~3.36 GiB)** |
| **Remaining Free VRAM Headroom** | **~658 MiB (~0.64 GiB)** |

The entire model, 32k context window, and display server fit comfortably inside the 4 GB VRAM!

---

## Quickstart Guide

### 1. Clone This Repository
```bash
git clone https://github.com/maitas44/Bonsai-8B-MacBookPro-2019-Radeon-555X-Omarchy.git
cd Bonsai-8B-MacBookPro-2019-Radeon-555X-Omarchy
```

### 2. Run Setup
The setup script downloads the PrismML Vulkan binary bundle, fetches `Bonsai-8B-Q1_0.gguf`, and calculates the calibrated KV bias:
```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 3. Launch the Server (Web UI & OpenAI API)
```bash
./scripts/start_server.sh
```
- Open your browser to chat: **`http://localhost:8080`**
- OpenAI-compatible endpoint: **`http://localhost:8080/v1/chat/completions`**

### 4. Interactive CLI Chat
To chat directly in your terminal:
```bash
./scripts/run_cli.sh
```
Or ask a single question:
```bash
./scripts/run_cli.sh -p "Explain quantum computing in one sentence."
```

### 5. Monitor VRAM Usage in Real Time
```bash
./scripts/monitor_vram.sh
```
Shows real-time VRAM allocation directly from the AMD GPU kernel driver (`card1`).

---

## Direct Launch Command (Full Paths)

If you prefer to run the command directly without scripts:

```bash
LD_LIBRARY_PATH=/path/to/bin/vulkan \
LLAMA_ATTN_ROT_DISABLE=1 \
/path/to/bin/vulkan/llama-server \
  -m /path/to/models/Bonsai-8B-Q1_0.gguf \
  --device Vulkan0 \
  -ngl 99 \
  -fa on \
  -c 32768 \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --kv-mean-center /path/to/models/Bonsai-8B-kv-bias.gguf \
  --host 127.0.0.1 \
  --port 8080 \
  --temp 0.5 --top-p 0.85 --top-k 20 --min-p 0 \
  --reasoning-budget 0 --reasoning-format none \
  --chat-template-kwargs '{"enable_thinking": false}'
```

---

## Benchmarks on This Exact Machine

Tested on an **Intel Core i7-9750H** + **AMD Radeon Pro 555X 4GB**:

| Execution Mode | Prompt Prefill (pp64) | Token Generation (tg32) | Notes |
| :--- | :--- | :--- | :--- |
| **AMD Radeon 555X (GPU)** | **35.6 t/s** | **14.0 t/s** | Smooth, offloads 100% of GPU compute |
| **CPU Only (6 Physical Threads)** | **40.7 t/s** | **8.91 t/s** | Fast prompt evaluation via AVX2/FMA |
| **CPU Only (12 Logical Threads)** | 40.9 t/s | **4.81 t/s** | ⚠️ Hyper-threading cache contention penalty |

The **Radeon Pro 555X GPU delivers ~56% faster text generation** than the optimal 6-core CPU run while keeping laptop temperatures and CPU fan noise low.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
