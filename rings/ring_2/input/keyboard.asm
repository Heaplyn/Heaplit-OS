; rings/ring_0/ring_2/keyboard.asm
; Keyboard Input Services for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

; -----------------------------------------------------------------------------
; wait_for_key: Blocks execution until a key is pressed.
; Returns:
;   AL = ASCII character
;   AH = BIOS Scan Code
; -----------------------------------------------------------------------------
wait_for_key:
    mov ah, 0x00                        ; Set ah = 0x00
    int 0x16                            ; Trigger BIOS Keyboard Services interrupt
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; check_key_available: Checks if a key is waiting in the buffer (Non-blocking).
; Returns:
;   ZF = 1 if NO key pressed
;   ZF = 0 if key is available (AL = ASCII, AH = Scan code)
; -----------------------------------------------------------------------------
check_key_available:
    mov ah, 0x01                        ; Set ah = 0x01
    int 0x16                            ; Trigger BIOS Keyboard Services interrupt
    ret                                 ;Return control to caller instruction pointer

; ------------------------------------------------------------
; get_key - Wait for a keypress and return the ASCII character
; Output: AL = ASCII character, AH = Scancode
; ------------------------------------------------------------
get_key:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x00                        ;BIOS function: Wait for key
    int 0x16                            ;BIOS Keyboard Service
    mov [.key_ascii], al                ; Move value into target register/memory
    mov [.key_scancode], ah             ; Move value into target register/memory
    popa                                ; Restore all 16-bit general purpose registers from stack
    mov al, [.key_ascii]                ; Move value into target register/memory
    mov ah, [.key_scancode]             ; Move value into target register/memory
    ret                                 ; Return control to caller instruction pointer
.key_ascii: db 0                        ; Execute hardware step
.key_scancode: db 0                     ; Execute hardware step

; ------------------------------------------------------------
; has_key - Check if a key is pressed (non-blocking)
; Output: ZF=0 if key pressed, AL=ASCII, AH=Scancode
;         ZF=1 if no key pressed
; ------------------------------------------------------------
has_key:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x01                        ;BIOS function: Check for key
    int 0x16                            ; Trigger BIOS Keyboard Services interrupt
    jz .no_key                          ;ZF=1 means no key
    ; Key is waiting. Get it so the buffer clears (we can discard it or keep it)
    mov ah, 0x00                        ; Set ah = 0x00
    int 0x16                            ; Trigger BIOS Keyboard Services interrupt
    mov [.key_ascii], al                ; Move value into target register/memory
    mov [.key_scancode], ah             ; Move value into target register/memory
    popa                                ; Restore all 16-bit general purpose registers from stack
    mov al, [.key_ascii]                ; Move value into target register/memory
    mov ah, [.key_scancode]             ; Move value into target register/memory
    test ax, ax                         ;Set ZF=0 (since key is present)
    ret                                 ; Return control to caller instruction pointer
.no_key:
    popa                                ; Restore all 16-bit general purpose registers from stack
    xor ax, ax                          ;AX = 0
    test ax, ax                         ;Set ZF=1
    ret                                 ; Return control to caller instruction pointer
.key_ascii: db 0                        ; Execute hardware step
.key_scancode: db 0                     ; Execute hardware step

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
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    xor bx, bx                          ;Current character count

.input_loop:
    call wait_for_key                   ;Wait for keystroke (AL = ASCII)

    cmp al, 0x0D                        ;Enter / Return key pressed?
    je .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)

    cmp al, 0x08                        ;Backspace pressed?
    je .handle_backspace                ; Branch to '.handle_backspace' if Zero Flag is set (ZF=1)

    cmp bx, cx                          ;Is buffer full?
    jge .input_loop                     ; Branch to '.input_loop' if Greater or Equal

    ; Normal printable character
    mov [di + bx], al                   ; Set [di + bx] = al
    inc bx                              ;Increment bx by 1

    ; Echo character to screen
    mov ah, 0x0E                        ; Set BIOS function 0x0E (Teletype Output ASCII character)
    int 0x10                            ; Trigger BIOS Video Services interrupt
    jmp .input_loop                     ;Unconditional jump to target label .input_loop

.handle_backspace:
    test bx, bx                         ; Test base register for zero
    jz .input_loop                      ;Nothing to delete at start of line
    dec bx                              ;Decrement bx by 1

    ; Erase character visually: Backspace -> Space -> Backspace
    mov ah, 0x0E                        ; Set BIOS function 0x0E (Teletype Output ASCII character)
    mov al, 0x08                        ; Set al = 0x08
    int 0x10                            ; Trigger BIOS Video Services interrupt
    mov al, ' '                         ; Move value into target register/memory
    int 0x10                            ; Trigger BIOS Video Services interrupt
    mov al, 0x08                        ; Set al = 0x08
    int 0x10                            ; Trigger BIOS Video Services interrupt
    jmp .input_loop                     ;Unconditional jump to target label .input_loop

.done:
    mov byte [di + bx], 0               ;Append null terminator
    call print_newline                  ; Call subroutine 'print_newline'
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer
