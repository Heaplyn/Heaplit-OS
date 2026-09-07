; =============================================================================
; Heaplit OS - Global Descriptor Table (GDT)
; Ring Placement: rings/ring_0/cpu/gdt.asm (Ring 0)
; Included by: rings/ring_3/boot/base.asm, directly before protected_mode.asm
; =============================================================================
;
; WHY A GDT IS STILL NEEDED
; --------------------------
; x86 segmentation can never be fully switched off. Even running a "flat"
; memory model (base=0, limit=max) - and even in 64-bit Long Mode, where the
; MMU ignores segment Base/Limit entirely for code and data - the CPU still
; requires CS/DS/SS/ES/FS/GS to hold valid *selectors*. A selector is just an
; index into a descriptor table (this GDT, or an LDT), and the CPU reads the
; descriptor it points to on every segment load to determine the requested
; privilege level (RPL), the descriptor's privilege level (DPL), whether it's
; a code or data segment, and - critically in Long Mode - the L-bit that puts
; the CPU into 64-bit instruction decoding for that segment. No valid GDT
; means CS/SS can never be loaded, so nothing after `lgdt` can execute.
;
; LIFECYCLE / WHO LOADS THIS
; ----------------------------
; This table is built once, statically, at assembly time (it never changes at
; runtime - there is no dynamic descriptor allocation here). It is loaded
; exactly once via `lgdt [gdt_descriptor]` in protected_mode.asm, immediately
; before `CR0.PE` is set to 1 to leave 16-bit real mode. The same physical
; table is reused, unmodified, all the way through the 32-bit -> 64-bit ->
; Ring 3 transitions; only the *selector values* loaded into the segment
; registers change (e.g. long_mode.asm reloads DS/ES/SS with DATA_SEG_64,
; ring3_transition.asm loads the Ring-3 selectors with RPL=3 OR'd in).
; `gdt_descriptor_64` is the 64-bit-operand-sized GDTR image (8-byte base
; instead of 4-byte) provided for any future re-load of the same table once
; the CPU is fully in Long Mode; it is not currently invoked anywhere.
;
; SEGMENT DESCRIPTOR BYTE LAYOUT (8 bytes per entry, low byte first)
; --------------------------------------------------------------------
;   Bytes 0-1: Limit  [15:0]
;   Bytes 2-3: Base   [15:0]
;   Byte  4:   Base   [23:16]
;   Byte  5:   Access byte     -> Present(1) | DPL(2) | S(1) | Type(4)
;   Byte  6:   Flags | Limit   -> Gran(1) | Size(1) | Long(1) | AVL(1) | Limit[19:16](4)
;   Byte  7:   Base   [31:24]
;
; Access byte Type nibble for code/data descriptors (S=1) is itself 4 bits:
; [Executable | Conforming/Direction | Readable-or-Writable | Accessed].
; This file always leaves the Accessed bit clear (the CPU sets it lazily on
; first use) and never sets Conforming, so every code segment here is a
; strict, non-conforming segment matching its own DPL exactly.
;
; In Long Mode, once the L-bit (byte 6, bit 5) is set on a code descriptor,
; the CPU ignores that descriptor's Base and Limit fields entirely (flat 64-
; bit addressing is implicit) - which is why every 64-bit entry below hard-
; codes Base=0/Limit=0. They are structurally required padding; only the
; Access byte (Present/DPL/Type) and the L-bit are functionally meaningful.
; The two 32-bit entries (0x08, 0x10) are the exception: they run before
; paging/Long Mode exist, so their Base=0/Limit=0xFFFFF (with 4KB granularity
; -> 4GB effective limit) fields are real and enforced by the CPU.

