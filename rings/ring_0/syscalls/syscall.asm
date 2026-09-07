; src/kernel/syscall.asm
; Fast x86_64 Syscall Entry & Dispatcher for Heaplit OS
[bits 64]                               ; Set assembler target mode to 64-bit Long Mode
default rel                             ; Execute hardware step

global init_syscalls
global syscall_entry
extern ai_dispatcher

; -----------------------------------------------------------------------------
; init_syscalls: Configures CPU MSRs for syscall / sysret execution.
; -----------------------------------------------------------------------------
init_syscalls:
    push rbp                            ;Save caller frame pointer to stack
    mov rbp, rsp                        ;Establish new stack frame base address

    ; 1. Enable SCE (System Call Enable) bit 0 in IA32_EFER (0xC0000080)
    mov ecx, 0xC0000080                 ; Set ecx = 0xC0000080
    rdmsr                               ;Read Model Specific Register (ECX -> EDX:EAX)
    or eax, 1                           ; Execute hardware step
    wrmsr                               ;Write Model Specific Register (EDX:EAX -> ECX)

    ; 2. Configure Segment Selectors in IA32_STAR (0xC0000081)
    ; Bits 47:32 = User CS (0x28) / User SS (0x20)
    ; Bits 31:16 = Kernel CS (0x18) / Kernel SS (0x10)
    mov ecx, 0xC0000081                 ; Set ecx = 0xC0000081
    rdmsr                               ;Read Model Specific Register (ECX -> EDX:EAX)
    mov edx, (0x28 << 16) | 0x18        ; Move value into target register/memory
    wrmsr                               ;Write Model Specific Register (EDX:EAX -> ECX)

    ; 3. Set Target Entry Point in IA32_LSTAR (0xC0000082)
    mov ecx, 0xC0000082                 ; Set ecx = 0xC0000082
    mov rax, syscall_entry              ; Set rax = syscall_entry
    mov rdx, rax                        ; Set rdx = rax
    shr rdx, 32                         ;High 32 bits in EDX
    wrmsr                               ;Write Model Specific Register (EDX:EAX -> ECX)

    ; 4. Mask RFLAGS in IA32_SFMASK (0xC0000084) (Disable interrupts on entry)
    mov ecx, 0xC0000084                 ; Set ecx = 0xC0000084
    mov eax, 0x200                      ;Clear IF (Interrupt Flag)
    xor edx, edx                        ;Zero out EDX register
    wrmsr                               ;Write Model Specific Register (EDX:EAX -> ECX)

    pop rbp                             ;Restore caller stack frame base address
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; syscall_entry: The fast hardware entry point for all Ring 2/3 syscalls.
; -----------------------------------------------------------------------------
align 16
syscall_entry:
    ; 1. Switch to Kernel Stack via GS Base
    swapgs                              ; Execute hardware step
    mov [gs:0x10], rsp                  ;Save user stack pointer
    mov rsp, [gs:0x08]                  ;Load kernel stack pointer

    ; 2. Preserve registers
    push r11                            ;Saved RFLAGS
    push rcx                            ;Saved RIP
    push rbp                            ;Save caller frame pointer to stack
    push rbx                            ;Preserve non-volatile RBX register on stack
    push r12                            ;Preserve non-volatile R12 register on stack
    push r13                            ;Preserve non-volatile R13 register on stack
    push r14                            ;Preserve non-volatile R14 register on stack
    push r15                            ;Preserve non-volatile R15 register on stack
    push rdi                            ;Preserve RDI destination register on stack
    push rsi                            ;Preserve RSI source register on stack
    push rdx                            ;Preserve RDX data register on stack
    push r8                             ;Push R8 register onto memory stack
    push r9                             ;Push R9 register onto memory stack

    ; 3. Route Heaplit AI Syscalls (0x600 - 0x6FF)
    cmp rax, 0x600                      ; Execute hardware step
    jge .handle_ai_syscall              ; Branch to '.handle_ai_syscall' if Greater or Equal

    cmp rax, MAX_SYSCALL_NUM            ; Execute hardware step
    jae .invalid_syscall                ; Execute hardware step

    ; Dispatch POSIX / Kernel Syscall
    call [syscall_table + rax * 8]      ; Call helper function '[syscall_table'
    jmp .syscall_return                 ;Unconditional jump to target label .syscall_return

.handle_ai_syscall:
    call ai_dispatcher                  ; Call subroutine 'ai_dispatcher'
    jmp .syscall_return                 ;Unconditional jump to target label .syscall_return

.invalid_syscall:
    mov rax, -1                         ; Set rax = -1

.syscall_return:
    ; 4. Restore user registers
    pop r9                              ;Pop top stack value into R9 register
    pop r8                              ;Pop top stack value into R8 register
    pop rdx                             ;Restore RDX data register from stack
    pop rsi                             ;Restore RSI source register from stack
    pop rdi                             ;Restore RDI destination register from stack
    pop r15                             ;Restore non-volatile R15 register from stack
    pop r14                             ;Restore non-volatile R14 register from stack
    pop r13                             ;Restore non-volatile R13 register from stack
    pop r12                             ;Restore non-volatile R12 register from stack
    pop rbx                             ;Restore non-volatile RBX register from stack
    pop rbp                             ;Restore caller stack frame base address
    pop rcx                             ;Restore return RIP
    pop r11                             ;Restore return RFLAGS

    mov rsp, [gs:0x10]                  ;Restore user stack pointer
    swapgs                              ; Execute hardware step
    o64 sysret                          ; Execute hardware step

MAX_SYSCALL_NUM equ 64                  ; Execute hardware step

align 8
syscall_table:
    times MAX_SYSCALL_NUM dq 0          ; Execute hardware step
