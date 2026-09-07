; =============================================================================
; Heaplit OS - Staged Bare-Metal Bootloader
; Architecture: 16-bit Real Mode -> 32-bit Protected Mode -> 64-bit Long Mode -> Ring 3
; Ring Placement: rings/ring_0/base.asm
; =============================================================================
[org 0x7c00]
bits 16

jmp start

; =============================================================================
; Sector 1: Master Boot Record (0x7C00 - 0x7DFF)
; =============================================================================
start:
    cli                         ; Disable interrupts during CPU initialization
    mov [boot_drive], dl        ; Save boot drive ID passed by BIOS in DL

    ; Set up clean segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00              ; Stack safely below bootloader
    sti                         ; Re-enable interrupts

    call clear_screen

    ; Reset disk system (Drive DL)
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13

    ; Read 7 extended sectors (Sectors 2 through 8 = 3584 bytes) to 0x7E00
    mov ah, 0x02                ; BIOS read sector function
    mov al, 7                   ; Read 7 sectors (exactly matching 4KB disk size)
    mov ch, 0                   ; Cylinder 0
    mov cl, 2                   ; Sector 2 (1-based index)
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]        ; Drive ID
    
    ; Target buffer: ES:BX = 0x0000:0x7E00
    xor bx, bx
    mov es, bx
    mov bx, 0x7e00

    int 0x13
    jc disk_error

    ; Success message from Sector 1
    mov si, msg_sector_1
    call print_string_16

    ; Jump to extended loader in Sector 2
    jmp sector_2_start

disk_error:
    mov si, msg_disk_error
    call print_string_16
    cli
    hlt
    jmp $

; Sector 1 Data
boot_drive:      db 0
msg_sector_1:    db 'Heaplit OS Sector 1 Loaded (MBR 0x7C00)', 0x0D, 0x0A, 0
msg_disk_error:  db 'FATAL: Disk Read Failed!', 0x0D, 0x0A, 0

; Include Ring 1 (Memory) and Ring 2 (Console) in Sector 1
%include "../ring_1/memory.asm"
%include "../ring_2/console.asm"

; Pad Sector 1 to 510 bytes and append boot signature
times 510 - ($ - $$) db 0
dw 0xaa55

; =============================================================================
; Sectors 2 & 3: Extended Loader & Variable Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
; Include Ring 0 (Variable, Math, String) and Ring 1 (A20 Gate)
%include "variable.asm"
%include "math.asm"
%include "string.asm"
%include "../ring_1/a20.asm"

sector_2_start:
    mov si, msg_sector_2
    call print_string_16

    ; 1. Test Typed Variable System: Integer Creation & Addition
    mov di, var_num1
    mov al, type_int
    mov dx, 120
    call create_variable

    mov di, var_num2
    mov al, type_int
    mov dx, 35
    call create_variable

    ; Add var_num2 into var_num1 (120 + 35 = 155)
    mov di, var_num1
    mov si, var_num2
    call add_variables

    mov si, msg_calc_label
    call print_string_16
    mov di, var_num1
    call print_variable
    call print_newline

    ; 2. Test String Variable Creation & Printing
    mov di, var_title
    mov si, str_os_name
    call create_string_variable

    mov si, msg_str_label
    call print_string_16
    mov di, var_title
    call print_variable
    call print_newline

    ; 3. Test A20 Gate Activation
    call enable_a20
    test ax, ax
    jz .a20_failed

    mov si, msg_a20_success
    call print_string_16
    jmp .continue_boot

.a20_failed:
    mov si, msg_a20_error
    call print_string_16
    cli
    hlt
    jmp $

.continue_boot:
    ; Transfer control to Sector 4 (Interactive Console)
    jmp sector_4_start

msg_sector_2:     db 'Sectors 2-3 Executing (0x7E00): Initializing Subsystems...', 0x0D, 0x0A, 0
msg_calc_label:   db '  [Ring 0 Variable] 120 + 35 = ', 0
msg_str_label:    db '  [Ring 0 Variable] Loaded: ', 0
str_os_name:      db 'Heaplit OS Kernel Core v0.1', 0
msg_a20_success:  db '  [Ring 1 Hardware] A20 Gate: Verified Active.', 0x0D, 0x0A, 0
msg_a20_error:    db '  [Ring 1 Hardware] FATAL: A20 Gate Failed!', 0x0D, 0x0A, 0

; Variable buffers (6 bytes each)
var_num1:         times sizeof_variable db 0
var_num2:         times sizeof_variable db 0
var_title:        times sizeof_variable db 0

; Pad Sectors 2 & 3 to 1024 bytes (total 1536 bytes from base)
times (512 * 3) - ($ - $$) db 0

; =============================================================================
; Sector 4: Interactive Console & Input Trigger (0x8200 - 0x83FF)
; =============================================================================
; Include Ring 2 (Keyboard) in Sector 4
%include "../ring_2/keyboard.asm"

sector_4_start:
    ; Set video cursor position at Row 7, Col 0
    mov ah, 0x02
    mov bh, 0
    mov dh, 7
    mov dl, 0
    int 0x10

    mov si, msg_sector_4
    call print_string_16

    ; Display prompt asking user to proceed
    mov si, msg_prompt
    call print_string_16

    ; Read interactive line
    mov di, input_buffer
    mov cx, 48
    call read_line

    mov si, msg_cmd_received
    call print_string_16
    mov si, input_buffer
    call print_string_16
    call print_newline

    mov si, msg_switching_mode
    call print_string_16

    ; Advance to Sector 5: Protected Mode & Long Mode switch to Ring 3!
    jmp enter_protected_mode

msg_sector_4:       db 'Sector 4 Executing (0x8200): Ring 2 Console Online.', 0x0D, 0x0A, 0
msg_prompt:         db 'HeaplitOS> Press Enter to launch Long Mode & Ring 3: ', 0
msg_cmd_received:   db '  [Boot Command]: Launching -> ', 0
msg_switching_mode: db 'Transitioning: Real Mode -> 32-bit PM -> 64-bit LM -> Ring 3...', 0x0D, 0x0A, 0

input_buffer:       times 64 db 0

; Pad Sector 4 to 512 bytes (total 2048 bytes from base)
times (512 * 4) - ($ - $$) db 0

; =============================================================================
; Sectors 5+: 32-bit Protected Mode & 64-bit Long Mode Kernel Staging (Ring 0)
; =============================================================================
%include "gdt.asm"
%include "protected_mode.asm"
%include "paging.asm"
%include "long_mode.asm"

; Pad final kernel image to clean 4096-byte boundary (8 sectors total)
times 4096 - ($ - $$) db 0