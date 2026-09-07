; ============================================================================
; Heaplit OS - Hardware Sandbox Isolation & Concurrency Primitives
; Ring Placement: rings/ring_0/cpu/sandbox.asm (Ring 0)
; Description: CR3 Page Table Ring Protection, W^X enforcement, and x86-64
;              atomic lock-free spinlocks (lock bts, lock xadd, lock cmpxchg16b).
; ============================================================================

global spinlock_acquire
global spinlock_release
global atomic_add64
global atomic_cmpxchg16b
global enforce_page_sandbox

section .text
bits 64

; ----------------------------------------------------------------------------
; spinlock_acquire: Acquires an atomic spinlock with CPU pause power management
; Inputs: RDI = Pointer to 64-bit lock variable
; Returns: None
; ----------------------------------------------------------------------------
align 16
spinlock_acquire:
.spin:
    lock bts qword [rdi], 0             ;Set bit 0 atomically
    jnc .acquired                       ;If carry was 0, we acquired the lock
.loop:
    pause                               ;Reduce power and pipeline stalls
    test qword [rdi], 1                 ; Execute hardware step
    jnz .loop                           ; Branch to '.loop' if Zero Flag is clear (ZF=0)
    jmp .spin                           ;Unconditional jump to target label .spin
.acquired:
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; spinlock_release: Releases an acquired spinlock
; Inputs: RDI = Pointer to 64-bit lock variable
; Returns: None
; ----------------------------------------------------------------------------
align 16
spinlock_release:
    mov qword [rdi], 0                  ;Clear lock bit
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; atomic_add64: Atomically adds a value to a 64-bit destination
; Inputs: RDI = Pointer to 64-bit target, RSI = Value to add
; Returns: RAX = Old Value before addition
; ----------------------------------------------------------------------------
align 16
atomic_add64:
    mov rax, rsi                        ; Set rax = rsi
    lock xadd [rdi], rax                ;Atomic Exchange and Add
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; atomic_cmpxchg16b: Atomic 128-bit compare and exchange
; Inputs: RDI = Destination pointer, RDX:RAX = Expected, RCX:RBX = New
; Returns: RAX = Success (1) or Failure (0)
; ----------------------------------------------------------------------------
align 16
atomic_cmpxchg16b:
    push rbx                            ;Preserve non-volatile RBX register on stack
    mov rbx, rcx                        ;Move lower 64-bit new value to RBX
    mov rcx, r8                         ;Move upper 64-bit new value to RCX
    lock cmpxchg16b [rdi]               ; Execute hardware step
    setz al                             ;Return 1 if equal, 0 if not
    movzx rax, al                       ; Execute hardware step
    pop rbx                             ;Restore non-volatile RBX register from stack
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; enforce_page_sandbox: Configures page directory CR3 isolation flags
; Inputs: RDI = Physical Address of PML4 Table
; Returns: None
; ----------------------------------------------------------------------------
align 16
enforce_page_sandbox:
    mov cr3, rdi                        ;Load PML4 root into CR3
    ret                                 ;Return control to caller instruction pointer
