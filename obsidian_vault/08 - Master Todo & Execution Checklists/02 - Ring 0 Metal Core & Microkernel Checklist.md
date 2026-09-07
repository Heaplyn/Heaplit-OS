> **Status:** #status/implemented

# ⚡ Ring 0 Metal Core & Microkernel Checklist

> **Target Components:** `rings/ring_0/ring_0/` (`cpu`, `memory`, `sched`, `syscalls`, `types`)

---

## 1. Bootloader & CPU Initialization
- [x] **Sector 1 MBR (`mbr.asm`)**: Load 7 sectors to `0x7E00` via BIOS `INT 0x13 AH=0x02` #status/implemented
- [x] **A20 Line Gate (`a20.asm`)**: Multi-tier enabler (BIOS INT 0x15 -> Fast Port 0x92 -> 8042 Keyboard) #status/implemented
- [x] **Global Descriptor Table (`gdt.asm`)**: Set 64-bit Kernel Code (`0x08`), Kernel Data (`0x10`), User Code (`0x1B`), User Data (`0x23`), TSS (`0x28`) #status/implemented
- [x] **Interrupt Descriptor Table (`idt.asm`)**: 256 vector gates, exception stubs, APIC EOI signaling #status/implemented
- [x] **4-Level Paging (`paging.asm`)**: PML4 root @ `0x1000`, 2MB huge page directory, identity map + higher-half `0xFFFFFFFF80000000` #status/implemented
- [x] **Protected & Long Mode Switch (`protected_mode.asm`, `long_mode.asm`)**: `CR0.PE=1` -> PAE -> `EFER.LME=1` -> `CR0.PG=1` -> 64-bit Far Jump #status/implemented

## 2. Kernel Core Services & Memory
- [x] **Physical Memory Allocator (`pmm.asm`)**: 16MB bitmap array managing 512GB RAM via `lock bts` & `lock btr` #status/implemented
- [x] **Tickless ASM Scheduler (`scheduler.asm`)**: Context switch macro (`switch_threads`) preserving RAX..R15, RSP, and XSAVE AVX-512 state #status/implemented
- [x] **Fast Syscall Gateway (`syscall.asm`)**: MSR `IA32_LSTAR` hardware dispatching System V ABI registers (RDI, RSI, RDX, R10, R8, R9) #status/implemented
- [x] **Dynamic Variable Engine (`variable.asm`)**: 6-byte packed header layout, typed arithmetic (`add_variables`) #status/implemented
- [x] **Hardware Sandbox Guards (`sandbox.asm`)**: CR3 page directory isolation, `lock bts` spinlocks, `lock xadd` atomic additions #status/implemented
- [x] **AES-NI Cryptography (`crypto_aesni.asm`)**: Direct x86-64 `aesenc`/`aesenclast` encryption rounds #status/implemented

## 3. Pending Production Enhancements
- [ ] **APIC / IOAPIC Interrupt Gateway**: Replace legacy 8259 PIC with IOAPIC redirection table #status/future-implementation
- [ ] **SMP Multi-Core Booting**: Broadcast INIT-SIPI-SIPI over APIC ICR registers to boot APs #status/future-implementation
- [ ] **Per-CPU Storage**: Configure per-CPU `GS_BASE` registers (`MSR 0xC0000101`) #status/future-implementation
- [ ] **ACPI AML Power Control**: Parse RSDP/MADT/FADT for ACPI PM1a `S5` shutdown and Port `0xCF9` reboot #status/future-implementation
