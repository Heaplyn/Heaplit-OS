# 🚗 Ring 1 Drivers & AI Bridge Subsystem (`rings/ring_1/ring_1/drivers/`)

This subsystem contains device drivers and the freestanding local AI inference bridge.

$$\text{Privilege Level: Ring 1 } (M \le 1) \quad | \quad \text{Dependencies: Ring 0, Ring 1}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `pci.c` — PCIe Bus Scanner
- **Purpose**: Enumerates peripheral devices attached to the PCI / PCIe bus.
- **Mechanism**: Reads configuration space via I/O Port `0xCF8` (Config Address) and `0xCFC` (Config Data) across all 256 buses, 32 devices, and 8 functions. Extracts Vendor ID, Device ID, Class, Subclass, and BAR registers.

### 2. `vfs.c` — Virtual File System (VFS) with xattr Graph Hooks
- **Purpose**: Provides unified POSIX file access abstraction (`open`, `read`, `write`, `close`, `readdir`).
- **Graph Extensions**: Exposes extended attribute (`xattr`) key-value storage (`setxattr`, `getxattr`) allowing files to maintain semantic relationship links directly on the filesystem for the Ring 2 Lens Graph Explorer.

### 3. `ai_engine.c` — Freestanding GGML Local AI Inference Bridge
- **Purpose**: Executes quantized neural network inference (GGUF format) within Ring 1.
- **Features**:
  - Zero-copy model weight memory-mapping.
  - AVX-512 accelerated matrix multiplication kernels (`__attribute__((target("avx512f")))`).
  - Token buffer management and streaming generation.
