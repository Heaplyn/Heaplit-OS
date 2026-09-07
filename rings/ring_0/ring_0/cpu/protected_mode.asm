; rings/ring_0/protected_mode.asm
; 32-bit Protected Mode Initialization & Long Mode CPUID Check

[bits 16]                               ; Execute instruction
enter_protected_mode:
    cli                                 ; 1. Disable all hardware interrupts
    lgdt [gdt_descriptor]               ; 2. Load Global Descriptor Table

    ; 3. Enable Protection Enable (PE) bit in CR0
    mov eax, cr0                        ; Copy value from cr0 to eax
    or al, 1                            ; Set bit 0 (CR0.PE)
    mov cr0, eax                        ; Copy value from eax to cr0

    ; 4. Far jump to flush 16-bit prefetch queue and load 32-bit CS (0x08)
    jmp CODE_SEG_32:protected_mode_entry_32 ; Execute instruction

; -----------------------------------------------------------------------------
; 32-bit Protected Mode Code Segment
; -----------------------------------------------------------------------------
[bits 32]                               ; Execute instruction
protected_mode_entry_32:
    ; 1. Reload data segment registers with 32-bit Data Selector (0x10)
    mov ax, DATA_SEG_32                 ; Copy value from DATA_SEG_32 to ax
    mov ds, ax                          ; Copy value from ax to ds
    mov es, ax                          ; Copy value from ax to es
    mov ss, ax                          ; Copy value from ax to ss
    mov fs, ax                          ; Copy value from ax to fs
    mov gs, ax                          ; Copy value from ax to gs
    mov esp, 0x90000                    ; Set 32-bit stack pointer safely at 0x90000

    ; 2. Output 32-bit status string directly to VGA text buffer at 0xB8000
    mov esi, msg_pm32_active            ; Copy value from msg_pm32_active to esi
    mov edi, 0xB8000 + (10 * 80 * 2)    ; Row 10, Col 0
    call print_string_32                ; Execute instruction

    ; 3. Verify CPUID support
    call check_cpuid_32                 ; Execute instruction
    test eax, eax                       ; Execute instruction
    jz .no_cpuid                        ; Jump to .no_cpuid if condition 'z' is met

    ; 4. Verify 64-bit Long Mode capability via Extended CPUID
    call check_long_mode_32             ; Execute instruction
    test eax, eax                       ; Execute instruction
    jz .no_long_mode                    ; Jump to .no_long_mode if condition 'z' is met

    mov esi, msg_lm_supported           ; Copy value from msg_lm_supported to esi
    mov edi, 0xB8000 + (11 * 80 * 2)    ; Row 11, Col 0
    call print_string_32                ; Execute instruction

    ; 5. Initialize 4-Level Paging (PML4) & Enable Long Mode in MSR
    call setup_paging_32                ; Execute instruction

    ; 6. Far jump into 64-bit Long Mode Code Segment (0x18)
    jmp CODE_SEG_64:long_mode_entry_64  ; Execute instruction

.no_cpuid:
    mov esi, msg_no_cpuid               ; Copy value from msg_no_cpuid to esi
    mov edi, 0xB8000 + (12 * 80 * 2)    ; Execute instruction
    call print_string_32                ; Execute instruction
    cli                                 ; Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ; Halt CPU execution until next hardware interrupt
    jmp $                               ; Execute instruction

.no_long_mode:
    mov esi, msg_no_lm                  ; Copy value from msg_no_lm to esi
    mov edi, 0xB8000 + (12 * 80 * 2)    ; Execute instruction
    call print_string_32                ; Execute instruction
    cli                                 ; Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ; Halt CPU execution until next hardware interrupt
    jmp $                               ; Execute instruction

; -----------------------------------------------------------------------------
; check_cpuid_32: Checks if CPUID instruction is supported via EFLAGS ID bit (21).
; Returns: EAX = 1 if supported, EAX = 0 if not
; -----------------------------------------------------------------------------
check_cpuid_32:
    pushfd                              ; Execute instruction
    pop eax                             ; Pop top stack value into EAX register
    mov ecx, eax                        ; Copy value from eax to ecx
    xor eax, 1 << 21                    ; Flip ID bit
    push eax                            ; Push EAX register onto memory stack
    popfd                               ; Execute instruction
    pushfd                              ; Execute instruction
    pop eax                             ; Pop top stack value into EAX register
    push ecx                            ; Push ECX register onto memory stack
    popfd                               ; Restore original EFLAGS
    xor eax, ecx                        ; Execute instruction
    jz .not_supported                   ; Jump to .not_supported if condition 'z' is met
    mov eax, 1                          ; Copy value from 1 to eax
    ret                                 ; Return control to caller instruction pointer
.not_supported:
    xor eax, eax                        ; Zero out EAX register
    ret                                 ; Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; check_long_mode_32: Checks CPUID extended function 0x80000001 for LM bit (29).
; Returns: EAX = 1 if Long Mode supported, EAX = 0 if not
; -----------------------------------------------------------------------------
check_long_mode_32:
    mov eax, 0x80000000                 ; Copy value from 0x80000000 to eax
    cpuid                               ; Execute instruction
    cmp eax, 0x80000001                 ; Compare eax with 0x80000001 and update CPU EFLAGS
    jb .no_lm                           ; Jump to .no_lm if condition 'b' is met

    mov eax, 0x80000001                 ; Copy value from 0x80000001 to eax
    cpuid                               ; Execute instruction
    test edx, 1 << 29                   ; Long Mode bit in EDX
    jz .no_lm                           ; Jump to .no_lm if condition 'z' is met
    mov eax, 1                          ; Copy value from 1 to eax
    ret                                 ; Return control to caller instruction pointer
.no_lm:
    xor eax, eax                        ; Zero out EAX register
    ret                                 ; Return control to caller instruction pointer

msg_pm32_active:   db 'Heaplit OS: 32-bit Protected Mode Active.', 0 ; Execute instruction
msg_lm_supported:  db 'Hardware CPUID: 64-bit Long Mode Verified Supported.', 0 ; Execute instruction
msg_no_cpuid:      db 'FATAL: CPUID not supported by CPU!', 0 ; Execute instruction
msg_no_lm:         db 'FATAL: 64-bit Long Mode not supported by CPU!', 0 ; Execute instruction
