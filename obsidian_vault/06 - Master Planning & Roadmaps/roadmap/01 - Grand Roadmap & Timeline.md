> **Status:** #status/implemented

# 🗺️ Heaplit OS Grand Roadmap & Timeline

> **Target Release:** 3-Month Minimum Viable Product (MVP)  
> **Goal:** Fully self-hosting, AI-native microkernel that executes prompts from Obsidian to build bare-metal features.

---

## 1. Master Implementation Timeline (Weeks 1 – 20)

```mermaid
gantt
    title Heaplit OS 20-Week Master Timeline
    dateFormat  YYYY-MM-DD
    section Phase 0: Foundations
    AVX-512 XSAVE Stub in syscall.asm       :done, p0_1, 2026-09-01, 14d
    section Phase 1: Inference Engine
    Port GGML / Llama.cpp to Ring 1 C        :active, p1_1, 2026-09-15, 28d
    Huge-Page PML4 Allocator in ASM         :p1_2, 2026-09-22, 21d
    section Phase 2: Trampoline
    SYS_AI_INFER Syscall Trampoline         :p2_1, 2026-10-13, 14d
    section Phase 3: Daemon
    Ring 2 Daemon Skeleton & Socket Listener:p3_1, 2026-10-27, 14d
    Obsidian SYS_FS_WATCH File Monitor      :p3_2, 2026-11-03, 14d
    section Phase 4: Code Gen
    Prompt Pipeline -> NASM Output          :p4_1, 2026-11-10, 28d
    section Phase 5: Auto-Build
    Make / NASM execution & Error Parser    :p5_1, 2026-12-08, 14d
    section Phase 6: Full Integration
    Obsidian Plan -> ISO Build -> QEMU Loop :p6_1, 2026-12-22, 28d
```

---

## 2. Phase-by-Phase Breakdown

### Phase 0 (Weeks 1–2): ASM Dispatcher & SIMD State
- [x] Convert existing codebase to strict `snake_case` naming conventions.
- [x] Multi-sector bootloader loading (Sector 1 MBR $\rightarrow$ Sector 2 $\rightarrow$ Sector 3).
- [ ] Port `xsave` / `xrstor` 512-bit vector area at fixed address `0xFFFFFFFF80000000 + 0x5000`.
- [ ] CPUID feature check for AVX-512 foundation (`AVX512F`) and `XSAVEOPT`.

### Phase 1 (Weeks 3–6): Ring 1 C Engine & Model Mapper
- [ ] Port GGML transformer logic into freestanding C library (`liba`).
- [ ] Implement `-mno-red-zone` and `-mavx512f` builds.
- [ ] Implement huge-page virtual memory mapping (2MB / 1GB pages) in Ring 0.
- [ ] GGUF quantized weights file loader via kernel VFS.

### Phase 2 (Weeks 7–8): Syscall Trampoline Interface
- [ ] Connect ASM syscall `SYS_AI_INFER` (`0x601`) to `ai_infer_c`.
- [ ] `IA32_PERF_CTL` MSR performance frequency boost on inference entry.
- [ ] Implement safe zero-copy string buffer passing across rings.

### Phase 3 (Weeks 9–10): Ring 2 Daemon Skeleton
- [ ] Create `/system/bin/heaplit` daemon process.
- [ ] Expose `/tmp/heaplit.sock` IPC endpoint.
- [ ] Hook into `SYS_FS_WATCH` (`0x30`) to monitor `~/Documents/Obsidian/`.

### Phase 4 (Weeks 11–14): Autonomous Code Generation
- [ ] Construct ASM-optimized generation prompts with register context.
- [ ] BPE tokenization and sampling in Ring 1.
- [ ] Output verification and syntax validation for NASM code blocks.

### Phase 5 (Weeks 15–16): Auto-Build & Error Diagnostics
- [ ] Connect daemon to resident NASM/LLVM compiler.
- [ ] Parse compiler warnings and errors from stderr.
- [ ] Two-way writeback to Obsidian note `## Build Errors` section.

### Phase 6 (Weeks 17–20): Complete Self-Hosting Loop
- [ ] Heaplit reads `#HeaplitPlan`, writes kernel code, compiles ISO, and tests inside QEMU.
- [ ] Automatic rollback on panic or triple fault.

---

## 3. Related Action Plans
- [[01 - Planning/HeaplitPlan - Bootloader & Real Mode|Bootloader Action Plan]]
- [[01 - Planning/HeaplitPlan - Variable System & Memory|Variable System Plan]]
- [[01 - Planning/HeaplitPlan - AI Syscall Subsystem|AI Syscall Plan]]

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **Grand Roadmap & Timeline** across all x86-64 execution contexts:

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

The virtual address space for **Grand Roadmap & Timeline** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **Grand Roadmap & Timeline** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - Grand Roadmap & Timeline
; ============================================================================
%include "ring_0/types/variable.asm"

global grand_roadmap___timeline_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
grand_roadmap___timeline_entry:
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
msg_success: db "[HEAPLIT] Grand Roadmap & Timeline Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **Grand Roadmap & Timeline** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **Grand Roadmap & Timeline** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
