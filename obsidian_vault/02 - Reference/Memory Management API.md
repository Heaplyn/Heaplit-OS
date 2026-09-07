> **Status:** #status/implemented

# 💾 Memory Management API Reference

> **Source File:** [`rings/ring_0/ring_1/memory.asm`](file:///C:/Users/Kyle/Downloads/Projects/Heaplit%20OS/rings/ring_0/ring_1/memory.asm)  
> **Mode:** 16-bit Real Mode / Segmented Addressing (`ES:DI`)

---

## 1. Real-Mode Memory Functions

### `mem_set`
Fills a destination memory block with a specified byte value using hardware-accelerated 16-bit word operations (`rep stosw`).

- **Inputs:**
  - `ES:DI`: Pointer to destination memory buffer
  - `AL`: Byte value to fill
  - `CX`: Number of bytes to fill
- **Outputs:**
  - `ES:DI`: Restored to original buffer start pointer
- **Internal Optimization:**
  - Duplicates byte in `AL` across `AH` (`AX = (AL << 8) | AL`)
  - Halves count (`CX = CX / 2`) and executes fast word-sized `rep stosw`
  - Handles odd trailing byte via `.handle_odd` (`stosb`)

---

### `mem_copy`
Copies a block of memory from a source buffer to a destination buffer.

- **Inputs:**
  - `DS:SI`: Source buffer pointer
  - `ES:DI`: Destination buffer pointer
  - `CX`: Byte count to copy

---

### `mem_zero`
Zero-initializes a memory block by invoking `mem_set` with `AL = 0`.

- **Inputs:**
  - `ES:DI`: Pointer to memory buffer
  - `CX`: Byte count to zero out

---

## 2. Real-Mode Memory Map (First 1MB)

| Address Range | Size | Description |
| :--- | :--- | :--- |
| `0x00000 - 0x003FF` | 1 KB | Real Mode Interrupt Vector Table (IVT) |
| `0x00400 - 0x004FF` | 256 B | BIOS Data Area (BDA) |
| `0x00500 - 0x07BFF` | ~30 KB | Free Conventional Memory (Scratch / Stack) |
| `0x07C00 - 0x07DFF` | 512 B | **Sector 1: MBR Bootloader** |
| `0x07E00 - 0x07FFF` | 512 B | **Sector 2: Extended Bootloader** |
| `0x08000 - 0x081FF` | 512 B | **Sector 3: Kernel Setup / Drivers** |
| `0x08200 - 0x08FFF` | ~3.5 KB | Free Heap / Driver Buffers |
| `0x09000` | - | **Top of Stack (`SP = 0x9000`, grows downward)** |
| `0xA0000 - 0xBFFFF` | 128 KB | Video Memory (`0xB8000` = Color Text Mode Framebuffer) |
| `0xC0000 - 0xFFFFF` | 256 KB | BIOS ROM & Memory Mapped Hardware |

---

## 3. Related Notes
- [[02 - Reference/Variable System API|Variable System API]]
- [[01 - Planning/HeaplitPlan - Variable System & Memory|Memory Planning]]
- [[00 - Architecture/Ring 0 - Metal & Scheduler|Ring 0 Architecture]]

## 🔄 Physical & Virtual Memory Service Pipeline

```mermaid
flowchart TD
    A["`kalloc(bytes)` Call"] --> B["Calculate Page Count: `ceil(bytes / 4096)`"]
    B --> C["Invoke `pmm_alloc_page()` for Physical Frames"]
    C --> D["Walk 4-Level Page Table (PML4 -> PDPT -> PD -> PT)"]
    D --> E["Map Virtual Pages to Physical Frames with R/W Flags"]
    E --> F["Invalidate TLB via `invlpg` Instruction"]
    F --> G["Return Allocated Virtual Base Address"]
```
