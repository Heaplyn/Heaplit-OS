; rings/ring_0/ring_2/console.asm
; Console Display Utilities for Heaplit OS

; -----------------------------------------------------------------------------
; 16-bit Real Mode Console Functions
; -----------------------------------------------------------------------------
[bits 16]

; Initialize Stack safely at 0x9000 (grows down, safely above 0x7C00)
init_stack:
    cli                         ; Disable interrupts during setup
    xor ax, ax                  ; AX = 0
    mov ss, ax                  ; SS = 0
    mov sp, 0x9000              ; SP = 0x9000
    sti                         ; Re-enable interrupts
    ret

; Clear Screen by resetting to 80x25 text mode
clear_screen:
    pusha
    mov ah, 0x00                ; Set video mode
    mov al, 0x03                ; 80x25 color text
    int 0x10                    ; Call BIOS video service
    popa
    ret

; Print single character in AL
print_char:
    pusha
    mov ah, 0x0E
    int 0x10
    popa
    ret

; Print carriage return + newline
print_newline:
    push ax
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    pop ax
    ret

; Print null-terminated string at SI
print_string_16:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Set cursor position (DH = row, DL = col, BH = page)
set_cursor:
    pusha
    mov ah, 0x02                ; Set cursor position
    int 0x10
    popa
    ret

; Print byte in AL as 2 hexadecimal characters (e.g. 0x7E -> "7E")
print_hex_byte:
    push ax
    push bx
    mov bl, al
    shr al, 4                   ; High nibble
    call .print_nibble
    mov al, bl                  ; Low nibble
    and al, 0x0F
    call .print_nibble
    pop bx
    pop ax
    ret

.print_nibble:
    add al, '0'
    cmp al, '9'
    jle .ok
    add al, 7                   ; Convert to 'A'..'F'
.ok:
    mov ah, 0x0E
    int 0x10
    ret

; Print word in AX as 4 hexadecimal characters
print_hex_word:
    push ax
    xchg al, ah
    call print_hex_byte         ; Print high byte
    xchg al, ah
    call print_hex_byte         ; Print low byte
    pop ax
    ret

; -----------------------------------------------------------------------------
; 32-bit Protected Mode Console Functions
; -----------------------------------------------------------------------------
[bits 32]
; VGA Text Mode Buffer: 0xB8000 (Row * 80 + Col) * 2
; Arguments: ESI = String Pointer, EDI = Video Memory Offset (e.g. 0xB8000)
print_string_32:
    pusha
    mov edx, 0x0f               ; White text on Black background attribute
.loop:
    mov al, byte [esi]
    test al, al
    jz .done
    mov byte [edi], al          ; Character byte
    mov byte [edi + 1], dl      ; Color attribute byte
    inc esi
    add edi, 2
    jmp .loop
.done:
    popa
    ret
