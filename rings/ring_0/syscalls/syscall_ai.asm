; src/kernel/syscall_ai.asm
; Heaplit AI Syscall Interface & XSAVE State Management (0x600 - 0x6FF)
[bits 64]                               ; Set assembler target mode to 64-bit Long Mode

global ai_dispatcher
extern ai_load_model_c
extern ai_infer_c
extern ai_schedule_c

align 16
ai_dispatcher:
    ; 1. Save 512-bit vector registers (AVX-512, ZMM0-ZMM31) to kernel XSAVE area
    mov r10, kernel_xsave_area          ; Set r10 = kernel_xsave_area
    mov eax, 0xE7                       ;Request x87, SSE, AVX, OPMASK, ZMM state
    xor edx, edx                        ;Zero out EDX register
    xsave [r10]                         ; Execute hardware step

    ; 2. Boost core frequency via IA32_PERF_CTL MSR (Turbo mode hint)
    mov ecx, 0x199                      ;IA32_PERF_CTL MSR
    rdmsr                               ;Read Model Specific Register (ECX -> EDX:EAX)
    or eax, 0x1000                      ;Turbo boost bit
    wrmsr                               ;Write Model Specific Register (EDX:EAX -> ECX)

    ; 3. Route specific AI Syscall numbers
    cmp rax, 0x600                      ; Execute hardware step
    je .load_model                      ; Branch to '.load_model' if Zero Flag is set (ZF=1)
    cmp rax, 0x601                      ; Execute hardware step
    je .infer                           ; Branch to '.infer' if Zero Flag is set (ZF=1)
    cmp rax, 0x602                      ; Execute hardware step
    je .schedule_task                   ; Branch to '.schedule_task' if Zero Flag is set (ZF=1)
    jmp .invalid                        ;Unconditional jump to target label .invalid

.load_model:
    ; Arguments: RDI = Model Path, RSI = Size Hint
    call ai_load_model_c                ; Call subroutine 'ai_load_model_c'
    jmp .restore_and_return             ;Unconditional jump to target label .restore_and_return

.infer:
    ; Arguments: RDI = Model Handle, RSI = Prompt, RDX = Length, RCX = Output Buffer
    call ai_infer_c                     ; Call subroutine 'ai_infer_c'
    jmp .restore_and_return             ;Unconditional jump to target label .restore_and_return

.schedule_task:
    ; Arguments: RDI = Task Struct Pointer
    call ai_schedule_c                  ; Call subroutine 'ai_schedule_c'
    jmp .restore_and_return             ;Unconditional jump to target label .restore_and_return

.invalid:
    mov rax, -1                         ; Set rax = -1

.restore_and_return:
    push rax                            ;Preserve return value
    ; 4. Restore AVX-512 state
    mov r10, kernel_xsave_area          ; Set r10 = kernel_xsave_area
    mov eax, 0xE7                       ; Set eax = 0xE7
    xor edx, edx                        ;Zero out EDX register
    xrstor [r10]                        ; Execute hardware step
    pop rax                             ;Restore return value
    ret                                 ;Return control to caller instruction pointer

align 64
kernel_xsave_area:
    times 4096 db 0                     ;4KB aligned XSAVE buffer
