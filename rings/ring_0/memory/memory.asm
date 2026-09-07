; ring_1/memory.asm
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

segment_times: db 0                     ; Execute hardware step

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
    push    di                          ;Save original offset for restoration
    
    ; 1. Duplicate the byte in al across both al and ah
    mov     ah, al                      ;If al = 0xAA, then ax = 0xAAAA
    
    ; 2. Adjust count for 16-bit words
    mov     bx, cx                      ;Keep a copy of the original byte count in bx
    shr     cx, 1                       ;Divide byte count by 2 to get word count (cx = cx / 2)
    jz      .handle_odd                 ;If length was 0 or 1, skip the word loop

    ; 3. Perform fast word-sized fill
    cld                                 ;Clear direction flag (di increments forward)
    rep     stosw                       ;Store 16-bit word in ax to [es:di], cx times (di advances by 2 * cx)

.handle_odd:
    ; 4. Handle remaining single byte if original count was odd
    test    bx, 1                       ;Test if the lowest bit of original count was set
    jz      .done                       ; Branch to '.done' if Zero Flag is set (ZF=1)
    stosb                               ;Write the last odd byte using al

.done:
    pop     di                          ;Restore original destination offset
    ret                                 ;Return control to caller instruction pointer
.loop:
    mov byte [di], al                   ; Set byte [di] = al
    inc di                              ;Increment di by 1
    dec cx                              ;Decrement cx by 1
    jnz short .loop                     ; Branch to 'short' if Zero Flag is clear (ZF=0)

mem_copy:
    test cx, cx                         ; Execute hardware step
    jz short .done                      ; Branch to 'short' if Zero Flag is set (ZF=1)
.loop:
    mov al, byte [si]                   ; Set al = byte [si]
    mov byte [di], al                   ; Set byte [di] = al
    inc di                              ;Increment di by 1
    inc si                              ;Increment si by 1
    dec cx                              ;Decrement cx by 1
    jnz short .loop                     ; Branch to 'short' if Zero Flag is clear (ZF=0)
.done:
    ret                                 ;Return control to caller instruction pointer

mem_zero:
    xor al, al                          ;Zero out AL register
    call mem_set                        ; Call subroutine 'mem_set'
    ret                                 ;Return control to caller instruction pointer

