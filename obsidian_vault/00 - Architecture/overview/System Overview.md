> **Status:** #status/implemented

# 🏛️ Heaplit OS System Architecture

Heaplit OS is designed from first principles as a **Sovereign, Compiler-Native, AI-Embedded Operating System**. Rather than treating the AI Agent (**Heaplit**) as an untrusted, heavy userland web app, the AI engine is integrated directly into the ring execution hierarchy of the OS, while the bare-metal kernel speaks pure assembly directly to the hardware.

---

## 1. The 4-Layer Ring Dependency Hierarchy

Heaplit OS enforces a strict mathematical dependency hierarchy across its execution and organizational layers:

$$\text{A module in Ring } N \text{ can depend on / require modules from Ring } M \iff M \le N$$

Violating this rule introduces circular dependencies, layer violations, or silent loading crashes.

```mermaid
graph TD
    subgraph Ring3["Ring 3: Staged Boot Orchestration & Userland Applications"]
        R3_1["base.asm (Master Multi-Sector Orchestrator)"]
        R3_2["mbr.asm (Sector 1 Bootloader @ 0x7C00)"]
        R3_3["stage2.asm (Sectors 2-3 Diagnostics & Hardware Tests)"]
        R3_4["stage4_console.asm (Sector 4 Interactive Console)"]
        R3_5["entry.asm (Ring 3 Userland Shell & Applications)"]
    end

    subgraph Ring2["Ring 2: Presentation & Interactive Input Services"]
        R2_1["console.asm (Video Mode, Cursor Positioning, Hex/String Printers)"]
        R2_2["keyboard.asm (BIOS INT 0x16 Polling, Line Buffer Editor, Backspace)"]
        R2_3["The Lens Graph UI & Spatial Compositor (Future)"]
    end

    subgraph Ring1["Ring 1: Hardware Abstraction, Drivers & C Runtime Bridge"]
        R1_1["a20.asm (Multi-tier A20 Line Gate Enabler)"]
        R1_2["liba (Freestanding C Runtime: string.c, kprintf.c)"]
        R1_3["drivers (PCIe Scanner, VFS, GGML AI Engine Bridge)"]
    end

    subgraph Ring0["Ring 0: Pure Metal Utilities & Microkernel Core"]
        R0_1["types (variable.asm 6-byte engine, math.asm, string.asm)"]
        R0_2["memory (memory.asm block ops, pmm.asm 4KB bitmap allocator)"]
        R0_3["cpu (gdt.asm, idt.asm, paging.asm, protected_mode.asm, long_mode.asm)"]
        R0_4["sched (scheduler.asm tickless switch <100 cycles)"]
        R0_5["syscalls (syscall.asm MSR LSTAR, syscall_ai.asm 0x600-0x602 XSAVE)"]
    end

    Ring3 -->|"Can Require Ring 0, 1, 2, 3"| Ring2
    Ring3 -->|"Can Require Ring 0, 1, 2, 3"| Ring1
    Ring3 -->|"Can Require Ring 0, 1, 2, 3"| Ring0
    Ring2 -->|"Can Require Ring 0, 1, 2"| Ring1
    Ring2 -->|"Can Require Ring 0, 1, 2"| Ring0
    Ring1 -->|"Can Require Ring 0, 1"| Ring0
    Ring0 -->|"Strictly Independent (M = 0)"| Ring0
```

---

## 2. Layer-by-Layer Responsibilities

