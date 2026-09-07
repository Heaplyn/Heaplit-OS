; rings/ring_3/boot/stage2.asm
; =============================================================================
; Sectors 2 & 3: Extended Loader & Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
[bits 16]

stage2_entry:
    mov si, msg_sector_2
    call print_string_16

    ; 1. Test Ring 0 Dynamic Variable System: Integer Creation & Addition
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

    ; 2. Test Ring 0 String Variable Creation & Printing
    mov di, var_title
    mov si, str_os_name
    call create_string_variable

    mov si, msg_str_label
    call print_string_16
    mov di, var_title
    call print_variable
    call print_newline

    ; 3. Test Ring 1 Hardware A20 Gate Activation
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
    jmp stage4_console_entry

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
