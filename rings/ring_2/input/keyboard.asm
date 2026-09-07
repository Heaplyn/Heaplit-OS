; rings/ring_0/ring_2/keyboard.asm
; Keyboard Input Services for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Execute instruction

; -----------------------------------------------------------------------------
; wait_for_key: Blocks execution until a key is pressed.
; Returns:
;   AL = ASCII character
;   AH = BIOS Scan Code
; -----------------------------------------------------------------------------
wait_for_key:
    mov ah, 0x00                        ; Copy value from 0x00 to ah
    int 0x16                            ; Execute instruction
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; check_key_available: Checks if a key is waiting in the buffer (Non-blocking).
; Returns:
;   ZF = 1 if NO key pressed
;   ZF = 0 if key is available (AL = ASCII, AH = Scan code)
; -----------------------------------------------------------------------------
check_key_available:
    mov ah, 0x01                        ; Copy value from 0x01 to ah
    int 0x16                            ; Execute instruction
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; read_line: Interactive line editor reading into buffer at DI.
; Handles Backspace (0x08), echoes chars, appends null terminator.
; Inputs:
;   DI = Destination buffer pointer
;   CX = Maximum buffer capacity in bytes
; Preserved:
;   All general purpose registers
; -----------------------------------------------------------------------------
read_line:
    pusha                               ; Execute instruction
    xor bx, bx                          ; Current character count

.input_loop:
    call wait_for_key                   ; Wait for keystroke (AL = ASCII)

    cmp al, 0x0D                        ; Enter / Return key pressed?
    je .done                            ; Jump to .done if condition 'e' is met

    cmp al, 0x08                        ; Backspace pressed?
    je .handle_backspace                ; Jump to .handle_backspace if condition 'e' is met

    cmp bx, cx                          ; Is buffer full?
    jge .input_loop                     ; Jump to .input_loop if condition 'ge' is met

    ; Normal printable character
    mov [di + bx], al                   ; Copy value from al to [di + bx]
    inc bx                              ; Increment bx by 1

    ; Echo character to screen
    mov ah, 0x0E                        ; Copy value from 0x0E to ah
    int 0x10                            ; Execute instruction
    jmp .input_loop                     ; Unconditional jump to target label .input_loop

.handle_backspace:
    test bx, bx                         ; Execute instruction
    jz .input_loop                      ; Nothing to delete at start of line
    dec bx                              ; Decrement bx by 1

    ; Erase character visually: Backspace -> Space -> Backspace
    mov ah, 0x0E                        ; Copy value from 0x0E to ah
    mov al, 0x08                        ; Copy value from 0x08 to al
    int 0x10                            ; Execute instruction
    mov al, ' '                         ; Execute instruction
    int 0x10                            ; Execute instruction
    mov al, 0x08                        ; Copy value from 0x08 to al
    int 0x10                            ; Execute instruction
    jmp .input_loop                     ; Unconditional jump to target label .input_loop

.done:
    mov byte [di + bx], 0               ; Append null terminator
    call print_newline                  ; Execute instruction
    popa                                ; Execute instruction
    ret                                 ; Return control to caller instruction pointer
