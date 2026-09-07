> **Status:** #status/implemented

# 🚀 Staged Boot Sequence & Multi-Sector Orchestration

> **Ring Placement:** `rings/ring_3/ring_3/boot/`  
> **Source Files:** `base.asm`, `mbr.asm`, `stage2.asm`, `stage4_console.asm`  
> **Compiled Output:** `base.bin` (4,096 bytes / 8 sectors)

---

## 1. Execution Flow & Memory Map

```mermaid
sequenceDiagram
    autonumber
    participant BIOS as BIOS POST (0xFFFF0)
    participant S1 as Sector 1: mbr.asm (0x7C00)
    participant S2 as Sectors 2-3: stage2.asm (0x7E00)
    participant S4 as Sector 4: stage4_console.asm (0x8200)
    participant PM as Protected Mode 32-bit (0x8400)
    participant LM as Long Mode 64-bit (0xFFFFFFFF80000000)

    BIOS->>S1: Loads 512 bytes to 0x0000:0x7C00, DL = Boot Drive ID
    S1->>S1: Initializes DS=ES=SS=0, SP=0x7C00, Clears Screen
    S1->>S1: Calls INT 0x13, AH=0x02 to load 7 sectors to 0x7E00
    S1->>S2: Far Jump to 0x7E00
    S2->>S2: Instantiates Ring 0 Dynamic Variable Engine
    S2->>S2: Executes Ring 1 Multi-Tier A20 Gate Enabler
    S2->>S4: Far Jump to 0x8200
    S4->>S4: Prompts user via Ring 2 Keyboard Line Editor
    S4->>PM: Loads GDT, sets CR0.PE = 1, jumps to pm_entry
    PM->>LM: Enables PAE, loads PML4 @ 0x1000, sets EFER.LME=1, CR0.PG=1
    LM->>LM: Kernel Main 64-bit initialization
```

### Memory Map Layout

| Memory Range | Size | Component | Ring | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00001000 - 0x00001FFF` | 4 KB | PML4 Table | Ring 0 | 4-Level Paging Root Table |
| `0x00002000 - 0x00002FFF` | 4 KB | PDPT Table | Ring 0 | Page Directory Pointer Table |
| `0x00003000 - 0x00003FFF` | 4 KB | PD Table | Ring 0 | 2MB Huge Page Directory Table |
| `0x00007000 - 0x00007BFF` | ~3 KB | Real Mode Stack | Ring 0 | Stack grows downward from `0x7C00` |
| `0x00007C00 - 0x00007DFF` | 512 B | Sector 1: MBR | Ring 3 | Bootstrap loader & disk sector reader |
| `0x00007E00 - 0x000081FF` | 1024 B | Sectors 2-3: Stage 2 | Ring 3 | Variable engine diagnostics & A20 test |
| `0x00008200 - 0x000083FF` | 512 B | Sector 4: Stage 4 | Ring 3 | Interactive console prompt & input editor |
| `0x00008400 - 0x00008FFF` | 3 KB | Sectors 5-8: PM/LM | Ring 0 | GDT, IDT, PM switch, Long Mode entry |

---

## 2. Sector-by-Sector Technical Breakdown

### Sector 1: Master Boot Record (`mbr.asm`)
1. **Interrupt Suspension:** Executes `cli` immediately upon BIOS jump.
2. **Drive ID Preservation:** Stores BIOS drive number passed in register `DL` into `[boot_drive]`.
3. **Segment Normalization:** Sets `DS = 0`, `ES = 0`, `SS = 0`, and stack pointer `SP = 0x7C00`.
4. **Teletype Clear Screen:** Invokes `clear_screen` from `rings/ring_2/ring_2/console/console.asm`.
5. **Disk Read Service:** Sets `AH = 0x02`, `AL = 7` (reads remaining 7 sectors of `base.bin`), `CH = 0`, `CL = 2` (start sector 2), `DH = 0`, `DL = [boot_drive]`, `ES:BX = 0x0000:0x7E00`.
6. **Error Trap:** If Carry Flag is set (`jc disk_error`), prints fatal diagnostic message and halts.
7. **Stage 2 Jump:** Transfers execution to `0x7E00`.

### Sectors 2 & 3: Extended Loader Diagnostics (`stage2.asm`)
1. **Dynamic Variable System Test:** Creates 6-byte typed variables `var_score` (100) and `var_bonus` (50), executes `add_variables`, and prints formatted result.
2. **A20 Gate Enable:** Invokes `enable_a20` across BIOS `INT 0x15`, Fast Port `0x92`, and 8042 Keyboard Controller.
3. **Stage 4 Jump:** Advances execution to `0x8200`.

### Sector 4: Interactive Console Prompt (`stage4_console.asm`)
1. Displays system banner and prompt string (`HeaplitOS Prompt> `).
2. Captures user line using `read_line` from `rings/ring_2/ring_2/input/keyboard.asm` with full backspace handling.
3. Echoes command line and stages processor for Protected Mode transition.

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **01 - Boot Sequence & Staged Loading** across all x86-64 execution contexts:

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

The virtual address space for **01 - Boot Sequence & Staged Loading** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **01 - Boot Sequence & Staged Loading** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - 01 - Boot Sequence & Staged Loading
; ============================================================================
%include "ring_0/types/variable.asm"

global 01___boot_sequence___staged_loading_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
01___boot_sequence___staged_loading_entry:
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
msg_success: db "[HEAPLIT] 01 - Boot Sequence & Staged Loading Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **01 - Boot Sequence & Staged Loading** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **01 - Boot Sequence & Staged Loading** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
