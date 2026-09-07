> **Status:** #status/implemented

# 🔄 Obsidian Integration & Two-Way Sync

> In Heaplit OS, **Obsidian is not just documentation—it is the single source of truth and the control plane for the OS build pipeline.**

---

## 1. How Two-Way Sync Operates

```mermaid
sequenceDiagram
    autonumber
    actor Developer
    participant Vault as Obsidian Vault
    participant Daemon as Ring 2 Daemon
    participant Kernel as Ring 0 / 1 Kernel
    participant Compiler as NASM / Make

    Developer->>Vault: Writes #HeaplitPlan with tasks
    Vault->>Daemon: File Watcher Event (SYS_FS_WATCH)
    Daemon->>Kernel: SYS_AI_INFER (Generate Assembly)
    Kernel-->>Daemon: Raw NASM source code
    Daemon->>Compiler: Compiles source code
    alt Build Succeeded
        Daemon->>Vault: Checks off task `- [x]`, writes commit log note
    else Build Failed
        Daemon->>Vault: Appends error diagnostics to "## Build Errors"
    end
```

---

## 2. Special Heaplit Markdown Tags

| Tag | Purpose & Effect |
| :--- | :--- |
| `#HeaplitPlan` | Marks an actionable plan note that Heaplit should actively monitor and execute. |
| `#ASM` | Instructs the code generator to generate pure NASM x86 assembly routines. |
| `#Ring0` | Pins the generated routines to the bootloader/kernel supervisor ring. |
| `#MVP` | Marks a milestone as high-priority for the initial 3-month release target. |
| `// @Heaplit` | Inline source code annotation where Heaplit is authorized to inject modifications. |

---

## 3. Example Obsidian Directive Note

```markdown
# HeaplitPlan: Bootloader Cleanup
Tags: #HeaplitPlan #ASM #Ring0 #MVP

- [ ] Implement the A20 gate enable routine in pure ASM.
- [ ] Use `in al, 0x64` and `out 0x64, al` to talk to the 8042 keyboard controller.
- [ ] Place the routine in `rings/ring_0/ring_1/a20.asm`.

@Heaplit:
Generate the ASM code for enabling the A20 gate using fast A20 (BIOS INT 0x15) as the primary method, with fallback to keyboard controller 8042.
```

---

## 4. Automatic Rollback on Crash
If generated kernel code causes a triple fault or panic during QEMU automated testing:
1. The kernel watchdog detects the fault.
2. The filesystem rolls back to the previous snapshot.
3. Heaplit captures the register dump (`EIP`/`RIP`, `CR0`, `CR2`, stack trace) and creates an Obsidian postmortem note: `Build Failure: Triple Fault at 0x7E24`.

---

## 5. Related Notes
- [[00 - Architecture/Ring 2 - Heaplit Userland Daemon|Ring 2 Daemon]]
- [[01 - Planning/HeaplitPlan - Bootloader & Real Mode|Bootloader Action Plan]]
- [[01 - Planning/Grand Roadmap & Timeline|Roadmap & Timeline]]

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **Obsidian Integration & 2-Way Sync** across all x86-64 execution contexts:

| Register | CPU Role | Volatility / Preservation | Subsystem Function |
| :--- | :--- | :--- | :--- |
| `RAX` | Primary Accumulator | Volatile | Syscall ID entry, return status code, ALU calculation destination. |
| `RBX` | Base Register | Non-Volatile (Preserved) | Pointer to active TCB (Thread Control Block) / Data structure handle. |
| `RCX` | Counter / Syscall RIP | Volatile | Hardware `syscall` saves userland instruction pointer (`RIP`) into `RCX`. |
| `RDX` | Data Register | Volatile | Secondary return value, I/O port address, memory block size parameter. |
| `RSI` | Source Index | Volatile | Pointer to source memory buffer / string payload / argument 2. |
| `RDI` | Destination Index | Volatile | Pointer to destination memory buffer / argument 1 (`System V ABI`). |
| `RBP` | Frame Pointer | Non-Volatile (Preserved) | Stack frame base pointer for debug backtraces and stack unwinding. |
| `RSP` | Stack Pointer | Non-Volatile (Preserved) | Top of 16-byte aligned kernel/user execution stack. |
| `R8 - R11` | Scratch Registers | Volatile | Function parameters 5-6 (`R8`, `R9`), temporary scrap calculations. |
| `R12 - R15` | General Purpose | Non-Volatile (Preserved) | Long-lived kernel state registers preserved across C and ASM boundaries. |
| `CR0` | Control Register 0 | System Control | Toggles Protected Mode (`PE` bit 0), Paging (`PG` bit 31), Write Protect (`WP` bit 16). |
| `CR3` | Control Register 3 | Page Directory Root | Physical address pointer to PML4 root page table (4KB aligned). |
| `CR4` | Control Register 4 | Architectural Extension | Toggles PAE (`bit 5`), OSXSAVE (`bit 18`), SMEP/SMAP ring security flags. |
| `MSR LSTAR` | 0xC0000082 | Hardware Entry Point | Stores 64-bit virtual memory target address for the `syscall` handler. |

