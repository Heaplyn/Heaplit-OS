; rings/ring_0/ring_2/keyboard.asm
; Keyboard Input Services for Heaplit OS (16-bit Real Mode)
[bits 16]

; -----------------------------------------------------------------------------
; wait_for_key: Blocks execution until a key is pressed.
; Returns:
;   AL = ASCII character
;   AH = BIOS Scan Code
; -----------------------------------------------------------------------------
wait_for_key:
    mov ah, 0x00
    int 0x16
    ret

; -----------------------------------------------------------------------------
; check_key_available: Checks if a key is waiting in the buffer (Non-blocking).
; Returns:
;   ZF = 1 if NO key pressed
;   ZF = 0 if key is available (AL = ASCII, AH = Scan code)
; -----------------------------------------------------------------------------
check_key_available:
    mov ah, 0x01
    int 0x16
    ret

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
    pusha
    xor bx, bx                  ; Current character count

.input_loop:
    call wait_for_key           ; Wait for keystroke (AL = ASCII)

    cmp al, 0x0D                ; Enter / Return key pressed?
    je .done

    cmp al, 0x08                ; Backspace pressed?
    je .handle_backspace

    cmp bx, cx                  ; Is buffer full?
    jge .input_loop

    ; Normal printable character
    mov [di + bx], al
    inc bx

    ; Echo character to screen
    mov ah, 0x0E
    int 0x10
    jmp .input_loop

.handle_backspace:
    test bx, bx
    jz .input_loop              ; Nothing to delete at start of line
    dec bx

    ; Erase character visually: Backspace -> Space -> Backspace
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .input_loop

.done:
    mov byte [di + bx], 0       ; Append null terminator
    call print_newline
    popa
    ret
