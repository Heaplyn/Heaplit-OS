; =============================================================================
; Heaplit OS - Staged Bare-Metal Bootloader
; Architecture: 16-bit Real Mode -> Staged Protected Mode
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

    ; Read 4 extended sectors (Sectors 2, 3, 4, 5) from disk into RAM at 0x7E00
    mov ah, 0x02                ; BIOS read sector function
    mov al, 4                   ; Number of sectors to read (2048 bytes total)
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

; Include core console and memory routines in Sector 1
%include "ring_1/memory.asm"
%include "ring_2/console.asm"

; Pad Sector 1 to 510 bytes and append boot signature
times 510 - ($ - $$) db 0
dw 0xaa55

; =============================================================================
; Sectors 2 & 3: Extended Loader & Variable Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
; Include variable, math, string, and A20 libraries
%include "ring_0/variable.asm"
%include "ring_0/math.asm"
%include "ring_0/string.asm"
%include "ring_1/a20.asm"

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
msg_calc_label:   db '  [Dynamic Variable] 120 + 35 = ', 0
msg_str_label:    db '  [String Variable] Loaded: ', 0
str_os_name:      db 'Heaplit OS Kernel Core v0.1', 0
msg_a20_success:  db '  [Hardware Line] A20 Gate: Verified Active.', 0x0D, 0x0A, 0
msg_a20_error:    db '  [Hardware Line] FATAL: A20 Gate Failed!', 0x0D, 0x0A, 0

; Variable buffers (6 bytes each)
var_num1:         times sizeof_variable db 0
var_num2:         times sizeof_variable db 0
var_title:        times sizeof_variable db 0

; Pad Sectors 2 & 3 to 1024 bytes (total 1536 bytes from base)
times (512 * 3) - ($ - $$) db 0

; =============================================================================
; Sector 4: Interactive Console & Keyboard Driver (0x8200 - 0x83FF)
; =============================================================================
; Include keyboard routines in Sector 4
%include "ring_2/keyboard.asm"

sector_4_start:
    ; Set video cursor position at Row 7, Col 0
    mov ah, 0x02
    mov bh, 0
    mov dh, 7
    mov dl, 0
    int 0x10

    mov si, msg_sector_4
    call print_string_16

    ; Display interactive input prompt
    mov si, msg_prompt
    call print_string_16

    ; Read line with in-place backspace editing
    mov di, input_buffer
    mov cx, 48                  ; Max length
    call read_line

    ; Echo received command
    mov si, msg_cmd_received
    call print_string_16
    mov si, input_buffer
    call print_string_16
    call print_newline

    mov si, msg_kernel_ready
    call print_string_16

    ; Enter low-power idle halt loop
    cli
    hlt
    jmp $

msg_sector_4:     db 'Sector 4 Executing (0x8200): Console & Drivers Online.', 0x0D, 0x0A, 0
msg_prompt:       db 'HeaplitOS> Type a test command: ', 0
msg_cmd_received: db '  [Echo]: You typed -> ', 0
msg_kernel_ready: db 'System Staged. Kernel Ready for Protected Mode.', 0x0D, 0x0A, 0

input_buffer:     times 64 db 0

; Pad Sector 4 to 512 bytes (total 2048 bytes from base)
times (512 * 4) - ($ - $$) db 0

; =============================================================================
; Sector 5: Kernel Staging & 32-bit Protected Mode Bootstrap (0x8400 - 0x85FF)
; =============================================================================
sector_5_start:
    nop
    ret

; Pad Sector 5 to 512 bytes (total 2560 bytes from base)
times (512 * 5) - ($ - $$) db 0