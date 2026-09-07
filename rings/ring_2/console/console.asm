; rings/ring_0/ring_2/console.asm
; Console Display Utilities for Heaplit OS

; -----------------------------------------------------------------------------
; 16-bit Real Mode Console Functions
; -----------------------------------------------------------------------------
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

; Initialize Stack safely at 0x9000 (grows down, safely above 0x7C00)
init_stack:
    cli                                 ;Disable interrupts during setup
    xor ax, ax                          ;AX = 0
    mov ss, ax                          ;SS = 0
    mov sp, 0x9000                      ;SP = 0x9000
    sti                                 ;Re-enable interrupts
    ret                                 ;Return control to caller instruction pointer

; Clear Screen by resetting to 80x25 text mode
clear_screen:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x00                        ;Set video mode
    mov al, 0x03                        ;80x25 color text
    int 0x10                            ;Call BIOS video service
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer

; Print single character in AL
print_char:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x0E                        ; Set BIOS function 0x0E (Teletype Output ASCII character)
    int 0x10                            ; Trigger BIOS Video Services interrupt
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer

; Print carriage return + newline
print_newline:
    push ax                             ;Push AX register onto memory stack
    mov ah, 0x0E                        ; Set BIOS function 0x0E (Teletype Output ASCII character)
    mov al, 0x0D                        ; Set al = 0x0D
    int 0x10                            ; Trigger BIOS Video Services interrupt
    mov al, 0x0A                        ; Set al = 0x0A
    int 0x10                            ; Trigger BIOS Video Services interrupt
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; Print null-terminated string at SI
print_string_16:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x0E                        ; Set BIOS function 0x0E (Teletype Output ASCII character)
.loop:
    lodsb                               ; Execute hardware step
    test al, al                         ; Test AL byte for zero (null-terminator)
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    int 0x10                            ; Trigger BIOS Video Services interrupt
    jmp .loop                           ;Unconditional jump to target label .loop
.done:
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer

; Set cursor position (DH = row, DL = col, BH = page)
set_cursor:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov ah, 0x02                        ;Set cursor position
    int 0x10                            ; Trigger BIOS Video Services interrupt
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer

; Print byte in AL as 2 hexadecimal characters (e.g. 0x7E -> "7E")
print_hex_byte:
    push ax                             ;Push AX register onto memory stack
    push bx                             ;Push BX register onto memory stack
    mov bl, al                          ; Set bl = al
    shr al, 4                           ;High nibble
    call .print_nibble                  ; Call helper function '.print_nibble'
    mov al, bl                          ;Low nibble
    and al, 0x0F                        ; Execute hardware step
    call .print_nibble                  ; Call helper function '.print_nibble'
    pop bx                              ;Pop top stack value into BX register
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

.print_nibble:
    add al, '0'                         ; Execute hardware step
    cmp al, '9'                         ; Execute hardware step
    jle .ok                             ; Execute hardware step
    add al, 7                           ;Convert to 'A'..'F'
.ok:
    mov ah, 0x0E                        ; Set BIOS function 0x0E (Teletype Output ASCII character)
    int 0x10                            ; Trigger BIOS Video Services interrupt
    ret                                 ;Return control to caller instruction pointer

; Print word in AX as 4 hexadecimal characters
print_hex_word:
    push ax                             ;Push AX register onto memory stack
    xchg al, ah                         ; Execute hardware step
    call print_hex_byte                 ;Print high byte
    xchg al, ah                         ; Execute hardware step
    call print_hex_byte                 ;Print low byte
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; 32-bit Protected Mode Console Functions
; -----------------------------------------------------------------------------
[bits 32]                               ; Set assembler target mode to 32-bit Protected Mode
; VGA Text Mode Buffer: 0xB8000 (Row * 80 + Col) * 2
; Arguments: ESI = String Pointer, EDI = Video Memory Offset (e.g. 0xB8000)
print_string_32:
    pusha                               ; Push all 16-bit general purpose registers (AX, CX, DX, BX, SP, BP, SI, DI) onto stack
    mov edx, 0x0f                       ;White text on Black background attribute
.loop:
    mov al, byte [esi]                  ; Set al = byte [esi]
    test al, al                         ; Test AL byte for zero (null-terminator)
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    mov byte [edi], al                  ;Character byte
    mov byte [edi + 1], dl              ;Color attribute byte
    inc esi                             ;Increment esi by 1
    add edi, 2                          ; Execute hardware step
    jmp .loop                           ;Unconditional jump to target label .loop
.done:
    popa                                ; Restore all 16-bit general purpose registers from stack
    ret                                 ;Return control to caller instruction pointer
