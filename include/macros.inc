; =============================================================================
; Heaplit OS - Reusable NASM Macro Library
; =============================================================================

; -----------------------------------------------------------------------------
; ALIGN_16: Pads current location to the next 16-byte boundary with NOPs (0x90).
; -----------------------------------------------------------------------------
%macro ALIGN_16 0
    times ($$ - $) & 15 db 0x90
%endmacro

; -----------------------------------------------------------------------------
; ALIGN_4K: Pads current location to the next 4KB (4096 bytes) page boundary.
; -----------------------------------------------------------------------------
%macro ALIGN_4K 0
    times ($$ - $) & 4095 db 0x00
%endmacro

; -----------------------------------------------------------------------------
; PUSH_ALL_64: Saves all 16 general-purpose 64-bit registers onto the stack.
; -----------------------------------------------------------------------------
%macro PUSH_ALL_64 0
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
%endmacro

; -----------------------------------------------------------------------------
; POP_ALL_64: Restores all 16 general-purpose 64-bit registers from the stack.
; -----------------------------------------------------------------------------
%macro POP_ALL_64 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro

; -----------------------------------------------------------------------------
; DEBUG_HALT: Permanently disables interrupts and halts the CPU.
; -----------------------------------------------------------------------------
%macro DEBUG_HALT 0
    cli
    hlt
    jmp $
%endmacro
