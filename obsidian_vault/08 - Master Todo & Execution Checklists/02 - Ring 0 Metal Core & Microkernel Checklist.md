> **Status:** #status/implemented

# ⚡ Ring 0 Metal Core & Microkernel Checklist (Exhaustive Implementation Protocol)

> **Target Components:** `rings/ring_0/ring_0/` (`cpu`, `memory`, `sched`, `syscalls`, `types`)

---

## 1. Bootloader & CPU Initialization

- [x] **Sector 1 MBR (`mbr.asm`)**: Load 7 sectors to `0x7E00` via BIOS `INT 0x13 AH=0x02` #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **BIOS Boot Hook**: Executed by BIOS POST @ `0x0000:0x7C00`. Preserves BIOS drive ID passed in `DL` into memory `[boot_drive]`.
  > 2. **Registers Normalization**: Clears interrupts (`cli`), zeroes `DS`, `ES`, `SS`, and sets stack pointer `SP = 0x7C00`.
  > 3. **Disk Sector Read**: Issues BIOS `INT 0x13` (`AH = 0x02`, `AL = 7`, `CH = 0`, `CL = 2`, `DH = 0`, `ES:BX = 0x0000:0x7E00`).
  > 4. **Stage 2 Jump**: Verifies Carry Flag (`jnc stage2_entry`); prints error string and halts (`hlt`) if disk read fails.

- [x] **A20 Line Gate (`a20.asm`)**: Multi-tier enabler (BIOS INT 0x15 -> Fast Port 0x92 -> 8042 Keyboard) #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **A20 Test Function**: Writes test word to `0x0000:0x0500` and compares against `0xFFFF:0x0510` to check for 1MB memory wraparound.
  > 2. **Tier 1 (BIOS Interrupt)**: Invokes BIOS `INT 0x15` (`AX = 0x2401`). If Carry Flag is clear, re-checks wraparound test.
  > 3. **Tier 2 (Fast A20 Port 0x92)**: Performs I/O read on Port `0x92`, sets Bit 1 (`in al, 0x92`, `or al, 2`, `out 0x92, al`).
  > 4. **Tier 3 (8042 Controller)**: Sends command `0xAD` (Disable Keyboard) -> `0xD0` (Read Output Port) -> `0xD1` (Write Output Port with Bit 1 enabled) -> `0xAE` (Enable Keyboard).

- [x] **Global Descriptor Table (`gdt.asm`)**: Set 64-bit Kernel Code (`0x08`), Kernel Data (`0x10`), User Code (`0x1B`), User Data (`0x23`), TSS (`0x28`) #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **Descriptor Setup**: Defines Null Descriptor (`0x00`), 64-bit Kernel Code (`0x00AF9A000000FFFF`), Kernel Data (`0x00CF92000000FFFF`), User Code 32/64 (`0x00AFFA000000FFFF`), User Data (`0x00CFF2000000FFFF`), and 16-byte TSS descriptor.
  > 2. **GDTR Registration**: Constructs `gdt_descriptor` structure (16-bit limit, 64-bit physical base address) and issues `lgdt [gdt_descriptor]`.
  > 3. **Segment Reload**: Performs 64-bit far jump `jmp 0x08:.reload_cs` to load `CS = 0x08`, and sets `DS = ES = SS = 0x10`.

- [x] **Interrupt Descriptor Table (`idt.asm`)**: 256 vector gates, exception stubs, APIC EOI signaling #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **IDT Gate Struct**: Constructs 16-byte IDT gates (Target RIP Offset Low/High, CS Selector `0x08`, IST index, Attributes `0x8E` for Ring 0 Interrupt Gate).
  > 2. **Exception Vectors (0-31)**: Registers Assembly handlers for Division Error (`0`), Page Fault (`14`), General Protection Fault (`13`).
  > 3. **APIC EOI Signaling**: After servicing hardware IRQs (vectors 32-47), writes `0x00` to Local APIC EOI register (`0xFEE000B0`).
  > 4. **IDTR Registration**: Loads IDT pointer via `lidt [idt_descriptor]`.

- [x] **4-Level Paging (`paging.asm`)**: PML4 root @ `0x1000`, 2MB huge page directory, identity map + higher-half `0xFFFFFFFF80000000` #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **PML4 Setup**: Clears 4KB page frame @ physical `0x1000` for PML4 root. Points entry 0 to PDPT @ `0x2000` (`Present | Writeable`).
  > 2. **Higher-Half Mapping**: Points PML4 entry 511 (`0xFFFFFF8000000000`) to PDPT @ `0x2000` for higher-half kernel execution.
  > 3. **2MB Huge Page Directories**: Populates Page Directory @ `0x3000` with 2MB huge page flags (`PageSize bit 7 = 1`), identity mapping 0 - 1GB physical RAM.
  > 4. **CR3 Activation**: Writes `0x1000` into register `CR3`.

