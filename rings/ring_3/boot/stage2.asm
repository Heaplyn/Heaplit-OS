; rings/ring_3/boot/stage2.asm
; =============================================================================
; Sectors 2 & 3: Extended Loader & Diagnostics (0x7E00 - 0x81FF)
; =============================================================================
[bits 16]                               ;16-bit Real Mode Execution

stage2_entry:
    mov si, msg_sector_2                ; Load memory address of string 'msg_sector_2' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    ; 1. Test Ring 0 Dynamic Variable System: Integer Creation & Addition
    mov di, var_num1                    ; Load memory address of buffer 'var_num1' into DI destination register
    mov al, type_int                    ; Set al = type_int
    mov dx, 120                         ; Set dx = 120
    call create_variable                ; Call subroutine 'create_variable'

    mov di, var_num2                    ; Load memory address of buffer 'var_num2' into DI destination register
    mov al, type_int                    ; Set al = type_int
    mov dx, 35                          ; Set dx = 35
    call create_variable                ; Call subroutine 'create_variable'

    ; Add var_num2 into var_num1 (120 + 35 = 155)
    mov di, var_num1                    ; Load memory address of buffer 'var_num1' into DI destination register
    mov si, var_num2                    ; Load memory address of string 'var_num2' into SI argument register
    call add_variables                  ; Call subroutine 'add_variables'

    mov si, msg_calc_label              ; Load memory address of string 'msg_calc_label' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    mov di, var_num1                    ; Load memory address of buffer 'var_num1' into DI destination register
    call print_variable                 ; Call subroutine 'print_variable'
    call print_newline                  ; Call subroutine 'print_newline'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    ; 2. Test Ring 0 String Variable Creation & Printing
    mov di, var_title                   ; Load memory address of buffer 'var_title' into DI destination register
    mov si, str_os_name                 ; Load memory address of string 'str_os_name' into SI argument register
    call create_string_variable         ; Call subroutine 'create_string_variable'

    mov si, msg_str_label               ; Load memory address of string 'msg_str_label' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    mov di, var_title                   ; Load memory address of buffer 'var_title' into DI destination register
    call print_variable                 ; Call subroutine 'print_variable'
    call print_newline                  ; Call subroutine 'print_newline'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    ; 3. Test Ring 1 Hardware A20 Gate Activation
    call enable_a20                     ; Call subroutine 'enable_a20'
    test ax, ax                         ; Test accumulator register for zero / error status
    jz .a20_failed                      ; Branch to '.a20_failed' if Zero Flag is set (ZF=1)

    mov si, msg_a20_success             ; Load memory address of string 'msg_a20_success' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    jmp .continue_boot                  ;Unconditional jump to target label .continue_boot

.a20_failed:
    mov si, msg_a20_error               ; Load memory address of string 'msg_a20_error' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ;Halt CPU execution until next hardware interrupt
    jmp $                               ; Infinite spin loop to halt CPU on fatal error

.continue_boot:
    ; Transfer control to Sector 4 (Interactive Console)
    jmp stage4_console_entry            ;Unconditional jump to target label stage4_console_entry

sleep_500ms_16:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x86                        ; Set BIOS function 0x86 (Microsecond Sleep Delay)
    mov cx, 0x0007                      ;500,000 microseconds = 0x0007A120
    mov dx, 0xA120                      ; Set dx = 0xA120
    int 0x15                            ; Trigger BIOS System Services / Wait interrupt
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ; Return control to caller instruction pointer

msg_sector_2:     db 'Sectors 2-3 Executing (0x7E00): Initializing Subsystems...', 0x0D, 0x0A, 0 ; Execute hardware step
msg_calc_label:   db '  [Ring 0 Variable] 120 + 35 = ', 0 ; Execute hardware step
msg_str_label:    db '  [Ring 0 Variable] Loaded: ', 0 ; Execute hardware step
str_os_name:      db 'Heaplit OS Kernel Core v0.1', 0 ; Execute hardware step
msg_a20_success:  db '  [Ring 1 Hardware] A20 Gate: Verified Active.', 0x0D, 0x0A, 0 ; Execute hardware step
msg_a20_error:    db '  [Ring 1 Hardware] FATAL: A20 Gate Failed!', 0x0D, 0x0A, 0 ; Execute hardware step

; Variable buffers (6 bytes each)
var_num1:         times sizeof_variable db 0 ; Execute hardware step
var_num2:         times sizeof_variable db 0 ; Execute hardware step
var_title:        times sizeof_variable db 0 ; Execute hardware step