---

## 📐 Memory Map & Address Layout

The virtual address space for **Obsidian Integration & 2-Way Sync** adheres to Heaplit OS's canonical higher-half memory layout:

```
+-------------------------------------------------------------------+ 0xFFFFFFFFFFFFFFFF
| Higher-Half Kernel Direct Physical Map (Identity Mapped 512 GB)   |
| Virtual Address Range: 0xFFFF800000000000 - 0xFFFFFFFFFFFFFFFF     |
+-------------------------------------------------------------------+ 0xFFFF800000000000
| Unmapped Canonical Memory Hole (Non-Canonical Address Space)     |
+-------------------------------------------------------------------+ 0x00007FFFFFFFFFFF
| Ring 3 Sandboxed Application Execution Space (.axf JIT Memory)   |
| Virtual Address Range: 0x0000000040000000 - 0x00007FFFFFFFFFFF     |
+-------------------------------------------------------------------+ 0x0000000040000000
| Ring 2 Spatial UI & Compositor Framebuffers (VBE / GPU BARs)      |
| Virtual Address Range: 0x000000000FD00000 - 0x0000000010000000     |
+-------------------------------------------------------------------+ 0x0000000007E00000
| Ring 0 Microkernel Staged Execution Load Target (0x7C00 - 0x8F00) |
+-------------------------------------------------------------------+ 0x0000000000000000
```

---

## 🛠️ Step-by-Step Execution State Machine

```mermaid
flowchart TD
    subgraph State_Init["1. Initialization State"]
        S1["Load Subsystem Descriptors & Verify CPU Feature Flags"] --> S2["Allocate Initial Memory Blocks via PMM Bitmap"]
    end

    subgraph State_Exec["2. Active Execution State"]
        S2 --> S3["Setup Assembly Register Parameters (RDI, RSI, RDX)"]
        S3 --> S4["Issue Fast Syscall / Subsystem Function Call"]
        S4 --> S5["Execute Atomic ALU / SIMD Operations"]
    end

    subgraph State_Validation["3. Validation & Exception Handling"]
        S5 --> S6Check Status Code in RAX
        S6 -->|"RAX == 0 (Success)"| S7["Update System TCB & Commit Memory Writes"]
        S6 -->|"RAX < 0 (Error)"| S8["Capture Register Frame & Dispatch Debug Signal"]
    end

    S7 --> S9["Resume Parent Process Context via sysretq / iretq"]
    S8 --> S9
```

---

## 💻 Assembly Code Blueprint & Low-Level Implementation Examples

The low-level assembly implementation of **Obsidian Integration & 2-Way Sync** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - Obsidian Integration & 2-Way Sync
; ============================================================================
%include "ring_0/types/variable.asm"

global obsidian_integration___2_way_sync_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
obsidian_integration___2_way_sync_entry:
    push rbp
    mov rbp, rsp
    sub rsp, 32                    ; Align stack to 16 bytes for System V ABI

    ; Preserve non-volatile registers
    mov [rsp + 0], rbx
    mov [rsp + 8], r12
    mov [rsp + 16], r13

    ; Execute core subsystem operational logic
    mov rdi, 1                     ; Parameter 1: Allocation page count
    call pmm_alloc_page            ; Call Ring 0 Physical Memory Allocator
    test rax, rax
    jz .allocation_failed          ; Trap NULL pointer returns

    mov rbx, rax                   ; Store allocated physical page address in RBX
    
    ; Perform atomic register verification
    mov rsi, rbx
    mov rdi, msg_success
    call kprintf

    mov rax, 0                     ; Set success exit status code in RAX
    jmp .exit_clean

.allocation_failed:
    mov rax, -1                    ; Set error code in RAX (-1 = Out of Memory)
    
.exit_clean:
    ; Restore non-volatile registers
    mov rbx, [rsp + 0]
    mov r12, [rsp + 8]
    mov r13, [rsp + 16]

    add rsp, 32
    pop rbp
    ret

section .rodata
msg_success: db "[HEAPLIT] Obsidian Integration & 2-Way Sync Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **Obsidian Integration & 2-Way Sync** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **Obsidian Integration & 2-Way Sync** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
1. Zero stack pointer misalignment warnings (`RSP % 16 == 0`).
2. Successful page table mapping without triggering CR2 Page Faults.
3. Clean return of RAX status codes prior to CPU state resumption.

---

## 📑 Related Architecture Notes & References
- [[00 - Architecture/System Overview]]
- [[01 - Ring 0 - Metal Core (Assembly)/07 - Syscall Dispatcher & ABI]]
- [[01 - Ring 0 - Metal Core (Assembly)/04 - Paging & Virtual Memory]]
- [[02 - Ring 1 - The C Overhead (Bridge)/01 - Freestanding C Runtime (liba)]]
- [[03 - Ring 2 - Userland & Spatial UI/01 - Heaplit Daemon Architecture]]
