> **Status:** #status/implemented

# 🧠 Physical Memory Allocator (PMM)

> **Ring Placement:** `rings/ring_0/ring_0/memory/`  
> **Source File:** `pmm.asm`  
> **Privilege Level:** Ring 0 ($M = 0$)

---

## 1. Physical Memory Management Architecture

Heaplit OS uses a 64-bit Bitmap Physical Memory Manager (PMM) to track physical RAM frames.

- **Page Frame Size:** 4,096 bytes (4KB).
- **Tracking Mechanism:** 1 bit per page frame (`0` = Free, `1` = Allocated).
- **Capacity:** A 1MB bitmap tracks 8,388,608 page frames (32GB of physical RAM).
- **Bitmap Base Address:** Placed at physical address `0x00100000` (1MB mark) above BIOS reserved area.

---

## 2. BIOS E820 Map Parsing (`pmm_init`)

During bootstrap, BIOS function `INT 0x15, AX=0xE820` populates the physical memory map array:

```nasm
struc e820_entry
    .base_addr:  resq 1    ; +0:  Base physical address
    .length:     resq 1    ; +8:  Region length in bytes
    .type:       resd 1    ; +16: Type (1 = Free Usable RAM, 2 = Reserved)
    .acpi_attrs: resd 1    ; +20: ACPI 3.0 Extended Attributes
endstruc
```

`pmm_init` iterates through entry buffers, marks reserved physical regions (`Type != 1`) as allocated in the bitmap, and marks usable RAM as free.

---

## 3. Allocation & Deallocation Routines

### `pmm_alloc_page() -> RAX`
1. Scans bitmap dword-by-dword (`0xFFFFFFFF` check skips 32 allocated pages in a single instruction).
2. Finds first 0 bit using bit scan instruction `bsf`.
3. Sets bit to 1 (`bts`).
4. Calculates physical memory address: $\text{Physical Address} = \text{Bit Index} \times 4096$.
5. Returns physical base address in `RAX` (or `0` if out of memory).

### `pmm_free_page(RDI = phys_addr)`
1. Calculates bit index: $\text{Bit Index} = \text{RDI} / 4096$.
2. Clears bit in bitmap (`btr`).

## 🔄 PMM Page Allocation Flowchart

```mermaid
flowchart TD
    A["Page Allocation Request: `pmm_alloc_page()`"] --> B["Scan Bitmap Array starting from Last Free Bit"]
    B --> C{"Bit Value"}
    C -->|"1 (Allocated)"| D["Advance to Next Bit"]
    D --> B
    C -->|"0 (Free)"| E["Set Bit to 1 (Atomically via `lock bts`)"]
    E --> F["Calculate Physical Base Address: (Index * 4096)"]
    F --> G["Update Free Memory Counter"]
    G --> H["Return 64-bit Physical Address"]
```

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **05 - Physical Memory Allocator (PMM)** across all x86-64 execution contexts:

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

The virtual address space for **05 - Physical Memory Allocator (PMM)** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **05 - Physical Memory Allocator (PMM)** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - 05 - Physical Memory Allocator (PMM)
; ============================================================================
%include "ring_0/types/variable.asm"

global 05___physical_memory_allocator__pmm__entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
05___physical_memory_allocator__pmm__entry:
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
msg_success: db "[HEAPLIT] 05 - Physical Memory Allocator (PMM) Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **05 - Physical Memory Allocator (PMM)** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **05 - Physical Memory Allocator (PMM)** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
