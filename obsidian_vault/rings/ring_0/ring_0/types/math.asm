; rings/ring_0/ring_0/math.asm
; Math and Arithmetic Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]

; -----------------------------------------------------------------------------
; int_to_string: Converts a 16-bit unsigned integer in AX to an ASCII string.
; Inputs:
;   AX = Integer value (0 - 65535)
;   DI = Destination buffer pointer (minimum 6 bytes)
; Outputs:
;   DI = Null-terminated ASCII string written to destination
; Preserved:
;   All registers except DI buffer contents
; -----------------------------------------------------------------------------
int_to_string:
    push ax
    push bx
    push cx
    push dx
    push di

    mov bx, 10                  ; Base 10 divisor
    xor cx, cx                  ; Digit counter

.divide_loop:
    xor dx, dx
    div bx                      ; AX = quotient, DX = remainder (0..9)
    push dx                     ; Save remainder digit on stack
    inc cx
    test ax, ax
    jnz .divide_loop

.write_digits:
    pop dx
    add dl, '0'                 ; Convert binary 0..9 to ASCII '0'..'9'
    mov [di], dl
    inc di
    loop .write_digits

    mov byte [di], 0            ; Null terminator
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------------------------------
; string_to_int: Parses a null-terminated ASCII decimal string to 16-bit integer.
; Inputs:
;   SI = Pointer to null-terminated ASCII string
; Outputs:
;   AX = Parsed 16-bit integer
; Preserved:
;   BX, CX, DX, SI, DI
; -----------------------------------------------------------------------------
string_to_int:
    push bx
    push cx
    push dx
    push si

    xor ax, ax                  ; Result accumulator
    mov bx, 10                  ; Base 10 multiplier

.parse_loop:
    movzx cx, byte [si]
    test cl, cl
    jz .done
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done

    sub cl, '0'                 ; Convert ASCII char to binary number
    mul bx                      ; AX = AX * 10
    add ax, cx                  ; AX = AX + digit
    inc si
    jmp .parse_loop

.done:
    pop si
    pop dx
    pop cx
    pop bx
    ret

; -----------------------------------------------------------------------------
; abs16: Computes the absolute value of a signed 16-bit integer in AX.
; Inputs:
;   AX = Signed 16-bit integer
; Outputs:
;   AX = Absolute value
; -----------------------------------------------------------------------------
abs16:
    push dx
    cwd                         ; Sign-extend AX into DX (0 if positive, 0xFFFF if negative)
    xor ax, dx
    sub ax, dx
    pop dx
    ret

; -----------------------------------------------------------------------------
; min16: Returns the minimum of two 16-bit integers in AX and BX.
; Inputs: AX, BX
; Outputs: AX = min(AX, BX)
; -----------------------------------------------------------------------------
min16:
    cmp ax, bx
    jle .done
    mov ax, bx
.done:
    ret

; -----------------------------------------------------------------------------
; max16: Returns the maximum of two 16-bit integers in AX and BX.
; Inputs: AX, BX
; Outputs: AX = max(AX, BX)
; -----------------------------------------------------------------------------
max16:
    cmp ax, bx
    jge .done
    mov ax, bx
.done:
    ret