align 16
gdt_start:
    ; 0x00: Null Descriptor - mandatory placeholder. Loading CS/SS with
    ; selector 0x00 is architecturally defined to always #GP fault, which is
    ; intentionally used elsewhere (e.g. unused segment registers) as a safe
    ; "must never be dereferenced" sentinel value.
    dq 0x0000000000000000               ;8 zero bytes: Limit=0, Base=0, Access=0, Flags=0

    ; 0x08: Kernel 32-bit Code Segment (Base=0, Limit=4GB, Exec/Read, 32-bit)
    ; Used only briefly: protected_mode.asm far-jumps here right after CR0.PE=1
    ; to flush the prefetch queue and load a 32-bit CS before paging/Long Mode.
    dw 0xFFFF                           ;Limit 0..15
    dw 0x0000                           ;Base 0..15
    db 0x00                             ;Base 16..23
    db 10011010b                        ;Access: Present(1), Ring0(00), Code(1), Exec(1), Read(1), Acc(0)
    db 11001111b                        ;Flags: 4KB Gran(1), 32-bit(1), LongMode(0), Limit 16..19
    db 0x00                             ;Base 24..31

    ; 0x10: Kernel 32-bit Data Segment (Base=0, Limit=4GB, Read/Write, 32-bit)
    ; Loaded into DS/ES/SS immediately after the 0x08 far jump so the 32-bit
    ; kernel stack/data accesses are valid before Long Mode is entered.
    dw 0xFFFF                           ;Limit 0..15 (same 4GB flat limit as 0x08)
    dw 0x0000                           ;Base 0..15
    db 0x00                             ;Base 16..23
    db 10010010b                        ;Access: Present(1), Ring0(00), Data(1), Write(1), Acc(0)
    db 11001111b                        ;Flags: 4KB Gran(1), 32-bit(1)
    db 0x00                             ;Base 24..31

    ; 0x18: Kernel 64-bit Code Segment (Base=0, Long Mode L=1)
    ; Target of the far jump out of protected_mode.asm into long_mode_entry_64
    ; once CR4.PAE, EFER.LME and CR0.PG have all been set. This is the
    ; Ring 0 CS used for the rest of kernel execution, and it is also the
    ; selector value written into IA32_STAR[47:32] (see syscall.asm) so that
    ; the `syscall` instruction lands back here on every trap from userland.
    dw 0x0000                           ;Limit 0 (ignored in Long Mode)
    dw 0x0000                           ;Base 0..15 (ignored in Long Mode)
    db 0x00                             ;Base 16..23 (ignored in Long Mode)
    db 10011010b                        ;Access: Present(1), Ring0(00), Code(1), Exec(1), Read(1)
    db 00100000b                        ;Flags: Long Mode bit(1), 32-bit bit(0) -> L=1,D=0 per spec
    db 0x00                             ;Base 24..31 (ignored in Long Mode)

    ; 0x20: Kernel 64-bit Data Segment (Base=0, Long Mode)
    ; Loaded into DS/ES/SS/FS/GS by long_mode_entry_64 right after the far
    ; jump above. Also implicitly the kernel SS used on `syscall` entry,
    ; since the CPU derives it as IA32_STAR[47:32] + 8 = 0x18 + 8 = 0x20.
    dw 0x0000                           ;Limit 0 (ignored in Long Mode)
    dw 0x0000                           ;Base 0..15 (ignored in Long Mode)
    db 0x00                             ;Base 16..23 (ignored in Long Mode)
    db 10010010b                        ;Access: Present(1), Ring0(00), Data(1), Write(1)
    db 00000000b                        ;Flags: no Long/Gran bits needed for a data descriptor
    db 0x00                             ;Base 24..31 (ignored in Long Mode)

    ; 0x28: User 64-bit Data Segment (Ring 3 / Userland)
    ; DPL=3 lets Ring 3 code load this selector (with RPL=3 OR'd in, giving
    ; selector value 0x2B) into DS/ES/SS/FS/GS after the iretq/ring3 transition.
    dw 0x0000                           ;Limit 0 (ignored in Long Mode)
    dw 0x0000                           ;Base 0..15 (ignored in Long Mode)
    db 0x00                             ;Base 16..23 (ignored in Long Mode)
    db 11110010b                        ;Access: Present(1), Ring3(11), Data(1), Write(1)
    db 00000000b                        ;Flags: no Long/Gran bits needed for a data descriptor
    db 0x00                             ;Base 24..31 (ignored in Long Mode)

    ; 0x30: User 64-bit Code Segment (Ring 3 / Userland)
    ; DPL=3, L=1. Loaded (as selector 0x33 = 0x30|3) via iretq/ring3_transition
    ; to drop the CPU to CPL=3 for userland/entry.asm.
    dw 0x0000                           ;Limit 0 (ignored in Long Mode)
    dw 0x0000                           ;Base 0..15 (ignored in Long Mode)
    db 0x00                             ;Base 16..23 (ignored in Long Mode)
    db 11111010b                        ;Access: Present(1), Ring3(11), Code(1), Exec(1), Read(1)
    db 00100000b                        ;Flags: Long Mode bit(1)
    db 0x00                             ;Base 24..31 (ignored in Long Mode)

