; rings/ring_3/boot/stage4_console.asm
; =============================================================================
; Sector 4: Interactive Console & Input Trigger (0x8200 - 0x83FF)
; =============================================================================
[bits 16]

stage4_console_entry:
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

    ; Read interactive line with Backspace handling (Ring 2 keyboard service)
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

    ; Advance to Protected Mode & Long Mode switch
    jmp enter_protected_mode

msg_sector_4:       db 'Sector 4 Executing (0x8200): Ring 2 Console Online.', 0x0D, 0x0A, 0
msg_prompt:         db 'HeaplitOS> Press Enter to launch Long Mode & Ring 3: ', 0
msg_cmd_received:   db '  [Boot Command]: Launching -> ', 0
msg_switching_mode: db 'Transitioning: Real Mode -> 32-bit PM -> 64-bit LM -> Ring 3...', 0x0D, 0x0A, 0

input_buffer:       times 64 db 0
