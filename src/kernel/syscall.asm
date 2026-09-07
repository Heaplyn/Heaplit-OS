; src/kernel/syscall.asm
; Fast x86_64 Syscall Entry & Dispatcher for Heaplit OS
[bits 64]
default rel

global init_syscalls
global syscall_entry
extern ai_dispatcher

; -----------------------------------------------------------------------------
; init_syscalls: Configures CPU MSRs for syscall / sysret execution.
; -----------------------------------------------------------------------------
init_syscalls:
    push rbp
    mov rbp, rsp

    ; 1. Enable SCE (System Call Enable) bit 0 in IA32_EFER (0xC0000080)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1
    wrmsr

    ; 2. Configure Segment Selectors in IA32_STAR (0xC0000081)
    ; Bits 47:32 = User CS (0x28) / User SS (0x20)
    ; Bits 31:16 = Kernel CS (0x18) / Kernel SS (0x10)
    mov ecx, 0xC0000081
    rdmsr
    mov edx, (0x28 << 16) | 0x18
    wrmsr

    ; 3. Set Target Entry Point in IA32_LSTAR (0xC0000082)
    mov ecx, 0xC0000082
    mov rax, syscall_entry
    mov rdx, rax
    shr rdx, 32                 ; High 32 bits in EDX
    wrmsr

    ; 4. Mask RFLAGS in IA32_SFMASK (0xC0000084) (Disable interrupts on entry)
    mov ecx, 0xC0000084
    mov eax, 0x200              ; Clear IF (Interrupt Flag)
    xor edx, edx
    wrmsr

    pop rbp
    ret

; -----------------------------------------------------------------------------
; syscall_entry: The fast hardware entry point for all Ring 2/3 syscalls.
; -----------------------------------------------------------------------------
align 16
syscall_entry:
    ; 1. Switch to Kernel Stack via GS Base
    swapgs
    mov [gs:0x10], rsp          ; Save user stack pointer
    mov rsp, [gs:0x08]          ; Load kernel stack pointer

    ; 2. Preserve registers
    push r11                    ; Saved RFLAGS
    push rcx                    ; Saved RIP
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rdi
    push rsi
    push rdx
    push r8
    push r9

    ; 3. Route Antigravity AI Syscalls (0x600 - 0x6FF)
    cmp rax, 0x600
    jge .handle_ai_syscall

    cmp rax, MAX_SYSCALL_NUM
    jae .invalid_syscall

    ; Dispatch POSIX / Kernel Syscall
    call [syscall_table + rax * 8]
    jmp .syscall_return

.handle_ai_syscall:
    call ai_dispatcher
    jmp .syscall_return

.invalid_syscall:
    mov rax, -1

.syscall_return:
    ; 4. Restore user registers
    pop r9
    pop r8
    pop rdx
    pop rsi
    pop rdi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    pop rcx                     ; Restore return RIP
    pop r11                     ; Restore return RFLAGS

    mov rsp, [gs:0x10]          ; Restore user stack pointer
    swapgs
    o64 sysret

MAX_SYSCALL_NUM equ 64

align 8
syscall_table:
    times MAX_SYSCALL_NUM dq 0
