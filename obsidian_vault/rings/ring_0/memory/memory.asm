; ring_1/memory.asm
[bits 16]

segment_times: db 0

; -----------------------------------------------------------------------------
; Memory Utilities
; -----------------------------------------------------------------------------
; Inputs:
;   es:di = Destination buffer pointer (Segment:Offset)
;   al    = Value to set (byte)
;   cx    = Number of bytes to set (length)
; Output:
;   es:di = Original destination pointer (restored)

mem_set:
    push    di                ; Save original offset for restoration
    
    ; 1. Duplicate the byte in al across both al and ah
    mov     ah, al            ; If al = 0xAA, then ax = 0xAAAA
    
    ; 2. Adjust count for 16-bit words
    mov     bx, cx            ; Keep a copy of the original byte count in bx
    shr     cx, 1             ; Divide byte count by 2 to get word count (cx = cx / 2)
    jz      .handle_odd       ; If length was 0 or 1, skip the word loop

    ; 3. Perform fast word-sized fill
    cld                       ; Clear direction flag (di increments forward)
    rep     stosw             ; Store 16-bit word in ax to [es:di], cx times (di advances by 2 * cx)

.handle_odd:
    ; 4. Handle remaining single byte if original count was odd
    test    bx, 1             ; Test if the lowest bit of original count was set
    jz      .done             
    stosb                     ; Write the last odd byte using al

.done:
    pop     di                ; Restore original destination offset
    ret
.loop:
    mov byte [di], al
    inc di
    dec cx
    jnz short .loop

mem_copy:
    test cx, cx
    jz short .done
.loop:
    mov al, byte [si]
    mov byte [di], al
    inc di
    inc si
    dec cx
    jnz short .loop
.done:
    ret

mem_zero:
    xor al, al
    call mem_set
    ret

