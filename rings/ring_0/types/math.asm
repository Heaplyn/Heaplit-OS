; rings/ring_0/math.asm
; Math and Arithmetic Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

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
    push ax                             ;Push AX register onto memory stack
    push bx                             ;Push BX register onto memory stack
    push cx                             ;Push CX register onto memory stack
    push dx                             ;Push DX register onto memory stack
    push di                             ;Push DI register onto memory stack

    mov bx, 10                          ;Base 10 divisor
    xor cx, cx                          ;Digit counter

.divide_loop:
    xor dx, dx                          ;Zero out DX register
    div bx                              ;AX = quotient, DX = remainder (0..9)
    push dx                             ;Save remainder digit on stack
    inc cx                              ;Increment cx by 1
    test ax, ax                         ; Test accumulator register for zero / error status
    jnz .divide_loop                    ; Branch to '.divide_loop' if Zero Flag is clear (ZF=0)

.write_digits:
    pop dx                              ;Pop top stack value into DX register
    add dl, '0'                         ;Convert binary 0..9 to ASCII '0'..'9'
    mov [di], dl                        ; Set [di] = dl
    inc di                              ;Increment di by 1
    loop .write_digits                  ; Execute hardware step

    mov byte [di], 0                    ;Null terminator
    pop di                              ;Pop top stack value into DI register
    pop dx                              ;Pop top stack value into DX register
    pop cx                              ;Pop top stack value into CX register
    pop bx                              ;Pop top stack value into BX register
    pop ax                              ;Pop top stack value into AX register
    ret                                 ;Return control to caller instruction pointer

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
    push bx                             ;Push BX register onto memory stack
    push cx                             ;Push CX register onto memory stack
    push dx                             ;Push DX register onto memory stack
    push si                             ;Push SI register onto memory stack

    xor ax, ax                          ;Result accumulator
    mov bx, 10                          ;Base 10 multiplier

.parse_loop:
    movzx cx, byte [si]                 ; Execute hardware step
    test cl, cl                         ; Execute hardware step
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    cmp cl, '0'                         ; Execute hardware step
    jb .done                            ; Execute hardware step
    cmp cl, '9'                         ; Execute hardware step
    ja .done                            ; Execute hardware step

    sub cl, '0'                         ;Convert ASCII char to binary number
    mul bx                              ;AX = AX * 10
    add ax, cx                          ;AX = AX + digit
    inc si                              ;Increment si by 1
    jmp .parse_loop                     ;Unconditional jump to target label .parse_loop

.done:
    pop si                              ;Pop top stack value into SI register
    pop dx                              ;Pop top stack value into DX register
    pop cx                              ;Pop top stack value into CX register
    pop bx                              ;Pop top stack value into BX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; abs16: Computes the absolute value of a signed 16-bit integer in AX.
; Inputs:
;   AX = Signed 16-bit integer
; Outputs:
;   AX = Absolute value
; -----------------------------------------------------------------------------
abs16:
    push dx                             ;Push DX register onto memory stack
    cwd                                 ;Sign-extend AX into DX (0 if positive, 0xFFFF if negative)
    xor ax, dx                          ; Clear AX register to 0
    sub ax, dx                          ; Execute hardware step
    pop dx                              ;Pop top stack value into DX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; min16: Returns the minimum of two 16-bit integers in AX and BX.
; Inputs: AX, BX
; Outputs: AX = min(AX, BX)
; -----------------------------------------------------------------------------
min16:
    cmp ax, bx                          ; Execute hardware step
    jle .done                           ; Execute hardware step
    mov ax, bx                          ; Set ax = bx
.done:
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; max16: Returns the maximum of two 16-bit integers in AX and BX.
; Inputs: AX, BX
; Outputs: AX = max(AX, BX)
; -----------------------------------------------------------------------------
max16:
    cmp ax, bx                          ; Execute hardware step
    jge .done                           ; Branch to '.done' if Greater or Equal
    mov ax, bx                          ; Set ax = bx
.done:
    ret                                 ;Return control to caller instruction pointer
