; ring_0/console.asm

; Initialize Stack safely at 0x9000 (grows down, safely above 0x7C00)
[bits 16]
init_stack:
    cli                     ; Disable interrupts during setup
    xor ax, ax              ; AX = 0
    mov ss, ax              ; SS = 0
    mov sp, 0x9000          ; SP = 0x9000
    sti                     ; Re-enable interrupts
    ret
; Clear Screen by resetting to 80x25 text mode
clear_screen:
    pusha
    mov ah, 0x00            ; Set video mode
    mov al, 0x03            ; 80x25 color text
    int 0x10                ; Call BIOS video service
    popa
    ret
[bits 16]
print_string_16:
    pusha
    mov ah, 0x0e
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

[bits 16]
set_cursor:
    pusha
    mov ah, 0x02        ; Set cursor position
    int 0x10
    popa
    ret

[bits 32]
; VGA Text Mode Buffer: 0xB8000 (Row * 80 + Col) * 2
; Arguments: ESI = String Pointer, EDI = Video Memory Offset (e.g. 0xB8000)
print_string_32:
    pusha
    mov edx, 0x0f           ; White text on Black background attribute
.loop:
    mov al, byte [esi]
    test al, al
    jz .done
    mov byte [edi], al      ; Character byte
    mov byte [edi + 1], dl  ; Color attribute byte
    inc esi
    add edi, 2
    jmp .loop
.done:
    popa
    ret