| Ring Layer | Directory Path | Allowed Dependencies | Core Responsibilities |
| :--- | :--- | :--- | :--- |
| **Ring 0** | `rings/ring_0/` | **Ring 0 only ($M \le 0$)** | Independent metal utilities, dynamic variable type system, string/math functions, memory block operations, PMM bitmap allocator, GDT/IDT/Paging tables, tickless scheduler, fast MSR LSTAR syscall dispatcher, AVX-512 XSAVE engine. **MUST NOT require Ring 1, 2, or 3.** |
| **Ring 1** | `rings/ring_1/` | **Ring 0, Ring 1 ($M \le 1$)** | Hardware lines (A20 gate), freestanding C runtime (`liba`), device drivers (PCIe enumeration, VFS with xattr graph hooks, GGML inference bridge). **MUST NOT require Ring 2 or 3.** |
| **Ring 2** | `rings/ring_2/` | **Ring 0, Ring 1, Ring 2 ($M \le 2$)** | Presentation and input services: VGA video mode control, cursor management, hex/string printers, interactive keyboard reader, line buffer editor with backspace handling. **MUST NOT require Ring 3.** |
| **Ring 3** | `rings/ring_3/` | **Ring 0, Ring 1, Ring 2, Ring 3 ($M \le 3$)** | Top-level staged boot orchestrator (`base.asm`), MBR bootstrap (`mbr.asm`), stage diagnostics (`stage2.asm`), interactive shell stage (`stage4_console.asm`), userland CPL=3 entrypoint (`entry.asm`), and Heaplit userland daemon. |

---

## 3. The Non-Monolithic "Scaffolded Abstraction" Mandate

Monolithic kernel codebases suffer from tight coupling, high cognitive overhead, and failure cascades. Heaplit OS enforces **Scaffolded Abstractions**:
- Every subsystem is isolated into a dedicated folder (`boot/`, `cpu/`, `memory/`, `types/`, `sched/`, `syscalls/`, `hardware/`, `console/`, `input/`, `userland/`).
- Each module has a single, well-defined responsibility.
- Modules expose clean procedural or structure-based ABIs.
- High-level orchestrators compose lower-level primitives without embedding low-level implementations.

---

## 4. Execution Flow: From Power-On to Userland

```mermaid
sequenceDiagram
    autonumber
    participant BIOS as BIOS POST (0xFFFF0)
    participant MBR as Ring 3: MBR (0x7C00)
    participant S2 as Ring 3: Stage 2 (0x7E00)
    participant S4 as Ring 3: Stage 4 Console (0x8200)
    participant PM as Ring 0: Protected Mode (32-bit)
    participant LM as Ring 0: Long Mode (64-bit)
    participant U3 as Ring 3: Userland Entry (CPL=3)

    BIOS->>MBR: Loads Sector 1 to 0x7C00, DL=Drive ID
    MBR->>MBR: Sets DS=ES=SS=0, SP=0x7C00, Clears Screen
    MBR->>MBR: INT 0x13 AH=0x02 (Reads 7 Sectors to 0x7E00)
    MBR->>S2: Jumps to 0x7E00
    S2->>S2: Tests Ring 0 Variable Engine (Add/Print)
    S2->>S2: Tests Ring 1 A20 Gate (BIOS/Fast/8042)
    S2->>S4: Jumps to 0x8200 (Stage 4)
    S4->>S4: Ring 2 Keyboard Line Editor Prompt
    S4->>PM: Switches to 32-bit PM (GDT, CR0.PE=1)
    PM->>LM: Enables PAE, Loads PML4 Page Tables, EFER.LME=1, CR0.PG=1
    LM->>LM: Initializes PMM Bitmap, Scheduler, IDT, Syscall MSRs
    LM->>U3: Drops to Ring 3 via iretq (CPL=3 Userland Shell)
```

---

## 5. Related Architectural Documents
- [[00 - Architecture/Exhaustive Code Architecture & Implementation Walkthrough|Exhaustive Code Architecture & Walkthrough]]
- [[00 - Architecture/Code Quality & Engineering Guidelines|Code Quality & Engineering Guidelines]]
- [[01 - Ring 0 - Metal Core (Assembly)/01 - Boot Sequence & Staged Loading|Ring 0 Boot & Staged Loading]]
- [[02 - Ring 1 - The C Overhead (Bridge)/01 - Freestanding C Runtime (liba)|Ring 1 Freestanding C Runtime]]
- [[03 - Ring 2 - Userland & Spatial UI/01 - Heaplit Daemon Architecture|Ring 2 / Ring 3 Userland Architecture]]

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **System Overview** across all x86-64 execution contexts:

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

The virtual address space for **System Overview** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **System Overview** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - System Overview
; ============================================================================
%include "ring_0/types/variable.asm"

global system_overview_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
system_overview_entry:
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
msg_success: db "[HEAPLIT] System Overview Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **System Overview** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **System Overview** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
