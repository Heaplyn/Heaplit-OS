# 🌌 Heaplit OS - The 4-Ring Microkernel Hierarchy

This directory contains the foundational ring architecture for Heaplit OS, organized strictly by privilege rings and single-responsibility submodules.

---

## 🏛️ The Ring Dependency Law

Heaplit OS enforces a strict mathematical dependency hierarchy across all modules:

$$\text{A module in Ring } N \text{ can depend on / require modules from Ring } M \iff M \le N$$

- **Ring 0 (`rings/ring_0/ring_0/`)**: Pure metal utilities, data types, memory operations, CPU tables (GDT/IDT/Paging), scheduler, fast syscalls. Strictly independent ($M = 0$).
- **Ring 1 (`rings/ring_1/ring_1/`)**: Hardware line gate (A20), freestanding C standard library (`liba`), device drivers (PCIe, VFS, AI inference bridge). Can require Ring 0 and Ring 1 ($M \le 1$).
- **Ring 2 (`rings/ring_2/ring_2/`)**: Presentation and input services (VGA console, cursor, hex/string printers, interactive keyboard buffer editor). Can require Ring 0, Ring 1, Ring 2 ($M \le 2$).
- **Ring 3 (`rings/ring_3/ring_3/`)**: Staged bootloader orchestrator (`base.asm`, `mbr.asm`, `stage2.asm`, `stage4_console.asm`), userland CPL=3 shell (`entry.asm`), and userland daemons. Can require Ring 0, 1, 2, 3 ($M \le 3$).

---

## 📂 Subdirectory Organization

```
rings/
├── ring_0/                                # Ring 0 Metal Core & Utilities (M <= 0)
│   ├── README.md                          # Documentation for Ring 0 components
│   └── ring_0/
│       ├── types/                         # Dynamic variable system, math, strings
│       ├── memory/                        # Block memory utils, PMM bitmap allocator
│       ├── cpu/                           # GDT, IDT, Paging tables, PM/LM transitions
│       ├── sched/                         # Tickless thread scheduler (<100 cycles)
│       └── syscalls/                      # MSR LSTAR dispatcher, AVX-512 XSAVE engine
│
├── ring_1/                                # Ring 1 Hardware & Driver Bridge (M <= 1)
│   ├── README.md                          # Documentation for Ring 1 components
│   └── ring_1/
│       ├── hardware/                      # A20 gate multi-method enabler
│       ├── liba/                          # Freestanding C runtime (string.c, kprintf.c)
│       └── drivers/                       # PCIe scanner, VFS graph hooks, GGML bridge
│
├── ring_2/                                # Ring 2 Presentation & Input (M <= 2)
│   ├── README.md                          # Documentation for Ring 2 components
│   └── ring_2/
│       ├── console/                       # Video mode, cursor management, print utils
│       └── input/                         # BIOS INT 0x16 reader, line buffer editor
│
└── ring_3/                                # Ring 3 Boot Orchestrator & Userland (M <= 3)
    ├── README.md                          # Documentation for Ring 3 components
    └── ring_3/
        ├── boot/                          # Staged MBR, stage2, stage4 console, base.asm
        └── userland/                      # Ring 3 CPL=3 entrypoint & shell
```

---

## 🔨 Build & Execution

To compile the entire staged operating system and launch in QEMU:
```powershell
.\loader\load_os.ps1
```
