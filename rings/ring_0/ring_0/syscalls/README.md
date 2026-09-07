# 📡 Ring 0 Syscalls Subsystem (`rings/ring_0/ring_0/syscalls/`)

The Syscalls subsystem provides hardware fast syscall dispatching (`syscall`/`sysretq` instructions via MSR registers) and dedicated local AI syscall hooks with 512-bit AVX-512 vector context management.

$$\text{Privilege Level: Ring 0 } (M = 0) \quad | \quad \text{Dependencies: None (Strictly Independent)}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `syscall.asm` — Fast MSR LSTAR Syscall Dispatcher
- **MSR Hardware Setup**:
  - `MSR_STAR (0xC0000081)`: Configures Ring 0 kernel CS (`0x08`) and Ring 3 user CS (`0x20`).
  - `MSR_LSTAR (0xC0000082)`: Stores target 64-bit rip address of `syscall_entry`.
  - `MSR_SFMASK (0xC0000084)`: Mask flags cleared during syscall entry (Interrupts disabled, Trap flag cleared).
- **Dispatch Mechanism**:
  - Evaluates syscall number passed in `RAX`.
  - Routes standard calls: `SYS_EXIT` (`0x001`), `SYS_READ` (`0x003`), `SYS_WRITE` (`0x004`), `SYS_YIELD` (`0x018`).
  - Dispatches to `syscall_ai` handler when `RAX >= 0x600`.

### 2. `syscall_ai.asm` — Local AI Syscalls & Vector Engine
- **Dedicated AI Syscalls**:
  - `0x600 (SYS_AI_LOAD_MODEL)`: Maps GGUF model weights into physical memory address space.
  - `0x601 (SYS_AI_INFER)`: Initiates token forward pass through the Ring 1 C inference bridge.
  - `0x602 (SYS_AI_UNLOAD)`: Releases model weight physical allocations.
- **AVX-512 State Management**:
  - Allocates 512-byte aligned XSAVE area (`0x5000`).
  - Executes `xsave64 [rdi]` prior to executing heavy tensor math to preserve `ZMM0`-`ZMM31` vector registers without corrupting caller SIMD state.
  - Restores vector state using `xrstor64 [rdi]`.
