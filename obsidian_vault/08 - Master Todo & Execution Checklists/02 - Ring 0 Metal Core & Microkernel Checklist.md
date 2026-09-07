> **Status:** #status/implemented

# ⚡ Ring 0 Metal Core & Microkernel Checklist (Exhaustive)

> **Target Components:** `rings/ring_0/ring_0/` (`cpu`, `memory`, `sched`, `syscalls`, `types`)

---

## 1. Bootloader & CPU Initialization
- [x] **Sector 1 MBR (`mbr.asm`)**: Load 7 sectors to `0x7E00` via BIOS `INT 0x13 AH=0x02` #status/implemented
- [x] **A20 Line Gate (`a20.asm`)**: Multi-tier enabler (BIOS INT 0x15 -> Fast Port 0x92 -> 8042 Keyboard) #status/implemented
- [x] **Global Descriptor Table (`gdt.asm`)**: Set 64-bit Kernel Code (`0x08`), Kernel Data (`0x10`), User Code (`0x1B`), User Data (`0x23`), TSS (`0x28`) #status/implemented
- [x] **Interrupt Descriptor Table (`idt.asm`)**: 256 vector gates, exception stubs, APIC EOI signaling #status/implemented
- [x] **4-Level Paging (`paging.asm`)**: PML4 root @ `0x1000`, 2MB huge page directory, identity map + higher-half `0xFFFFFFFF80000000` #status/implemented
- [x] **Protected & Long Mode Switch (`protected_mode.asm`, `long_mode.asm`)**: `CR0.PE=1` -> PAE -> `EFER.LME=1` -> `CR0.PG=1` -> 64-bit Far Jump #status/implemented

## 2. Kernel Core Services & Memory Management
- [x] **Physical Memory Allocator (`pmm.asm`)**: 16MB bitmap array managing 512GB RAM via `lock bts` & `lock btr` #status/implemented
- [x] **Tickless ASM Scheduler (`scheduler.asm`)**: Context switch macro (`switch_threads`) preserving RAX..R15, RSP, and XSAVE AVX-512 state #status/implemented
- [x] **Fast Syscall Gateway (`syscall.asm`)**: MSR `IA32_LSTAR` hardware dispatching System V ABI registers (RDI, RSI, RDX, R10, R8, R9) #status/implemented
- [x] **Dynamic Variable Engine (`variable.asm`)**: 6-byte packed header layout, typed arithmetic (`add_variables`) #status/implemented
- [x] **Hardware Sandbox Guards (`sandbox.asm`)**: CR3 page directory isolation, `lock bts` spinlocks, `lock xadd` atomic additions #status/implemented
- [x] **AES-NI Cryptography (`crypto_aesni.asm`)**: Direct x86-64 `aesenc`/`aesenclast` encryption rounds #status/implemented

## 3. Advanced Multiprocessing & Power Controls (Mid-Term)
- [ ] **APIC / IOAPIC Interrupt Gateway**: Parse ACPI MADT table & replace legacy 8259 PIC with IOAPIC redirection table entries #status/future-implementation
- [ ] **MSI / MSI-X Support**: Implement Message Signaled Interrupts for PCIe hardware devices #status/future-implementation
- [ ] **SMP Multi-Core Booting**: Broadcast INIT-SIPI-SIPI over APIC ICR registers to boot Application Processors (APs) #status/future-implementation
- [ ] **Per-CPU Core Data Structures**: Configure per-CPU `GS_BASE` registers (`MSR 0xC0000101`) for TCB isolation #status/future-implementation
- [ ] **ACPI Power Management**: Implement ACPI PM1a/PM1b `S5` shutdown, Port `0xCF9` reboot, and `S3` sleep #status/future-implementation
- [ ] **HPET / APIC Timer Calibration**: Calibrate local APIC timer using HPET for nanosecond tickless resolution #status/future-implementation

## 4. Far-Future Kernel Innovations
- [ ] **Hard Real-Time EDF Scheduler**: Earliest Deadline First (EDF) scheduler class providing <500 µs latency guarantees #status/future-implementation
- [ ] **eBPF Assembly Probe Engine**: Dynamic Ring 0 tracing engine allowing userland daemons to attach safe observation probes #status/future-implementation
- [ ] **Quantum-Resistant Cryptography**: Post-quantum ML-KEM / Kyber Assembly implementation for Ring 0 keys #status/future-implementation
- [ ] **Radiation-Hardened Memory Scrubbing**: Multi-core parity and ECC background scrubbing engine #status/future-implementation

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **02 - Ring 0 Metal Core & Microkernel Checklist** across all x86-64 execution contexts:

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

The virtual address space for **02 - Ring 0 Metal Core & Microkernel Checklist** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **02 - Ring 0 Metal Core & Microkernel Checklist** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - 02 - Ring 0 Metal Core & Microkernel Checklist
; ============================================================================
%include "ring_0/types/variable.asm"

global 02___ring_0_metal_core___microkernel_checklist_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
02___ring_0_metal_core___microkernel_checklist_entry:
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
msg_success: db "[HEAPLIT] 02 - Ring 0 Metal Core & Microkernel Checklist Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **02 - Ring 0 Metal Core & Microkernel Checklist** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **02 - Ring 0 Metal Core & Microkernel Checklist** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
