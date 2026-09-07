# 🧠 Ring 0 Memory Subsystem (`rings/ring_0/ring_0/memory/`)

The Memory subsystem provides real-mode word-aligned block memory operations and the 64-bit Physical Memory Manager (PMM) page allocator.

$$\text{Privilege Level: Ring 0 } (M = 0) \quad | \quad \text{Dependencies: None (Strictly Independent)}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `memory.asm` — Fast Word Block Memory Operations
- **Purpose**: High-speed real-mode memory initialization, block transfer, and clearing.
- **Procedures**:
  - `mem_set(DI=dest, AL=value, CX=count)`: Fills buffer with byte value. Optimizes by pairing bytes into words for `rep stosw` when `CX >= 2`.
  - `mem_copy(DI=dest, SI=src, CX=count)`: Copies memory region. Uses `rep movsw` for even word transfers.
  - `mem_zero(DI=dest, CX=count)`: Sets buffer to zero.

### 2. `pmm.asm` — 64-bit Physical Memory Manager
- **Purpose**: Manages 4KB physical page frames across physical RAM using a dense bitmap.
- **Key Characteristics**:
  - **Page Size**: 4096 bytes (4KB).
  - **Capacity**: 1 bit per page frame. A 1MB bitmap tracks 8,388,608 pages (32GB of RAM).
  - **Bitmap Placement**: Placed at physical address `0x00100000` (1MB mark) above BIOS reserved area.
- **Procedures**:
  - `pmm_init(RDI=e820_map_ptr, RCX=entry_count)`: Parses BIOS E820 memory map, identifies free RAM regions (Type 1), and initializes the bitmap.
  - `pmm_alloc_page() -> RAX`: Scans bitmap for first free bit (0), sets it to allocated (1), and returns physical base address (`page_index * 4096`).
  - `pmm_free_page(RDI=phys_addr)`: Calculates bit index (`phys_addr / 4096`) and clears bit to 0.