- [x] **Protected & Long Mode Switch (`protected_mode.asm`, `long_mode.asm`)**: `CR0.PE=1` -> PAE -> `EFER.LME=1` -> `CR0.PG=1` -> 64-bit Far Jump #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **Protected Mode Switch**: Sets `CR0.PE = 1` (Bit 0) and issues far jump `jmp 0x08:pm_entry` to enter 32-bit Protected Mode.
  > 2. **PAE Enable**: Sets `CR4.PAE = 1` (Physical Address Extension Bit 5).
  > 3. **Long Mode Enable**: Reads `IA32_EFER` MSR (`0xC0000080`), sets `LME` (Bit 8 = 1), and writes back via `wrmsr`.
  > 4. **Paging Enable**: Sets `CR0.PG = 1` (Bit 31) to activate 64-bit Long Mode and far jumps to 64-bit Kernel Main.

---

## 2. Kernel Core Services & Memory Management

- [x] **Physical Memory Allocator (`pmm.asm`)**: 16MB bitmap array managing 512GB RAM via `lock bts` & `lock btr` #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **Bitmap Reserve**: Allocates 16MB `pmm_bitmap` array in kernel `.bss` section (134,217,728 bits managing 512 GB).
  > 2. **Atomic Allocation**: In `pmm_alloc_page`, scans bitmap array using `lock bts [pmm_bitmap], rbx`. If carry flag is 0, bit was free and is now atomically claimed.
  > 3. **Physical Address Calculation**: Returns 64-bit physical address `(rbx << 12)`.
  > 4. **Atomic Free**: In `pmm_free_page`, computes bit index (`PhysicalAddress >> 12`) and issues `lock btr [pmm_bitmap], rdi`.

- [x] **Tickless ASM Scheduler (`scheduler.asm`)**: Context switch macro (`switch_threads`) preserving RAX..R15, RSP, and XSAVE AVX-512 state #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **APIC Timer Setup**: Configures Local APIC timer in one-shot mode (`0xFEE00320`). Sets initial count based on next scheduled thread deadline.
  > 2. **State Preservation**: On thread switch, pushes `RAX`-`R15` onto current stack, saves `RSP` into TCB structure, and executes `xsave64 [tcb_xsave_area]`.
  > 3. **Thread Selector**: Picks next ready thread from scheduler queue.
  > 4. **State Resumption**: Restores next thread `RSP`, executes `xrstor64 [next_tcb_xsave_area]`, pops registers, and executes `iretq`.

- [x] **Fast Syscall Gateway (`syscall.asm`)**: MSR `IA32_LSTAR` hardware dispatching System V ABI registers (RDI, RSI, RDX, R10, R8, R9) #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **MSR LSTAR Config**: Writes 64-bit address of `syscall_entry` into `IA32_LSTAR` MSR (`0xC0000082`). Sets `IA32_STAR` (`0xC0000081`) with Kernel CS `0x08` and User CS `0x1B`.
  > 2. **Hardware Entry**: `syscall` instruction automatically saves `RIP` -> `RCX`, `RFLAGS` -> `R11`, and loads `syscall_entry`.
  > 3. **Table Bounds Check**: Checks system call ID in `RAX` against `MAX_SYSCALLS`.
  > 4. **Dispatch & Return**: Invokes `call [syscall_table + RAX * 8]`, stores return status in `RAX`, and returns to userland via `sysretq`.

- [x] **Dynamic Variable Engine (`variable.asm`)**: 6-byte packed header layout, typed arithmetic (`add_variables`) #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **Packed Header Structure**: Byte 0: Type Tag (`0x01` Int, `0x02` String, `0x03` Vector), Byte 1: Flags, Bytes 2-5: Payload Size, Bytes 6-13: Heap Pointer.
  > 2. **Typed Addition (`add_variables`)**: Reads type tags of parameters. If both are `INT`, executes `add rax, rbx`; if strings, allocates buffer and concatenates.

- [x] **Hardware Sandbox Guards (`sandbox.asm`)**: CR3 page directory isolation, `lock bts` spinlocks, `lock xadd` atomic additions #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **Spinlock Implementation**: `spinlock_acquire` issues `lock bts [rdi], 0`. If locked, loops using `pause` instruction to minimize bus contention.
  > 2. **Atomic Add**: `atomic_add64` executes `lock xadd [rdi], rax` for lock-free thread counter updates.
  > 3. **CR3 Sandboxing**: `enforce_page_sandbox` loads isolated process PML4 table into `CR3`.

- [x] **AES-NI Cryptography (`crypto_aesni.asm`)**: Direct x86-64 `aesenc`/`aesenclast` encryption rounds #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **CPUID Feature Check**: Executes `CPUID.01H` and tests `ECX` Bit 25 (`bt ecx, 25`) to verify hardware AES-NI support.
  > 2. **Block Encryption**: Loads plaintext into `XMM0`, performs `pxor` whitening with Round Key 0, executes 9 `aesenc` rounds, and completes with `aesenclast`.

---

## 3. Advanced Multiprocessing & Power Controls (Mid-Term)

