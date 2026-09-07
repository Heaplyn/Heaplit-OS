; src/kernel/scheduler.asm
; Tickless Event-Driven Scheduler & Fast Context Switch for Heaplit OS
[bits 64]                               ; Execute instruction
default rel                             ; Execute instruction

global switch_threads
global scheduler_yield

struc thread_control_block              ; Execute instruction
    .rsp          resq 1                ; Offset 0x00: Saved Stack Pointer
    .cr3          resq 1                ; Offset 0x08: Page Directory Base Address
    .cpu_affinity resd 1                ; Offset 0x10: Target Core ID
    .priority     resd 1                ; Offset 0x14: Priority (0=Idle, 255=Realtime AI)
    .state        resd 1                ; Offset 0x18: 0=Ready, 1=Running, 2=Blocked, 3=Dead
    .xsave_ptr    resq 1                ; Offset 0x20: Pointer to 4KB XSAVE vector area
endstruc                                ; Execute instruction

; -----------------------------------------------------------------------------
; switch_threads: The ~20-instruction microkernel context switch.
; Inputs:
;   RDI = Pointer to outgoing thread's TCB (prev)
;   RSI = Pointer to incoming thread's TCB (next)
; -----------------------------------------------------------------------------
align 16
switch_threads:
    ; 1. Save general-purpose callee-saved registers on outgoing thread's stack
    push rbp                            ; Save caller frame pointer to stack
    push rbx                            ; Preserve non-volatile RBX register on stack
    push r12                            ; Preserve non-volatile R12 register on stack
    push r13                            ; Preserve non-volatile R13 register on stack
    push r14                            ; Preserve non-volatile R14 register on stack
    push r15                            ; Preserve non-volatile R15 register on stack
    pushfq                              ; Save RFLAGS

    ; 2. Store current stack pointer in prev->rsp
    mov [rdi + thread_control_block.rsp], rsp ; Execute instruction

    ; 3. Load incoming thread's stack pointer from next->rsp
    mov rsp, [rsi + thread_control_block.rsp] ; Execute instruction

    ; 4. Check if page tables (CR3) need swapping
    mov rax, [rsi + thread_control_block.cr3] ; Execute instruction
    mov rdx, cr3                        ; Copy value from cr3 to rdx
    cmp rax, rdx                        ; Compare rax with rdx and update CPU EFLAGS
    je .same_address_space              ; Jump to .same_address_space if condition 'e' is met
    mov cr3, rax                        ; Swap page tables
.same_address_space:

    ; 5. Restore incoming thread's register state
    popfq                               ; Execute instruction
    pop r15                             ; Restore non-volatile R15 register from stack
    pop r14                             ; Restore non-volatile R14 register from stack
    pop r13                             ; Restore non-volatile R13 register from stack
    pop r12                             ; Restore non-volatile R12 register from stack
    pop rbx                             ; Restore non-volatile RBX register from stack
    pop rbp                             ; Restore caller stack frame base address

    ; 6. Return into incoming thread's saved instruction pointer (RIP)
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; scheduler_yield: Voluntarily relinquishes remaining CPU time slice.
; -----------------------------------------------------------------------------
scheduler_yield:
    mov rdi, [current_thread]           ; Copy value from [current_thread] to rdi
    mov rsi, [next_thread]              ; Copy value from [next_thread] to rsi
    jmp switch_threads                  ; Unconditional jump to target label switch_threads

current_thread: dq 0                    ; Execute instruction
next_thread:    dq 0                    ; Execute instruction
