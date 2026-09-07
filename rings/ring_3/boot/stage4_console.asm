; rings/ring_3/boot/stage4_console.asm
; =============================================================================
; Sector 4: Interactive Console & Input Trigger (0x8200 - 0x83FF)
; =============================================================================
[bits 16]                               ;16-bit Real Mode Execution

stage4_console_entry:
    ; Set video cursor position at Row 7, Col 0
    mov ah, 0x02                        ; Set BIOS function 0x02 (Set Video Cursor Position)
    mov bh, 0                           ; Set bh = 0
    mov dh, 7                           ; Set dh = 7
    mov dl, 0                           ; Set dl = 0
    int 0x10                            ; Trigger BIOS Video Services interrupt

    mov si, msg_sector_4                ; Load memory address of string 'msg_sector_4' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    ; Display prompt asking user to proceed
    mov si, msg_prompt                  ; Load memory address of string 'msg_prompt' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'

    ; Read interactive line with Backspace handling (Ring 2 keyboard service)
    mov di, input_buffer                ; Load memory address of buffer 'input_buffer' into DI destination register
    mov cx, 48                          ; Set cx = 48
    call read_line                      ; Call subroutine 'read_line'

    call sleep_500ms_16                 ;0.5s visual diagnostic sleep
    mov si, msg_cmd_received            ; Load memory address of string 'msg_cmd_received' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    mov si, input_buffer                ; Load memory address of string 'input_buffer' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    call print_newline                  ; Call subroutine 'print_newline'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    mov si, msg_switching_mode          ; Load memory address of string 'msg_switching_mode' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    call sleep_500ms_16                 ;0.5s visual diagnostic sleep

    ; Advance to Protected Mode & Long Mode switch
    jmp enter_protected_mode            ;Unconditional jump to target label enter_protected_mode

msg_sector_4:       db 'Sector 4 Executing (0x8200): Ring 2 Console Online.', 0x0D, 0x0A, 0 ; ASCII text string for Sector 4 console banner
msg_prompt:         db 'HeaplitOS> Press Enter to launch Long Mode & Ring 3: ', 0 ; ASCII text string for user command prompt
msg_cmd_received:   db '  [Boot Command]: Launching -> ', 0 ; ASCII text string confirming command execution
msg_switching_mode: db 'Transitioning: Real Mode -> 32-bit PM -> 64-bit LM -> Ring 3...', 0x0D, 0x0A, 0 ; ASCII text string logging CPU mode transition

input_buffer:       times 64 db 0       ; Reserve 64 zeroed bytes in RAM for user command input
