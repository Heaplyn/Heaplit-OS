> **Status:** #status/implemented

# 📋 HeaplitPlan: AI Syscall Subsystem

Tags: #HeaplitPlan #Ring0 #Ring1 #ASM #MVP

> **Target:** Wire the bare-metal x86_64 Long Mode syscall handler to the dedicated Heaplit AI inference subsystem (`0x600`–`0x6FF`).

---

## 1. Actionable Milestones

- [ ] **MSR Syscall Registration:**
  - [ ] Configure `IA32_EFER.SCE` (Syscall Enable bit).
  - [ ] Set `IA32_STAR` (`0xC0000081`) with kernel and user CS/SS segment selectors.
  - [ ] Set `IA32_LSTAR` (`0xC0000082`) to point to the kernel ASM syscall entry point.
  - [ ] Set `IA32_SFMASK` (`0xC0000084`) to mask `RFLAGS` on syscall entry.
- [ ] **SIMD Context Preservation Area:**
  - [ ] Allocate 4KB aligned XSAVE buffer at `0xFFFFFFFF80000000 + 0x5000`.
  - [ ] Check `CPUID.(EAX=0xD, ECX=0)` for XSAVE area size and feature mask (`XCR0`).
  - [ ] Set `CR4.OSXSAVE = 1` and configure `XCR0` for X87, SSE, AVX, and AVX-512 states (`0x7` or `0xE7`).
- [ ] **Syscall Dispatcher (`syscall_ai_dispatcher.asm`):**
  - [ ] Intercept `RAX == 0x600` $\rightarrow$ `SYS_AI_LOAD_MODEL`
  - [ ] Intercept `RAX == 0x601` $\rightarrow$ `SYS_AI_INFER`
  - [ ] Intercept `RAX == 0x602` $\rightarrow$ `SYS_AI_SCHEDULE_TASK`
  - [ ] Implement `xsave` before C trampoline and `xrstor` before `sysretq`.
- [ ] **Ring 1 C Trampoline Interface:**
  - [ ] Implement `ai_load_model_c` in freestanding C.
  - [ ] Implement `ai_infer_c` with AVX-512 target flags.
  - [ ] Implement error propagation (`RAX = -1` on failure).

---

## 2. Heaplit Prompt Directive

```markdown
@Heaplit:
Implement the Long Mode assembly syscall handler in `src/kernel/syscall_ai.asm` that saves AVX-512 state with XSAVE, switches to the kernel stack, and calls `ai_infer_c`.
```

---

## 3. Related Files & Notes
- Syscall Spec: [[02 - Reference/api/AI Syscall Specification|AI Syscall Specification]]
- Ring 0 Spec: [[00 - Architecture/rings/Ring 0 - Metal & Scheduler|Ring 0 - Metal & Scheduler]]
- Ring 1 Spec: [[00 - Architecture/rings/Ring 1 - The C Inference Engine|Ring 1 - The C Inference Engine]]

## 🔄 AI Syscall Subsystem Sequence Flowchart

```mermaid
sequenceDiagram
    autonumber
    participant App as Ring 3 App / Spatial UI
    participant Sys as Ring 0 Syscall Entry (LSTAR)
    participant Kernel as Ring 0 AI Vector Manager
    participant GGUF as Ring 1 GGML C Engine

    App->>Sys: Assembly `syscall` (RAX=0xA1, RDI=PromptPtr, RSI=Len)
    Sys->>Kernel: Validate Memory Pointer & Context Bounds
    Kernel->>GGUF: Invoke `ggml_graph_compute()` with AVX-512 SIMD
    GGUF-->>Kernel: Return Generated Token Buffer Pointer
    Kernel-->>Sys: Copy Token Data to Userland Buffer
    Sys-->>App: `sysretq` returning Token Count in RAX
```

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **HeaplitPlan - AI Syscall Subsystem** across all x86-64 execution contexts:

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

The virtual address space for **HeaplitPlan - AI Syscall Subsystem** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **HeaplitPlan - AI Syscall Subsystem** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - HeaplitPlan - AI Syscall Subsystem
; ============================================================================
%include "ring_0/types/variable.asm"

global heaplitplan___ai_syscall_subsystem_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
heaplitplan___ai_syscall_subsystem_entry:
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
msg_success: db "[HEAPLIT] HeaplitPlan - AI Syscall Subsystem Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **HeaplitPlan - AI Syscall Subsystem** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **HeaplitPlan - AI Syscall Subsystem** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
1. Zero stack pointer misalignment warnings (`RSP % 16 == 0`).
2. Successful page table mapping without triggering CR2 Page Faults.
3. Clean return of RAX status codes prior to CPU state resumption.

---

## 📑 Related Architecture Notes & References
- [[00 - Architecture/overview/System Overview|System Overview]]
- [[01 - Ring 0 - Metal Core (Assembly)/ring_0/syscalls/07 - Syscall Dispatcher & ABI|07 - Syscall Dispatcher & ABI]]
- [[01 - Ring 0 - Metal Core (Assembly)/ring_0/cpu/04 - Paging & Virtual Memory|04 - Paging & Virtual Memory]]
- [[02 - Ring 1 - The C Overhead (Bridge)/ring_1/liba/01 - Freestanding C Runtime (liba)|01 - Freestanding C Runtime (liba)]]
- [[03 - Ring 2 - Userland & Spatial UI/ring_2/daemon/01 - Heaplit Daemon Architecture|01 - Heaplit Daemon Architecture]]
