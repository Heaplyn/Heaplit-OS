; src/kernel/scheduler.asm
; Tickless Event-Driven Scheduler & Fast Context Switch for Heaplit OS
[bits 64]
default rel

global switch_threads
global scheduler_yield

struc thread_control_block
    .rsp          resq 1        ; Offset 0x00: Saved Stack Pointer
    .cr3          resq 1        ; Offset 0x08: Page Directory Base Address
    .cpu_affinity resd 1        ; Offset 0x10: Target Core ID
    .priority     resd 1        ; Offset 0x14: Priority (0=Idle, 255=Realtime AI)
    .state        resd 1        ; Offset 0x18: 0=Ready, 1=Running, 2=Blocked, 3=Dead
    .xsave_ptr    resq 1        ; Offset 0x20: Pointer to 4KB XSAVE vector area
endstruc

; -----------------------------------------------------------------------------
; switch_threads: The ~20-instruction microkernel context switch.
; Inputs:
;   RDI = Pointer to outgoing thread's TCB (prev)
;   RSI = Pointer to incoming thread's TCB (next)
; -----------------------------------------------------------------------------
align 16
switch_threads:
    ; 1. Save general-purpose callee-saved registers on outgoing thread's stack
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    pushfq                      ; Save RFLAGS

    ; 2. Store current stack pointer in prev->rsp
    mov [rdi + thread_control_block.rsp], rsp

    ; 3. Load incoming thread's stack pointer from next->rsp
    mov rsp, [rsi + thread_control_block.rsp]

    ; 4. Check if page tables (CR3) need swapping
    mov rax, [rsi + thread_control_block.cr3]
    mov rdx, cr3
    cmp rax, rdx
    je .same_address_space
    mov cr3, rax                ; Swap page tables
.same_address_space:

    ; 5. Restore incoming thread's register state
    popfq
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp

    ; 6. Return into incoming thread's saved instruction pointer (RIP)
    ret

; -----------------------------------------------------------------------------
; scheduler_yield: Voluntarily relinquishes remaining CPU time slice.
; -----------------------------------------------------------------------------
scheduler_yield:
    mov rdi, [current_thread]
    mov rsi, [next_thread]
    jmp switch_threads

current_thread: dq 0
next_thread:    dq 0
