# 🔌 Ring 1 Hardware Subsystem (`rings/ring_1/ring_1/hardware/`)

The Hardware subsystem manages physical address line gating (A20 Gate) to unlock access to memory above the 1MB real-mode boundary.

$$\text{Privilege Level: Ring 1 } (M \le 1) \quad | \quad \text{Dependencies: Ring 0, Ring 1}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `a20.asm` — Multi-Tier A20 Line Gate Enabler
- **Purpose**: Enables the 21st address line (A20), eliminating 1MB address wraparound.
- **Execution Pipeline**:
  1. `check_a20`: Compares memory at `0x0000:0x7E00` vs `0xFFFF:0x7E10`. If values match after test inversion, A20 is disabled (wrapped). If distinct, A20 is enabled.
  2. **Method 1 (BIOS Fast A20)**: Calls BIOS `INT 0x15, AX=0x2401`.
  3. **Method 2 (Fast A20 Gate)**: Reads System Control Port A (`0x92`), sets Bit 1, and writes back (`out 0x92, al`).
  4. **Method 3 (8042 Keyboard Controller)**: Sends command `0xD1` to Port `0x64`, then writes `0xDF` to Port `0x60`.
