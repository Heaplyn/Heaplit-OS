# 👤 Ring 3 Userland Subsystem (`rings/ring_3/ring_3/userland/`)

The Userland subsystem contains unprivileged (CPL=3) userland applications, shells, and daemons.

$$\text{Privilege Level: Ring 3 } (M \le 3) \quad | \quad \text{Dependencies: Ring 0, Ring 1, Ring 2, Ring 3}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `entry.asm` — Ring 3 Userland Entrypoint (CPL=3)
- **Purpose**: Represents unprivileged userland execution.
- **Behavior**:
  - Executes in 64-bit Long Mode with CPL=3 (`CS=0x20 | 3`, `SS=0x18 | 3`).
  - Access to privileged instructions (`cli`, `lgdt`, `mov cr0`) is blocked by CPU hardware protection.
  - Invokes operating system services exclusively through the `syscall` instruction (`SYS_YIELD` `0x018`, `SYS_EXIT` `0x001`).
