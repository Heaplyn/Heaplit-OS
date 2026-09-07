> **Status:** #status/implemented

# 💾 Physical Memory Allocator (PMM 4KB Bitmap Allocator)

> **Ring Placement:** `rings/ring_0/ring_0/memory/`  
> **Source File:** `pmm.asm`  
> **Compiled Target:** Core Kernel Module (Ring 0)  
> **Hardware Alignment:** 4KB Page Frame Boundary (`0x1000`)

---

## 1. Overview & Architectural Role

The **Physical Memory Allocator (PMM)** is Ring 0's foundational memory manager. Responsible for managing up to 512 GB of physical RAM, the PMM uses a 16MB bitmap array (`pmm_bitmap`) where each bit represents a single 4KB physical page frame. It employs x86-64 Bit Scan Forward (`bsf`) and atomic Bit Test and Set (`lock bts`) instructions to guarantee multi-core thread safety without kernel deadlocks.

```mermaid
flowchart TD
    subgraph PMM_Allocation["pmm_alloc_page() Allocation Loop"]
        A["Allocation Request"] --> B["Scan pmm_bitmap starting from pmm_last_searched"]
        B --> C{"Atomic Bit Test & Set (lock bts)"}
        C -->|"Carry = 0 (Was Free)"| D["Bit Set to 1 Atomically"]
        C -->|"Carry = 1 (Was Allocated)"| E["Increment Index & Repeat Search"]
        D --> F["Calculate Physical Address: Index * 4096"]
        F --> G["Decrement Free Page Counter & Return Address in RAX"]
    end
```

---

## 2. Low-Level API & Assembly Routines

### `pmm_init(RDI = TotalPhysicalMemoryBytes)`
- Calculates total 4KB pages (`TotalBytes >> 12`).
- Clears the `pmm_bitmap` memory region (`16,384 KB`).
- Sets `pmm_free_pages` counter and zeroes `pmm_last_searched`.

### `pmm_alloc_page()`
- Scans `pmm_bitmap` using `lock bts [pmm_bitmap], rbx`.
- On finding a zero bit, atomically sets it to 1 and returns physical base address `(rbx << 12)`.
- If memory is exhausted, wraps around to index 0; returns NULL (`RAX = 0`) on failure.

### `pmm_free_page(RDI = PhysicalAddress)`
- Computes page index (`PhysicalAddress >> 12`).
- Executes `lock btr [pmm_bitmap], rdi` (Bit Test and Reset) to return the page frame to the free pool.

---

## 3. Register & Memory Specifications

| Register / Variable | Data Type | Function |
| :--- | :--- | :--- |
| `pmm_bitmap` | `resb 16384 * 1024` | 16MB bitmap array managing 134,217,728 physical page frames. |
| `pmm_total_pages` | `resq 1` | Total system page frame count. |
| `pmm_free_pages` | `resq 1` | Counter tracking currently available 4KB pages. |
| `pmm_last_searched` | `resq 1` | Index hint for next allocation pass to reduce bitmap search overhead. |

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
