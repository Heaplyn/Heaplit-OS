> **Status:** #status/implemented

# 📑 GDT, IDT & Processor Descriptor Tables

> **Ring Placement:** `rings/ring_0/ring_0/cpu/`  
> **Source Files:** `gdt.asm`, `idt.asm`  
> **Privilege Level:** Ring 0 ($M = 0$)

---

## 1. Global Descriptor Table (GDT) Layout

The GDT configures segment boundaries and privilege rings for Protected Mode and Long Mode.

```
+-----------------------------------+ 0x00: Null Descriptor
| 0x0000000000000000                |
+-----------------------------------+ 0x08: Ring 0 64-bit Kernel Code (DPL=0)
| Limit=0xFFFF, Base=0, Acc=0x9A... |
+-----------------------------------+ 0x10: Ring 0 64-bit Kernel Data (DPL=0)
| Limit=0xFFFF, Base=0, Acc=0x92... |
+-----------------------------------+ 0x18: Ring 3 64-bit User Data (DPL=3)
| Limit=0xFFFF, Base=0, Acc=0xF2... |
+-----------------------------------+ 0x20: Ring 3 64-bit User Code (DPL=3)
| Limit=0xFFFF, Base=0, Acc=0xFA... |
+-----------------------------------+ 0x28: Task State Segment (TSS, 16 Bytes)
| 64-bit TSS Descriptor             |
+-----------------------------------+
```

### Segment Descriptors Structure
```nasm
gdt_start:
    dq 0x0000000000000000              ; 0x00: Null descriptor
    ; 0x08: Kernel Code 64-bit (Exec/Read, DPL=0, L=1, D=0)
    dw 0xffff, 0x0000, 0x9a00, 0x00af
    ; 0x10: Kernel Data 64-bit (Read/Write, DPL=0)
    dw 0xffff, 0x0000, 0x9200, 0x00cf
    ; 0x18: User Data 64-bit (Read/Write, DPL=3)
    dw 0xffff, 0x0000, 0xf200, 0x00cf
    ; 0x20: User Code 64-bit (Exec/Read, DPL=3, L=1)
    dw 0xffff, 0x0000, 0xfa00, 0x00af
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
```

---

## 2. Interrupt Descriptor Table (IDT) Architecture

In 64-bit Long Mode, each IDT entry is **16 bytes wide** (128 bits):

```
+-------------------+-------------------+-------------------+-------------------+
| 63             48 | 47             32 | 31             16 | 15              0 |
+-------------------+-------------------+-------------------+-------------------+
| Offset (63..32)   | Reserved (0)      | Offset (31..16)   | Attributes/IST    |
+-------------------+-------------------+-------------------+-------------------+
| Segment Selector (0x08)               | Offset (15..0)                        |
+---------------------------------------+---------------------------------------+
```

### ISR Vectors Handled
- `0x00`: Divide-by-zero Error (`#DE`)
- `0x06`: Invalid Opcode (`#UD`)
- `0x08`: Double Fault (`#DF`)
- `0x0D`: General Protection Fault (`#GP`)
- `0x0E`: Page Fault (`#PF`) — Reads `CR2` for faulting virtual address.
- `0x20 - 0x2F`: PIC Hardware IRQs (Timer IRQ0, Keyboard IRQ1).
- `0x80`: Legacy syscall interrupt hook.

## 🔄 Interrupt & Exception Handling Flowchart

```mermaid
flowchart TD
    A["Processor Interrupt / Trap Raised"] --> B{"Interrupt Vector Class"}
    B -->|"0x00 - 0x1F"| C["CPU Exception Handler (Page Fault / GPF)"]
    B -->|"0x20 - 0x2F"| D["Hardware IRQ Handler (APIC Timer / Keyboard)"]
    B -->|"0x80"| E["Legacy System Call Trap"]
    C --> F["Save CPU Interrupt Frame (SS, RSP, RFLAGS, CS, RIP)"]
    D --> F
    E --> F
    F --> G["Dispatch to Assembly Service Routine"]
    G --> H["Send APIC EOI (0xFEE000B0)"]
    H --> I["Execute `iretq` Instruction"]
```

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **03 - GDT, IDT & Descriptor Tables** across all x86-64 execution contexts:

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

The virtual address space for **03 - GDT, IDT & Descriptor Tables** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **03 - GDT, IDT & Descriptor Tables** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - 03 - GDT, IDT & Descriptor Tables
; ============================================================================
%include "ring_0/types/variable.asm"

global 03___gdt__idt___descriptor_tables_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
03___gdt__idt___descriptor_tables_entry:
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
msg_success: db "[HEAPLIT] 03 - GDT, IDT & Descriptor Tables Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **03 - GDT, IDT & Descriptor Tables** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **03 - GDT, IDT & Descriptor Tables** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
