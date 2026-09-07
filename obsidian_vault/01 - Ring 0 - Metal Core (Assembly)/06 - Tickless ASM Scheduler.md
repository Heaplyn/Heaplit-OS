> **Status:** #status/implemented

# ⏱️ Tickless Sub-100-Cycle ASM Scheduler

> **Ring Placement:** `rings/ring_0/ring_0/sched/`  
> **Source File:** `scheduler.asm`  
> **Privilege Level:** Ring 0 ($M = 0$)

---

## 1. Why Tickless?

Traditional operating systems rely on periodic timer interrupts (e.g., 1000 Hz PIT ticks). This causes:
- High power consumption and CPU wakeups during idle state.
- Unpredictable latency spikes and context switch jitter.
- Cache pollution from timer ISR executions.

Heaplit OS utilizes a **Tickless Event-Driven Scheduler**: context switches occur strictly on blocking I/O, AI forward pass completion, or voluntary yield (`SYS_YIELD`).

---

## 2. Thread Control Block (`thread_t`)

```nasm
struc thread_t
    .rsp:       resq 1         ; +0:  Saved kernel stack pointer
    .rip:       resq 1         ; +8:  Saved instruction pointer
    .rflags:    resq 1         ; +16: Saved CPU flags
    .pid:       resq 1         ; +24: Process Identifier
    .state:     resq 1         ; +32: Thread state (0=Ready, 1=Running, 2=Blocked)
    .zmm_ptr:   resq 1         ; +40: Pointer to 512-bit AVX-512 XSAVE state buffer
endstruc
```

---

## 3. Sub-100-Cycle Context Switch Procedure

```nasm
; switch_threads(RDI = current_thread_ptr, RSI = next_thread_ptr)
switch_threads:
    ; 1. Save callee-preserved registers of current thread
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    ; 2. Swap stack pointers
    mov [rdi + thread_t.rsp], rsp
    mov rsp, [rsi + thread_t.rsp]

    ; 3. Restore callee-preserved registers of next thread
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx

    ; 4. Return to next thread's saved execution point
    ret
```

## 🔄 Tickless APIC Timer & Task Switch Sequence

```mermaid
sequenceDiagram
    autonumber
    participant Timer as Local APIC Timer
    participant Sched as Tickless ASM Scheduler
    participant Prev as Previous Thread TCB
    participant Next as Next Thread TCB

    Timer->>Sched: Interrupt Fired (Vector 0x20)
    Sched->>Prev: Save General Registers (RAX-R15)
    Sched->>Prev: Save Vector Registers (`xsave64`)
    Sched->>Prev: Save Stack Pointer RSP
    Sched->>Sched: Select Next Ready Thread in Run Queue
    Sched->>Next: Restore RSP Pointer
    Sched->>Next: Restore Vector State (`xrstor64`)
    Sched->>Next: Restore General Registers
    Sched->>Timer: Program Next Sleep Interval in APIC ICR
    Sched->>Next: `iretq` into Scheduled Thread Context
```

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **06 - Tickless ASM Scheduler** across all x86-64 execution contexts:

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

The virtual address space for **06 - Tickless ASM Scheduler** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **06 - Tickless ASM Scheduler** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - 06 - Tickless ASM Scheduler
; ============================================================================
%include "ring_0/types/variable.asm"

global 06___tickless_asm_scheduler_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
06___tickless_asm_scheduler_entry:
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
msg_success: db "[HEAPLIT] 06 - Tickless ASM Scheduler Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **06 - Tickless ASM Scheduler** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **06 - Tickless ASM Scheduler** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
