; src/kernel/syscall_ai.asm
; Antigravity AI Syscall Interface & XSAVE State Management (0x600 - 0x6FF)
[bits 64]

global ai_dispatcher
extern ai_load_model_c
extern ai_infer_c
extern ai_schedule_c

align 16
ai_dispatcher:
    ; 1. Save 512-bit vector registers (AVX-512, ZMM0-ZMM31) to kernel XSAVE area
    mov r10, kernel_xsave_area
    mov eax, 0xE7               ; Request x87, SSE, AVX, OPMASK, ZMM state
    xor edx, edx
    xsave [r10]

    ; 2. Boost core frequency via IA32_PERF_CTL MSR (Turbo mode hint)
    mov ecx, 0x199              ; IA32_PERF_CTL MSR
    rdmsr
    or eax, 0x1000              ; Turbo boost bit
    wrmsr

    ; 3. Route specific AI Syscall numbers
    cmp rax, 0x600
    je .load_model
    cmp rax, 0x601
    je .infer
    cmp rax, 0x602
    je .schedule_task
    jmp .invalid

.load_model:
    ; Arguments: RDI = Model Path, RSI = Size Hint
    call ai_load_model_c
    jmp .restore_and_return

.infer:
    ; Arguments: RDI = Model Handle, RSI = Prompt, RDX = Length, RCX = Output Buffer
    call ai_infer_c
    jmp .restore_and_return

.schedule_task:
    ; Arguments: RDI = Task Struct Pointer
    call ai_schedule_c
    jmp .restore_and_return

.invalid:
    mov rax, -1

.restore_and_return:
    push rax                    ; Preserve return value
    ; 4. Restore AVX-512 state
    mov r10, kernel_xsave_area
    mov eax, 0xE7
    xor edx, edx
    xrstor [r10]
    pop rax                     ; Restore return value
    ret

align 64
kernel_xsave_area:
    times 4096 db 0             ; 4KB aligned XSAVE buffer
