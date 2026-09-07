# 🚀 Ring 3 Bootloader Subsystem (`rings/ring_3/ring_3/boot/`)

The Boot subsystem contains the master multi-sector staged bootstrap orchestrator that coordinates system startup across all rings.

$$\text{Privilege Level: Ring 3 } (M \le 3) \quad | \quad \text{Dependencies: Ring 0, Ring 1, Ring 2, Ring 3}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `base.asm` — Master Staged Bootloader Orchestrator
- **Purpose**: Master NASM file that compiles into 4,096-byte (8-sector) raw disk image `base.bin`.
- **Layout**:
  - Sector 1 (`0x7C00 - 0x7DFF`): Includes `mbr.asm`, `memory.asm`, `console.asm`.
  - Sectors 2 & 3 (`0x7E00 - 0x81FF`): Includes `variable.asm`, `math.asm`, `string.asm`, `a20.asm`, `stage2.asm`.
  - Sector 4 (`0x8200 - 0x83FF`): Includes `keyboard.asm`, `stage4_console.asm`.
  - Sectors 5+ (`0x8400 - 0x8FFF`): Includes `gdt.asm`, `protected_mode.asm`, `paging.asm`, `long_mode.asm`.

### 2. `mbr.asm` — Sector 1 Master Boot Record
- **Purpose**: Loaded by BIOS POST at `0x0000:0x7C00`. Initializes segment registers (`DS=ES=SS=0`), sets stack pointer to `0x7C00`, clears screen, preserves boot drive ID in `DL`, and executes BIOS `INT 0x13, AH=0x02` to load 7 sectors from disk into memory at `0x7E00`.

### 3. `stage2.asm` — Sectors 2-3 Extended Loader & Diagnostics
- **Purpose**: Executes at `0x7E00`. Instantiates dynamic variables (`var_score`, `var_bonus`), tests typed addition and formatting, executes A20 gate multi-method enabler, and jumps to Sector 4.

### 4. `stage4_console.asm` — Sector 4 Interactive Prompt
- **Purpose**: Executes at `0x8200`. Renders interactive prompt (`HeaplitOS Prompt>`), captures command into buffer using `read_line`, and triggers Protected Mode transition.
