; rings/ring_0/ring_0/string.asm
; String Manipulation Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]

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
    push si
    xor cx, cx
.loop:
    cmp byte [si], 0
    je .done
    inc si
    inc cx
    jmp .loop
.done:
    pop si
    ret

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
    push si
    push di
    push bx

.loop:
    mov al, byte [si]
    mov bl, byte [di]
    cmp al, bl
    jne .diff
    test al, al
    jz .equal
    inc si
    inc di
    jmp .loop

.diff:
    movzx ax, al
    movzx bx, bl
    sub ax, bx
    pop bx
    pop di
    pop si
    ret

.equal:
    xor ax, ax
    pop bx
    pop di
    pop si
    ret

; -----------------------------------------------------------------------------
; strcpy16: Copies null-terminated string from SI to DI.
; Inputs:
;   SI = Source string pointer
;   DI = Destination buffer pointer
; Preserved:
;   SI, DI, AX, CX
; -----------------------------------------------------------------------------
strcpy16:
    push si
    push di
    push ax
.loop:
    mov al, [si]
    mov [di], al
    test al, al
    jz .done
    inc si
    inc di
    jmp .loop
.done:
    pop ax
    pop di
    pop si
    ret

; -----------------------------------------------------------------------------
; strcat16: Appends string at SI to the end of string at DI.
; Inputs:
;   SI = Source string pointer
;   DI = Destination string buffer pointer
; Preserved:
;   SI, DI, AX, CX
; -----------------------------------------------------------------------------
strcat16:
    push si
    push di
    push ax

    ; 1. Find end of destination string
.find_end:
    cmp byte [di], 0
    je .copy_source
    inc di
    jmp .find_end

    ; 2. Copy source into end of destination
.copy_source:
    mov al, [si]
    mov [di], al
    test al, al
    jz .done
    inc si
    inc di
    jmp .copy_source

.done:
    pop ax
    pop di
    pop si
    ret

; -----------------------------------------------------------------------------
; to_upper16: Converts an in-place ASCII string at DI to uppercase.
; Inputs:
;   DI = Pointer to null-terminated string
; -----------------------------------------------------------------------------
to_upper16:
    push di
    push ax
.loop:
    mov al, [di]
    test al, al
    jz .done
    cmp al, 'a'
    jb .next
    cmp al, 'z'
    ja .next
    sub al, 32                  ; Convert 'a'..'z' to 'A'..'Z'
    mov [di], al
.next:
    inc di
    jmp .loop
.done:
    pop ax
    pop di
    ret
