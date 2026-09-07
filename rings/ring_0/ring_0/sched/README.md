# ⏱️ Ring 0 Scheduler Subsystem (`rings/ring_0/ring_0/sched/`)

The Scheduler subsystem implements a tickless, event-driven context switcher capable of swapping thread contexts in under 100 CPU cycles.

$$\text{Privilege Level: Ring 0 } (M = 0) \quad | \quad \text{Dependencies: None (Strictly Independent)}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `scheduler.asm` — Tickless ASM Scheduler
- **Thread Control Block (`thread_t`) Structure**:
  - `+0 (8 bytes)`: `rsp` (Saved kernel stack pointer).
  - `+8 (8 bytes)`: `rip` (Instruction pointer for thread resume).
  - `+16 (8 bytes)`: `rflags` (Saved processor flags).
  - `+24 (8 bytes)`: `pid` (Process identifier).
  - `+32 (8 bytes)`: `state` (`0` = Ready, `1` = Running, `2` = Blocked, `3` = Dead).
  - `+40 (8 bytes)`: `zmm_ptr` (Pointer to 512-bit AVX-512 XSAVE vector state buffer).
- **Procedures**:
  - `switch_threads(RDI=current_thread_ptr, RSI=next_thread_ptr)`:
    1. Saves callee-preserved registers (`RBX`, `RBP`, `R12`, `R13`, `R14`, `R15`) onto current stack.
    2. Stores `RSP` into `[RDI + thread_t.rsp]`.
    3. Loads new stack pointer `mov RSP, [RSI + thread_t.rsp]`.
    4. Restores callee-preserved registers from new stack.
    5. Returns via `ret` directly to next thread's resume point.
