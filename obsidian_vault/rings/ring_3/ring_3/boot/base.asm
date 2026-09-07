; =============================================================================
; Heaplit OS - Staged Bootloader Orchestrator (Ring 3 Orchestration Layer)
; Architecture: 16-bit Real Mode -> 32-bit Protected Mode -> 64-bit Long Mode -> Ring 3
; Ring Placement: rings/ring_3/ring_3/boot/base.asm
; =============================================================================
[org 0x7c00]
bits 16

jmp mbr_entry

; =============================================================================
; Sector 1: Master Boot Record (0x7C00 - 0x7DFF)
; =============================================================================
%include "mbr.asm"
%include "ring_0/memory/memory.asm"
%include "ring_2/console/console.asm"

; Pad Sector 1 to 510 bytes and append boot signature
times 510 - ($ - $$) db 0
dw 0xaa55

; =============================================================================
; Sectors 2 & 3: Extended Loader & Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
%include "ring_0/types/variable.asm"
%include "ring_0/types/math.asm"
%include "ring_0/types/string.asm"
%include "ring_1/hardware/a20.asm"
%include "stage2.asm"

; Pad Sectors 2 & 3 to 1024 bytes (total 1536 bytes from base)
times (512 * 3) - ($ - $$) db 0

; =============================================================================
; Sector 4: Interactive Console & Input Trigger (0x8200 - 0x83FF)
; =============================================================================
%include "ring_2/input/keyboard.asm"
%include "stage4_console.asm"

; Pad Sector 4 to 512 bytes (total 2048 bytes from base)
times (512 * 4) - ($ - $$) db 0

; =============================================================================
; Sectors 5+: 32-bit Protected Mode & 64-bit Long Mode Staging (Ring 0 -> Ring 3)
; =============================================================================
%include "ring_0/cpu/gdt.asm"
%include "ring_0/cpu/protected_mode.asm"
%include "ring_0/cpu/paging.asm"
%include "ring_0/cpu/long_mode.asm"

; Pad final kernel image to clean 4096-byte boundary (8 sectors total)
times 4096 - ($ - $$) db 0