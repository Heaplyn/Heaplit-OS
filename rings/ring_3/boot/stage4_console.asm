; rings/ring_3/boot/stage4_console.asm
; =============================================================================
; Sector 4: Interactive Console & Input Trigger (0x8200 - 0x83FF)
; =============================================================================
[bits 16]                               ; 16-bit Real Mode Execution

stage4_console_entry:
    ; Set video cursor position at Row 7, Col 0
    mov ah, 0x02                        ; Copy value from 0x02 to ah
    mov bh, 0                           ; Copy value from 0 to bh
    mov dh, 7                           ; Copy value from 7 to dh
    mov dl, 0                           ; Copy value from 0 to dl
    int 0x10                            ; Execute instruction

    mov si, msg_sector_4                ; Copy value from msg_sector_4 to si
    call print_string_16                ; Execute instruction
    call sleep_500ms_16                 ; 0.5s visual diagnostic sleep

    ; Display prompt asking user to proceed
    mov si, msg_prompt                  ; Copy value from msg_prompt to si
    call print_string_16                ; Execute instruction

    ; Read interactive line with Backspace handling (Ring 2 keyboard service)
    mov di, input_buffer                ; Copy value from input_buffer to di
    mov cx, 48                          ; Copy value from 48 to cx
    call read_line                      ; Execute instruction

    call sleep_500ms_16                 ; 0.5s visual diagnostic sleep
    mov si, msg_cmd_received            ; Copy value from msg_cmd_received to si
    call print_string_16                ; Execute instruction
    mov si, input_buffer                ; Copy value from input_buffer to si
    call print_string_16                ; Execute instruction
    call print_newline                  ; Execute instruction
    call sleep_500ms_16                 ; 0.5s visual diagnostic sleep

    mov si, msg_switching_mode          ; Copy value from msg_switching_mode to si
    call print_string_16                ; Execute instruction
    call sleep_500ms_16                 ; 0.5s visual diagnostic sleep

    ; Advance to Protected Mode & Long Mode switch
    jmp enter_protected_mode            ; Unconditional jump to target label enter_protected_mode

msg_sector_4:       db 'Sector 4 Executing (0x8200): Ring 2 Console Online.', 0x0D, 0x0A, 0 ; Execute instruction
msg_prompt:         db 'HeaplitOS> Press Enter to launch Long Mode & Ring 3: ', 0 ; Execute instruction
msg_cmd_received:   db '  [Boot Command]: Launching -> ', 0 ; Execute instruction
msg_switching_mode: db 'Transitioning: Real Mode -> 32-bit PM -> 64-bit LM -> Ring 3...', 0x0D, 0x0A, 0 ; Execute instruction

input_buffer:       times 64 db 0       ; Execute instruction