gdt_end:

; GDTR image for `lgdt` while still in 32-bit/compatibility addressing - the
; base field here is only 32 bits wide, which is all protected_mode.asm needs
; since gdt_start lives well below the 4GB boundary at boot time.
gdt_descriptor:
    dw gdt_end - gdt_start - 1          ;GDT Size (limit) = table size in bytes - 1
    dd gdt_start                        ;GDT Base Address (32-bit)

; 64-bit-operand GDTR image (8-byte base) for re-loading the same table once
; running fully in Long Mode. Not currently invoked by any code path; kept
; for a future higher-half kernel remap where gdt_start's linear address
; could exceed 32 bits.
gdt_descriptor_64:
    dw gdt_end - gdt_start - 1          ;GDT Size (limit), identical to gdt_descriptor
    dq gdt_start                        ;GDT Base Address (64-bit)

; Segment Selector Constants
; A selector is (index << 3) | TI(1) | RPL(2); since TI=0 (GDT, not LDT) and
; these are the raw Ring 0 index values, no shifting is needed - the byte
; offset of each descriptor above already doubles as its selector value.
CODE_SEG_32 equ 0x08                    ;Ring 0 32-bit code selector (protected_mode.asm far jump)
DATA_SEG_32 equ 0x10                    ;Ring 0 32-bit data selector (protected_mode.asm DS/ES/SS)
CODE_SEG_64 equ 0x18                    ;Ring 0 64-bit code selector; also IA32_STAR[47:32]
DATA_SEG_64 equ 0x20                    ;Ring 0 64-bit data selector; also implied SYSCALL SS
; RPL=3 (binary 11) is OR'd into the index so these selectors can only ever
; be loaded while already running at CPL=3 - loading a DPL=3 descriptor with
; RPL=0 from Ring 0 code is legal but would be a privilege-check bug waiting
; to happen, so baking `| 3` into the constant name is a deliberate guard.
USER_DATA_64 equ 0x28 | 3               ;Ring 3 64-bit data selector (0x2B)
USER_CODE_64 equ 0x30 | 3               ;Ring 3 64-bit code selector (0x33)

; NOTE - SYSRET selector convention: `sysret` in 64-bit mode does not use
; USER_CODE_64/USER_DATA_64 directly. It derives CS = IA32_STAR[63:48] + 16
; and SS = IA32_STAR[63:48] + 8. syscall.asm currently programs STAR[63:48]
; with 0x28 (this table's User Data descriptor), which would make `sysret`
; load CS = 0x38 (past the end of this table - no such descriptor exists)
; and SS = 0x30 (the User *Code* descriptor, not a valid data segment for
; SS). If/when `sysret` is actually exercised, either add a placeholder
; selector at 0x38 and reorder so STAR[63:48]+8/+16 land on USER_DATA_64/
; USER_CODE_64 respectively, or switch the return path to `iretq` (which
; ring3_transition.asm already uses successfully, since it loads USER_DATA_64
; and USER_CODE_64 explicitly rather than relying on the STAR offset math).
