; rings/ring_0/string.asm
; String Manipulation Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

; -----------------------------------------------------------------------------
; strlen16: Measures length of a null-terminated ASCII string.
; Inputs:
;   SI = Pointer to null-terminated ASCII string
; Outputs:
;   CX = Length in bytes (excluding null terminator)
; Preserved:
;   SI, AX, BX, DX, DI
; -----------------------------------------------------------------------------
strlen16:
    push si                             ;Push SI register onto memory stack
    xor cx, cx                          ;Zero out CX register
.loop:
    cmp byte [si], 0                    ; Execute hardware step
    je .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    inc si                              ;Increment si by 1
    inc cx                              ;Increment cx by 1
    jmp .loop                           ;Unconditional jump to target label .loop
.done:
    pop si                              ;Pop top stack value into SI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; strcmp16: Compares two null-terminated ASCII strings.
; Inputs:
;   SI = Pointer to String 1
;   DI = Pointer to String 2
; Outputs:
;   ZF = 1 if identical, ZF = 0 if different
;   AX = Difference of first non-matching byte (0 if identical)
; Preserved:
;   SI, DI, BX, CX, DX
; -----------------------------------------------------------------------------
strcmp16:
    push si                             ;Push SI register onto memory stack
    push di                             ;Push DI register onto memory stack
    push bx                             ;Push BX register onto memory stack

.loop:
    mov al, byte [si]                   ; Set al = byte [si]
    mov bl, byte [di]                   ; Set bl = byte [di]
    cmp al, bl                          ; Execute hardware step
    jne .diff                           ; Branch to '.diff' if Zero Flag is clear (ZF=0)
    test al, al                         ; Test AL byte for zero (null-terminator)
    jz .equal                           ; Branch to '.equal' if Zero Flag is set (ZF=1)
    inc si                              ;Increment si by 1
    inc di                              ;Increment di by 1
    jmp .loop                           ;Unconditional jump to target label .loop

.diff:
    movzx ax, al                        ; Execute hardware step
    movzx bx, bl                        ; Execute hardware step
    sub ax, bx                          ; Execute hardware step
    pop bx                              ;Pop top stack value into BX register
    pop di                              ;Pop top stack value into DI register
    pop si                              ;Pop top stack value into SI register
    ret                                 ;Return control to caller instruction pointer

.equal:
    xor ax, ax                          ;Zero out AX register
    pop bx                              ;Pop top stack value into BX register
    pop di                              ;Pop top stack value into DI register
    pop si                              ;Pop top stack value into SI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; strcpy16: Copies null-terminated string from SI to DI.
; Inputs:
;   SI = Source string pointer
;   DI = Destination buffer pointer
; Preserved:
;   SI, DI, AX, CX
; -----------------------------------------------------------------------------
strcpy16:
    push si                             ;Push SI register onto memory stack
    push di                             ;Push DI register onto memory stack
    push ax                             ;Push AX register onto memory stack
.loop:
    mov al, [si]                        ; Set al = [si]
    mov [di], al                        ; Set [di] = al
    test al, al                         ; Test AL byte for zero (null-terminator)
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    inc si                              ;Increment si by 1
    inc di                              ;Increment di by 1
    jmp .loop                           ;Unconditional jump to target label .loop
.done:
    pop ax                              ;Pop top stack value into AX register
    pop di                              ;Pop top stack value into DI register
    pop si                              ;Pop top stack value into SI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; strcat16: Appends string at SI to the end of string at DI.
; Inputs:
;   SI = Source string pointer
;   DI = Destination string buffer pointer
; Preserved:
;   SI, DI, AX, CX
; -----------------------------------------------------------------------------
strcat16:
    push si                             ;Push SI register onto memory stack
    push di                             ;Push DI register onto memory stack
    push ax                             ;Push AX register onto memory stack

    ; 1. Find end of destination string
.find_end:
    cmp byte [di], 0                    ; Execute hardware step
    je .copy_source                     ; Branch to '.copy_source' if Zero Flag is set (ZF=1)
    inc di                              ;Increment di by 1
    jmp .find_end                       ;Unconditional jump to target label .find_end

    ; 2. Copy source into end of destination
.copy_source:
    mov al, [si]                        ; Set al = [si]
    mov [di], al                        ; Set [di] = al
    test al, al                         ; Test AL byte for zero (null-terminator)
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    inc si                              ;Increment si by 1
    inc di                              ;Increment di by 1
    jmp .copy_source                    ;Unconditional jump to target label .copy_source

.done:
    pop ax                              ;Pop top stack value into AX register
    pop di                              ;Pop top stack value into DI register
    pop si                              ;Pop top stack value into SI register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; to_upper16: Converts an in-place ASCII string at DI to uppercase.
; Inputs:
;   DI = Pointer to null-terminated string
; -----------------------------------------------------------------------------
to_upper16:
    push di                             ;Push DI register onto memory stack
    push ax                             ;Push AX register onto memory stack
.loop:
    mov al, [di]                        ; Set al = [di]
    test al, al                         ; Test AL byte for zero (null-terminator)
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)
    cmp al, 'a'                         ; Execute hardware step
    jb .next                            ; Execute hardware step
    cmp al, 'z'                         ; Execute hardware step
    ja .next                            ; Execute hardware step
    sub al, 32                          ;Convert 'a'..'z' to 'A'..'Z'
    mov [di], al                        ; Set [di] = al
.next:
    inc di                              ;Increment di by 1
    jmp .loop                           ;Unconditional jump to target label .loop
.done:
    pop ax                              ;Pop top stack value into AX register
    pop di                              ;Pop top stack value into DI register
    ret                                 ;Return control to caller instruction pointer
