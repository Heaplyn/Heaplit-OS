> **Status:** #status/implemented

# 📋 HeaplitPlan: Bootloader & Real Mode Execution

Tags: #HeaplitPlan #ASM #Ring0 #MVP

> **Target:** Robust multi-sector boot sequence that transitions from 16-bit Real Mode to 32-bit Protected Mode and 64-bit Long Mode.

---

## 1. Actionable Milestones

- [x] **Sector 1 (MBR at `0x7C00`):** Set up segment registers (`DS`, `ES`, `SS`, `SP=0x7C00`), save boot drive ID from `DL`.
- [x] **Multi-Sector Disk Read:** Use BIOS `INT 0x13, AH=0x02` to load extended sectors into `0x7E00` (Sector 2) and `0x8000` (Sector 3).
- [ ] **A20 Gate Enable Routine:**
  - [ ] Test A20 line status via memory wrap-around check at `0x0000:0x7E00` vs `0xFFFF:0x7E10`.
  - [ ] Method 1 (Fast A20): BIOS `INT 0x15, AX=0x2401`.
  - [ ] Method 2 (Fallback): 8042 Keyboard Controller via `in al, 0x64` / `out 0x64, al`.
  - [ ] Method 3 (Fast Port A): Port `0x92`.
- [ ] **Global Descriptor Table (GDT):**
  - [ ] Null Descriptor (8 bytes `0x00`).
  - [ ] 32-bit Kernel Code Segment (`0x08`, Base 0, Limit 4GB, Type `0x9A`, Flags `0xCF`).
  - [ ] 32-bit Kernel Data Segment (`0x10`, Base 0, Limit 4GB, Type `0x92`, Flags `0xCF`).
  - [ ] 64-bit Code Segment Descriptor (`0x18`, Long mode flag `0x20`).
- [ ] **Protected Mode Switch:**
  - [ ] Disable interrupts (`cli`).
  - [ ] Load GDT register (`lgdt [gdt_descriptor]`).
  - [ ] Set `PE` (Protection Enable) bit in `CR0` (`mov eax, cr0; or al, 1; mov cr0, eax`).
  - [ ] Far jump to flush CPU prefetch pipeline (`jmp 0x08:protected_mode_entry`).
- [ ] **Paging & Long Mode Switch:**
  - [ ] Set up identity-mapped 4-level PML4 page tables.
  - [ ] Enable PAE (`CR4.PAE = 1`).
  - [ ] Set `LME` (Long Mode Enable) in `EFER` MSR (`0xC0000080`).
  - [ ] Enable paging (`CR0.PG = 1`).
  - [ ] Long jump into 64-bit kernel entry point.

---

## 2. Heaplit Prompt Directive

```markdown
@Heaplit:
Generate the assembly module `rings/ring_0/ring_1/a20.asm` with full A20 line testing, fast BIOS INT 0x15 enable, and 8042 keyboard controller fallback routine.
```

---

## 3. Related Files & Notes
- Source: [`rings/ring_0/base.asm`](file:///C:/Users/Kyle/Downloads/Projects/Heaplit%20OS/rings/ring_0/base.asm)
- Loader: [`loader/load_os.ps1`](file:///C:/Users/Kyle/Downloads/Projects/Heaplit%20OS/loader/load_os.ps1)
- Architecture: [[00 - Architecture/rings/Ring 0 - Metal & Scheduler|Ring 0 - Metal & Scheduler]]

## 🔄 Bootloader & Long Mode Switch Pipeline

```mermaid
flowchart TD
    A["Real Mode Sector 1 (0x7C00)"] --> B["INT 0x13 Read Sectors 2-8"]
    B --> C["Stage 2: Dynamic Variable Engine Test"]
    C --> D["A20 Line Activation (BIOS / Port 0x92 / 8042)"]
    D --> E["Load GDT & Set CR0.PE = 1 (32-bit Protected Mode)"]
    E --> F["Setup 4-Level Page Tables (PML4, PDPT, PD, PT)"]
    F --> G["Set CR4.PAE = 1, IA32_EFER.LME = 1, CR0.PG = 1"]
    G --> H["Far Jump to 64-bit Long Mode Kernel Entry"]
```

---

## 🔬 In-Depth Architectural & Technical Specifications

### Hardware & Processor Register Contract
Heaplit OS enforces strict register management conventions for **HeaplitPlan - Bootloader & Real Mode** across all x86-64 execution contexts:

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

The virtual address space for **HeaplitPlan - Bootloader & Real Mode** adheres to Heaplit OS's canonical higher-half memory layout:

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

The low-level assembly implementation of **HeaplitPlan - Bootloader & Real Mode** uses canonical NASM syntax optimized for x86-64 execution:

```nasm
; ============================================================================
; Heaplit OS Low-Level Core Blueprint - HeaplitPlan - Bootloader & Real Mode
; ============================================================================
%include "ring_0/types/variable.asm"

global heaplitplan___bootloader___real_mode_entry
extern pmm_alloc_page
extern kprintf

section .text
bits 64

align 16
heaplitplan___bootloader___real_mode_entry:
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
msg_success: db "[HEAPLIT] HeaplitPlan - Bootloader & Real Mode Subsystem initialized at physical address: 0x%x", 10, 0
```

---

## 🔍 Verification, QEMU Testing & Diagnostics

### Headless QEMU Emulation Verification
To test **HeaplitPlan - Bootloader & Real Mode** within the Heaplit OS kernel binary (`base.bin`), execute the host automated build script:

```powershell
# Execute build and launch QEMU emulator with serial debugging
.\loader\load_os.ps1
```

### Serial Log Verification Protocol
During execution, **HeaplitPlan - Bootloader & Real Mode** outputs diagnostic traces to COM1 Serial Port (`0x3F8`). Verified serial outputs must confirm:
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