- [ ] **APIC / IOAPIC Interrupt Gateway**: Parse ACPI MADT table & replace legacy 8259 PIC with IOAPIC redirection table entries #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **PIC Masking**: Writes `0xFF` to master PIC port `0x21` and slave PIC port `0xA1` to disable legacy 8259 PIC.
  > 2. **MADT Parsing**: Locates IOAPIC physical address (default `0xFEC00000`) and LAPIC address (`0xFEE00000`) in ACPI `MADT` table.
  > 3. **Redirection Table Setup**: Writes IOAPIC register `0x10 + (2 * IRQ)` to assign hardware IRQs to CPU vectors `0x20`-`0xFF` with low-polarity / edge-triggered flags.

- [ ] **MSI / MSI-X Support**: Implement Message Signaled Interrupts for PCIe hardware devices #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Capability Search**: Scans PCIe device capability list for MSI (`0x05`) or MSI-X (`0x11`) capability structure.
  > 2. **Address & Data Configuration**: Writes target Local APIC physical address (`0xFEE00000`) into Message Address Register, and vector number (`0x20`-`0xFF`) into Message Data Register.
  > 3. **Control Bit Enable**: Sets Enable Bit in MSI Control Register to bypass legacy IRQ pins.

- [ ] **SMP Multi-Core Booting**: Broadcast INIT-SIPI-SIPI over APIC ICR registers to boot Application Processors (APs) #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **INIT IPI Broadcast**: Writes `0x000C4500` to Local APIC ICR register (`0xFEE00300`) to send INIT IPI to all secondary cores. Sleeps 10 ms.
  > 2. **SIPI IPI Broadcast**: Writes `0x000C4608` to ICR register (Startup IPI pointing to real-mode trampoline @ `0x8000`).
  > 3. **AP Trampoline Execution**: AP cores boot @ `0x8000`, load shared GDT/IDT/CR3 page tables, allocate per-CPU stack, set `GS_BASE`, and signal BSP completion flag.

- [ ] **Per-CPU Storage**: Configure per-CPU `GS_BASE` registers (`MSR 0xC0000101`) for TCB isolation #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Per-CPU Struct**: Allocates `percpu_t` structure containing Core ID, active thread TCB pointer, kernel stack top, and CPU stats.
  > 2. **MSR Write**: Executes `wrmsr` with `ECX = 0xC0000101` (`IA32_GS_BASE`) pointing to `percpu_t`.
  > 3. **Fast Access**: Kernel accesses core data via `mov rax, gs:[16]` without lock overhead.

- [ ] **ACPI Power Management**: Implement ACPI PM1a/PM1b `S5` shutdown, Port `0xCF9` reboot, and `S3` sleep #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **FADT Parsing**: Extracts `PM1a_CNT_BLK` and `PM1b_CNT_BLK` IO port addresses from ACPI FADT table.
  > 2. **S5 Shutdown**: Writes `SLP_TYPa | SLP_EN` (`(1 << 13)`) to `PM1a_CNT` port.
  > 3. **Hardware Reboot**: Writes `0x06` or `0x0E` to PCI Reset Control Port `0xCF9`.

- [ ] **HPET / APIC Timer Calibration**: Calibrate local APIC timer using HPET for nanosecond tickless resolution #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **HPET Discovery**: Maps HPET base address from ACPI `HPET` table (default `0xFED00000`).
  > 2. **Frequency Read**: Reads Main Counter Period register (`HPET + 0x00`) to determine femtoseconds per tick.
  > 3. **APIC Calibration**: Measures APIC timer ticks over a 10 ms HPET interval to calculate exact CPU bus frequency.

---

## 4. Far-Future Kernel Innovations

- [ ] **Hard Real-Time EDF Scheduler**: Earliest Deadline First (EDF) scheduler class providing <500 µs latency guarantees #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Deadline Queue**: Maintains red-black tree of real-time tasks sorted by absolute deadline (`t_deadline`).
  > 2. **Preemption Gate**: If new real-time task has an earlier deadline than current thread, issues immediate APIC self-IPI to force context switch.

- [ ] **eBPF Assembly Probe Engine**: Dynamic Ring 0 tracing engine allowing userland daemons to attach safe observation probes #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Bytecode Verifier**: Validates eBPF instructions (no unbounded loops, valid memory offsets, read-only kernel pointers).
  > 2. **JIT Compilation**: Compiles eBPF bytecode into native x86-64 machine code.
  > 3. **Probe Detour**: Replaces target kernel instruction with `INT 3` or `call` detour to execute probe routine.

- [ ] **Quantum-Resistant Cryptography**: Post-quantum ML-KEM / Kyber Assembly implementation for Ring 0 keys #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **NTT Assembly Loops**: Implements Number Theoretic Transform (NTT) polynomial matrix multiplications using AVX-512 vector instructions.
  > 2. **Key Encapsulation**: Provides `ml_kem_keypair()`, `ml_kem_encapsulate()`, `ml_kem_decapsulate()` Ring 0 system call entry points.

- [ ] **Radiation-Hardened Memory Scrubbing**: Multi-core parity and ECC background scrubbing engine #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Background Scrubber Thread**: Low-priority background thread scanning physical memory ranges during CPU idle states.
  > 2. **ECC / Parity Check**: Reads memory frames using AVX-512 non-temporal loads (`vmovntdqa`); traps Machine Check Exceptions (`Vector 18 MCE`) to remap faulty physical pages before application crashes occur.
