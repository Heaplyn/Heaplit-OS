; rings/ring_0/protected_mode.asm
; 32-bit Protected Mode Initialization & Long Mode CPUID Check

[bits 16]                               ; Set assembler target mode to 16-bit Real Mode
enter_protected_mode:
    cli                                 ;1. Disable all hardware interrupts
    lgdt [gdt_descriptor]               ;2. Load Global Descriptor Table

    ; 3. Enable Protection Enable (PE) bit in CR0
    mov eax, cr0                        ; Set eax = cr0
    or al, 1                            ;Set bit 0 (CR0.PE)
    mov cr0, eax                        ; Update Control Register 0 (CR0) with new protection/paging bits

    ; 4. Far jump to flush 16-bit prefetch queue and load 32-bit CS (0x08)
    jmp CODE_SEG_32:protected_mode_entry_32 ; Jump to label 'CODE_SEG_32:protected_mode_entry_32'

; -----------------------------------------------------------------------------
; 32-bit Protected Mode Code Segment
; -----------------------------------------------------------------------------
[bits 32]                               ; Set assembler target mode to 32-bit Protected Mode
protected_mode_entry_32:
    ; 1. Reload data segment registers with 32-bit Data Selector (0x10)
    mov ax, DATA_SEG_32                 ; Set ax = DATA_SEG_32
    mov ds, ax                          ; Set DS segment selector to match AX
    mov es, ax                          ; Set ES segment selector to match AX
    mov ss, ax                          ; Set SS segment selector to match AX
    mov fs, ax                          ; Set FS segment selector to match AX
    mov gs, ax                          ; Set GS segment selector to match AX
    mov esp, 0x90000                    ;Set 32-bit stack pointer safely at 0x90000

    ; 2. Output 32-bit status string directly to VGA text buffer at 0xB8000
    mov esi, msg_pm32_active            ; Set esi = msg_pm32_active
    mov edi, 0xB8000 + (10 * 80 * 2)    ;Row 10, Col 0
    call print_string_32                ; Call subroutine 'print_string_32'

    ; 3. Verify CPUID support
    call check_cpuid_32                 ; Call subroutine 'check_cpuid_32'
    test eax, eax                       ; Test accumulator register for zero / error status
    jz .no_cpuid                        ; Branch to '.no_cpuid' if Zero Flag is set (ZF=1)

    ; 4. Verify 64-bit Long Mode capability via Extended CPUID
    call check_long_mode_32             ; Call subroutine 'check_long_mode_32'
    test eax, eax                       ; Test accumulator register for zero / error status
    jz .no_long_mode                    ; Branch to '.no_long_mode' if Zero Flag is set (ZF=1)

    mov esi, msg_lm_supported           ; Set esi = msg_lm_supported
    mov edi, 0xB8000 + (11 * 80 * 2)    ;Row 11, Col 0
    call print_string_32                ; Call subroutine 'print_string_32'

    ; 5. Initialize 4-Level Paging (PML4) & Enable Long Mode in MSR
    call setup_paging_32                ; Call subroutine 'setup_paging_32'

    ; 6. Far jump into 64-bit Long Mode Code Segment (0x18)
    jmp CODE_SEG_64:long_mode_entry_64  ; Jump to label 'CODE_SEG_64:long_mode_entry_64'

.no_cpuid:
    mov esi, msg_no_cpuid               ; Set esi = msg_no_cpuid
    mov edi, 0xB8000 + (12 * 80 * 2)    ; Move value into target register/memory
    call print_string_32                ; Call subroutine 'print_string_32'
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ;Halt CPU execution until next hardware interrupt
    jmp $                               ; Infinite spin loop to halt CPU on fatal error

.no_long_mode:
    mov esi, msg_no_lm                  ; Set esi = msg_no_lm
    mov edi, 0xB8000 + (12 * 80 * 2)    ; Move value into target register/memory
    call print_string_32                ; Call subroutine 'print_string_32'
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ;Halt CPU execution until next hardware interrupt
    jmp $                               ; Infinite spin loop to halt CPU on fatal error

; -----------------------------------------------------------------------------
; check_cpuid_32: Checks if CPUID instruction is supported via EFLAGS ID bit (21).
; Returns: EAX = 1 if supported, EAX = 0 if not
; -----------------------------------------------------------------------------
check_cpuid_32:
    pushfd                              ; Push 32-bit EFLAGS register onto stack
    pop eax                             ;Pop top stack value into EAX register
    mov ecx, eax                        ; Set ecx = eax
    xor eax, 1 << 21                    ;Flip ID bit
    push eax                            ;Push EAX register onto memory stack
    popfd                               ; Restore 32-bit EFLAGS register from stack
    pushfd                              ; Push 32-bit EFLAGS register onto stack
    pop eax                             ;Pop top stack value into EAX register
    push ecx                            ;Push ECX register onto memory stack
    popfd                               ;Restore original EFLAGS
    xor eax, ecx                        ; Clear EAX register to 0
    jz .not_supported                   ; Branch to '.not_supported' if Zero Flag is set (ZF=1)
    mov eax, 1                          ; Set eax = 1
    ret                                 ;Return control to caller instruction pointer
.not_supported:
    xor eax, eax                        ;Zero out EAX register
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; check_long_mode_32: Checks CPUID extended function 0x80000001 for LM bit (29).
; Returns: EAX = 1 if Long Mode supported, EAX = 0 if not
; -----------------------------------------------------------------------------
check_long_mode_32:
    mov eax, 0x80000000                 ; Set eax = 0x80000000
    cpuid                               ; Execute hardware step
    cmp eax, 0x80000001                 ; Execute hardware step
    jb .no_lm                           ; Execute hardware step

    mov eax, 0x80000001                 ; Set eax = 0x80000001
    cpuid                               ; Execute hardware step
    test edx, 1 << 29                   ;Long Mode bit in EDX
    jz .no_lm                           ; Branch to '.no_lm' if Zero Flag is set (ZF=1)
    mov eax, 1                          ; Set eax = 1
    ret                                 ;Return control to caller instruction pointer
.no_lm:
    xor eax, eax                        ;Zero out EAX register
    ret                                 ;Return control to caller instruction pointer

msg_pm32_active:   db 'Heaplit OS: 32-bit Protected Mode Active.', 0 ; Execute hardware step
msg_lm_supported:  db 'Hardware CPUID: 64-bit Long Mode Verified Supported.', 0 ; Execute hardware step
msg_no_cpuid:      db 'FATAL: CPUID not supported by CPU!', 0 ; Execute hardware step
msg_no_lm:         db 'FATAL: 64-bit Long Mode not supported by CPU!', 0 ; Execute hardware step
