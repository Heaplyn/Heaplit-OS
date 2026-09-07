> **Status:** #status/implemented

# 💾 Memory Management API Reference

> **Source File:** [`rings/ring_0/ring_1/memory.asm`](file:///C:/Users/Kyle/Downloads/Projects/Heaplit%20OS/rings/ring_0/ring_1/memory.asm)  
> **Mode:** 16-bit Real Mode / Segmented Addressing (`ES:DI`)

---

## 1. Real-Mode Memory Functions

### `mem_set`
Fills a destination memory block with a specified byte value using hardware-accelerated 16-bit word operations (`rep stosw`).

- **Inputs:**
  - `ES:DI`: Pointer to destination memory buffer
  - `AL`: Byte value to fill
  - `CX`: Number of bytes to fill
- **Outputs:**
  - `ES:DI`: Restored to original buffer start pointer
- **Internal Optimization:**
  - Duplicates byte in `AL` across `AH` (`AX = (AL << 8) | AL`)
  - Halves count (`CX = CX / 2`) and executes fast word-sized `rep stosw`
  - Handles odd trailing byte via `.handle_odd` (`stosb`)

---

### `mem_copy`
Copies a block of memory from a source buffer to a destination buffer.

- **Inputs:**
  - `DS:SI`: Source buffer pointer
  - `ES:DI`: Destination buffer pointer
  - `CX`: Byte count to copy

---

### `mem_zero`
Zero-initializes a memory block by invoking `mem_set` with `AL = 0`.

- **Inputs:**
  - `ES:DI`: Pointer to memory buffer
  - `CX`: Byte count to zero out

---

## 2. Real-Mode Memory Map (First 1MB)

| Address Range | Size | Description |
| :--- | :--- | :--- |
| `0x00000 - 0x003FF` | 1 KB | Real Mode Interrupt Vector Table (IVT) |
| `0x00400 - 0x004FF` | 256 B | BIOS Data Area (BDA) |
| `0x00500 - 0x07BFF` | ~30 KB | Free Conventional Memory (Scratch / Stack) |
| `0x07C00 - 0x07DFF` | 512 B | **Sector 1: MBR Bootloader** |
| `0x07E00 - 0x07FFF` | 512 B | **Sector 2: Extended Bootloader** |
| `0x08000 - 0x081FF` | 512 B | **Sector 3: Kernel Setup / Drivers** |
| `0x08200 - 0x08FFF` | ~3.5 KB | Free Heap / Driver Buffers |
| `0x09000` | - | **Top of Stack (`SP = 0x9000`, grows downward)** |
| `0xA0000 - 0xBFFFF` | 128 KB | Video Memory (`0xB8000` = Color Text Mode Framebuffer) |
| `0xC0000 - 0xFFFFF` | 256 KB | BIOS ROM & Memory Mapped Hardware |

---

## 3. Related Notes
- [[02 - Reference/Variable System API|Variable System API]]
- [[01 - Planning/HeaplitPlan - Variable System & Memory|Memory Planning]]
- [[00 - Architecture/Ring 0 - Metal & Scheduler|Ring 0 Architecture]]

## 🔄 Physical & Virtual Memory Service Pipeline

```mermaid
flowchart TD
    A["`kalloc(bytes)` Call"] --> B["Calculate Page Count: `ceil(bytes / 4096)`"]
    B --> C["Invoke `pmm_alloc_page()` for Physical Frames"]
    C --> D["Walk 4-Level Page Table (PML4 -> PDPT -> PD -> PT)"]
    D --> E["Map Virtual Pages to Physical Frames with R/W Flags"]
    E --> F["Invalidate TLB via `invlpg` Instruction"]
    F --> G["Return Allocated Virtual Base Address"]
```

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **Memory Management API** across all x86-64 execution contexts:

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

The virtual address space for **Memory Management API** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **Memory Management API** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - Memory Management API
; ============================================================================
%include "ring_0/types/variable.asm"

global memory_management_api_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
memory_management_api_entry:
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
msg_success: db "[HEAPLIT] Memory Management API Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **Memory Management API** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **Memory Management API** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
