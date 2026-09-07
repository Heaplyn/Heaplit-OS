; src/kernel/syscall_ai.asm
; Heaplit AI Syscall Interface & XSAVE State Management (0x600 - 0x6FF)
[bits 64]                               ; Execute instruction

global ai_dispatcher
extern ai_load_model_c
extern ai_infer_c
extern ai_schedule_c

align 16
ai_dispatcher:
    ; 1. Save 512-bit vector registers (AVX-512, ZMM0-ZMM31) to kernel XSAVE area
    mov r10, kernel_xsave_area          ; Copy value from kernel_xsave_area to r10
    mov eax, 0xE7                       ; Request x87, SSE, AVX, OPMASK, ZMM state
    xor edx, edx                        ; Zero out EDX register
    xsave [r10]                         ; Execute instruction

    ; 2. Boost core frequency via IA32_PERF_CTL MSR (Turbo mode hint)
    mov ecx, 0x199                      ; IA32_PERF_CTL MSR
    rdmsr                               ; Read Model Specific Register (ECX -> EDX:EAX)
    or eax, 0x1000                      ; Turbo boost bit
    wrmsr                               ; Write Model Specific Register (EDX:EAX -> ECX)

    ; 3. Route specific AI Syscall numbers
    cmp rax, 0x600                      ; Compare rax with 0x600 and update CPU EFLAGS
    je .load_model                      ; Jump to .load_model if condition 'e' is met
    cmp rax, 0x601                      ; Compare rax with 0x601 and update CPU EFLAGS
    je .infer                           ; Jump to .infer if condition 'e' is met
    cmp rax, 0x602                      ; Compare rax with 0x602 and update CPU EFLAGS
    je .schedule_task                   ; Jump to .schedule_task if condition 'e' is met
    jmp .invalid                        ; Unconditional jump to target label .invalid

.load_model:
    ; Arguments: RDI = Model Path, RSI = Size Hint
    call ai_load_model_c                ; Execute instruction
    jmp .restore_and_return             ; Unconditional jump to target label .restore_and_return

.infer:
    ; Arguments: RDI = Model Handle, RSI = Prompt, RDX = Length, RCX = Output Buffer
    call ai_infer_c                     ; Execute instruction
    jmp .restore_and_return             ; Unconditional jump to target label .restore_and_return

.schedule_task:
    ; Arguments: RDI = Task Struct Pointer
    call ai_schedule_c                  ; Execute instruction
    jmp .restore_and_return             ; Unconditional jump to target label .restore_and_return

.invalid:
    mov rax, -1                         ; Copy value from -1 to rax

.restore_and_return:
    push rax                            ; Preserve return value
    ; 4. Restore AVX-512 state
    mov r10, kernel_xsave_area          ; Copy value from kernel_xsave_area to r10
    mov eax, 0xE7                       ; Copy value from 0xE7 to eax
    xor edx, edx                        ; Zero out EDX register
    xrstor [r10]                        ; Execute instruction
    pop rax                             ; Restore return value
    ret                                 ; Return control to caller instruction pointer

align 64
kernel_xsave_area:
    times 4096 db 0                     ; 4KB aligned XSAVE buffer
