; rings/ring_1/hardware/thread.asm
; =============================================================================
; Heaplit OS - Freestanding Ring 1 Thread Sleep System Call Bridge
; Ring Placement: rings/ring_1/hardware/thread.asm (Ring 1)
; Description: 64-bit Assembly wrapper invoking sys_nanosleep (syscall 35).
; =============================================================================

[bits 64]                               ; 64-bit Long Mode Execution

global sleep_for_nanoseconds

section .text

; -----------------------------------------------------------------------------
; sleep_for_nanoseconds: Invokes kernel sys_nanosleep syscall
; Inputs: RDI = Pointer to timespec structure
; Returns: RAX = 0 on Success, -1 on Error
; -----------------------------------------------------------------------------
align 16
sleep_for_nanoseconds:
    mov rax, 35                         ; Copy syscall number 35 (sys_nanosleep) to RAX
    xor rsi, rsi                        ; Zero out RSI (NULL pointer for remaining time)
    syscall                             ; Fast hardware syscall invocation into Ring 0 microkernel
    ret                                 ; Return control to caller instruction pointer
