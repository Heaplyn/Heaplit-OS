# ⚙️ Ring 0: Pure Metal Utilities & Microkernel Core

Ring 0 contains the lowest-level, hardware-closest components of Heaplit OS. It is strictly independent ($M = 0$) and **MUST NOT** require or depend on any modules from Ring 1, Ring 2, or Ring 3.

---

## 📂 Subfolder Breakdown

### 1. `rings/ring_0/ring_0/types/` — Dynamic Variable & Type Utilities
- **`variable.asm`**: Implements the 6-byte dynamic typed variable system (`type` [1 byte], `flags` [1 byte], `payload` [4 bytes]). Supports integer and string types, dynamic memory allocation/rebasing, typed addition/subtraction, and formatting.
- **`math.asm`**: 16-bit and 32-bit arithmetic helpers, integer-to-ASCII string conversion (`int_to_string`), absolute value (`abs16`), and min/max routines.
- **`string.asm`**: Real-mode string manipulation routines (`strlen16`, `strcmp16`, `strcpy16`, `strcat16`).

### 2. `rings/ring_0/ring_0/memory/` — Memory Block Operations & Physical Allocator
- **`memory.asm`**: Optimized 16-bit word-aligned block memory utilities (`mem_set`, `mem_copy`, `mem_zero`).
- **`pmm.asm`**: 64-bit Physical Memory Manager (PMM). Implements a 4KB-page bitmap tracking up to 32GB of physical RAM, with allocation (`pmm_alloc_page`), deallocation (`pmm_free_page`), and BIOS E820 memory map parsing.

### 3. `rings/ring_0/ring_0/cpu/` — Processor Descriptors & Mode Transitions
- **`gdt.asm`**: Flat Global Descriptor Table defining 16-bit, 32-bit, and 64-bit code and data segments for Ring 0 and Ring 3, plus TSS descriptors.
- **`idt.asm`**: 64-bit Interrupt Descriptor Table with 256 ISR gates, mapping CPU exceptions (0-31) and hardware IRQs (32-255).
- **`paging.asm`**: 4-level paging setup (PML4, PDPT, Page Directory) configured at fixed offsets (`0x1000`, `0x2000`, `0x3000`) using 2MB huge pages to map the first 1GB of physical RAM.
- **`protected_mode.asm`**: Enters 32-bit Protected Mode (`CR0.PE = 1`), loads the GDT, flushes pipeline, and validates Long Mode CPUID support.
- **`long_mode.asm`**: Activates 64-bit Long Mode (`CR4.PAE = 1`, `EFER.LME = 1`, `CR0.PG = 1`), jumps into 64-bit kernel code, and provides the `drop_to_ring3` trampoline using `iretq`.

### 4. `rings/ring_0/ring_0/sched/` — Tickless Scheduler
- **`scheduler.asm`**: High-performance, tickless event-driven thread scheduler with a thread control block (`thread_t`) and sub-100-cycle context switch routine (`switch_threads`).

### 5. `rings/ring_0/ring_0/syscalls/` — Fast Syscall Dispatcher & AI Vector Engine
- **`syscall.asm`**: Initializes `MSR_LSTAR` (`0xC0000082`), `MSR_STAR`, and `MSR_SFMASK` for fast `syscall`/`sysretq` instructions and routes system calls (0x000 to 0x6FF).
- **`syscall_ai.asm`**: Fast entrypoints for dedicated AI syscalls (`SYS_AI_LOAD_MODEL` `0x600`, `SYS_AI_INFER` `0x601`, `SYS_AI_UNLOAD` `0x602`) and 512-bit XSAVE/XRSTOR vector context preservation.
