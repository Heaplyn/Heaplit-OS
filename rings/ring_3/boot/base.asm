; =============================================================================
; Heaplit OS - Staged Bootloader Orchestrator (Ring 3 Orchestration Layer)
; Architecture: 16-bit Real Mode -> 32-bit Protected Mode -> 64-bit Long Mode -> Ring 3
; Ring Placement: rings/ring_3/boot/base.asm
; =============================================================================
[org 0x7c00]                            ; Execute hardware step
bits 16

jmp mbr_entry                           ;Unconditional jump to target label mbr_entry

; =============================================================================
; Sector 1: Master Boot Record (0x7C00 - 0x7DFF)
; =============================================================================
%include "mbr.asm"                      ; Execute hardware step
%include "../../ring_0/memory/memory.asm" ; Execute hardware step
%include "../../ring_2/console/console.asm" ; Execute hardware step

; Pad Sector 1 to 510 bytes and append boot signature
times 510 - ($ - $$) db 0               ; Execute hardware step
dw 0xaa55                               ; Execute hardware step

; =============================================================================
; Sectors 2 & 3: Extended Loader & Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
%include "../../ring_0/types/variable.asm" ; Execute hardware step
%include "../../ring_0/types/math.asm"  ; Execute hardware step
%include "../../ring_0/types/string.asm" ; Execute hardware step
%include "../../ring_1/hardware/a20.asm" ; Execute hardware step
%include "stage2.asm"                   ; Execute hardware step

; Pad Sectors 2 & 3 to 1024 bytes (total 1536 bytes from base)
times (512 * 3) - ($ - $$) db 0         ; Execute hardware step

; =============================================================================
; Sector 4: Interactive Console & Input Trigger (0x8200 - 0x83FF)
; =============================================================================
%include "../../ring_2/input/keyboard.asm" ; Execute hardware step
%include "stage4_console.asm"           ; Execute hardware step

; Pad Sector 4 to 512 bytes (total 2048 bytes from base)
times (512 * 4) - ($ - $$) db 0         ; Execute hardware step

; =============================================================================
; Sectors 5+: 32-bit Protected Mode & 64-bit Long Mode Staging (Ring 0 -> Ring 3)
; =============================================================================
%include "../../ring_0/cpu/gdt.asm"     ; Execute hardware step
%include "../../ring_0/cpu/protected_mode.asm" ; Execute hardware step
%include "../../ring_0/cpu/paging.asm"  ; Execute hardware step
%include "../../ring_0/cpu/long_mode.asm" ; Execute hardware step
%include "../../ring_1/hardware/thread.asm" ; Execute hardware step
%include "../userland/ring3_transition.asm" ; Execute hardware step
%include "../userland/entry.asm"        ; Execute hardware step

; Pad final kernel image to clean 4096-byte boundary (8 sectors total)
times (512 * 8) - ($ - $$) db 0         ; Execute hardware step
