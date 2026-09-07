; rings/ring_3/boot/stage2.asm
; =============================================================================
; Sectors 2 & 3: Extended Loader & Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
[bits 16]                               ; 16-bit Real Mode Execution

stage2_entry:
    mov si, msg_sector_2                ; Copy value from msg_sector_2 to si
    call print_string_16                ; Execute instruction

    ; 1. Test Ring 0 Dynamic Variable System: Integer Creation & Addition
    mov di, var_num1                    ; Copy value from var_num1 to di
    mov al, type_int                    ; Copy value from type_int to al
    mov dx, 120                         ; Copy value from 120 to dx
    call create_variable                ; Execute instruction

    mov di, var_num2                    ; Copy value from var_num2 to di
    mov al, type_int                    ; Copy value from type_int to al
    mov dx, 35                          ; Copy value from 35 to dx
    call create_variable                ; Execute instruction

    ; Add var_num2 into var_num1 (120 + 35 = 155)
    mov di, var_num1                    ; Copy value from var_num1 to di
    mov si, var_num2                    ; Copy value from var_num2 to si
    call add_variables                  ; Execute instruction

    mov si, msg_calc_label              ; Copy value from msg_calc_label to si
    call print_string_16                ; Execute instruction
    mov di, var_num1                    ; Copy value from var_num1 to di
    call print_variable                 ; Execute instruction
    call print_newline                  ; Execute instruction

    ; 2. Test Ring 0 String Variable Creation & Printing
    mov di, var_title                   ; Copy value from var_title to di
    mov si, str_os_name                 ; Copy value from str_os_name to si
    call create_string_variable         ; Execute instruction

    mov si, msg_str_label               ; Copy value from msg_str_label to si
    call print_string_16                ; Execute instruction
    mov di, var_title                   ; Copy value from var_title to di
    call print_variable                 ; Execute instruction
    call print_newline                  ; Execute instruction

    ; 3. Test Ring 1 Hardware A20 Gate Activation
    call enable_a20                     ; Execute instruction
    test ax, ax                         ; Execute instruction
    jz .a20_failed                      ; Jump to .a20_failed if condition 'z' is met

    mov si, msg_a20_success             ; Copy value from msg_a20_success to si
    call print_string_16                ; Execute instruction

    ; 16-bit BIOS Wait Delay (500ms = 0x0007A120 microseconds)
    mov ah, 0x86
    mov cx, 0x0007
    mov dx, 0xA120
    int 0x15

    jmp .continue_boot                  ; Unconditional jump to target label .continue_boot

.a20_failed:
    mov si, msg_a20_error               ; Copy value from msg_a20_error to si
    call print_string_16                ; Execute instruction
    cli                                 ; Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ; Halt CPU execution until next hardware interrupt
    jmp $                               ; Execute instruction

.continue_boot:
    ; Transfer control to Sector 4 (Interactive Console)
    jmp stage4_console_entry            ; Unconditional jump to target label stage4_console_entry

msg_sector_2:     db 'Sectors 2-3 Executing (0x7E00): Initializing Subsystems...', 0x0D, 0x0A, 0 ; Execute instruction
msg_calc_label:   db '  [Ring 0 Variable] 120 + 35 = ', 0 ; Execute instruction
msg_str_label:    db '  [Ring 0 Variable] Loaded: ', 0 ; Execute instruction
str_os_name:      db 'Heaplit OS Kernel Core v0.1', 0 ; Execute instruction
msg_a20_success:  db '  [Ring 1 Hardware] A20 Gate: Verified Active.', 0x0D, 0x0A, 0 ; Execute instruction
msg_a20_error:    db '  [Ring 1 Hardware] FATAL: A20 Gate Failed!', 0x0D, 0x0A, 0 ; Execute instruction

; Variable buffers (6 bytes each)
var_num1:         times sizeof_variable db 0 ; Execute instruction
var_num2:         times sizeof_variable db 0 ; Execute instruction
var_title:        times sizeof_variable db 0 ; Execute instruction
