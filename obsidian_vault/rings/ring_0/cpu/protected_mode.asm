; rings/ring_0/protected_mode.asm
; 32-bit Protected Mode Initialization & Long Mode CPUID Check

[bits 16]
enter_protected_mode:
    cli                         ; 1. Disable all hardware interrupts
    lgdt [gdt_descriptor]       ; 2. Load Global Descriptor Table

    ; 3. Enable Protection Enable (PE) bit in CR0
    mov eax, cr0
    or al, 1                    ; Set bit 0 (CR0.PE)
    mov cr0, eax

    ; 4. Far jump to flush 16-bit prefetch queue and load 32-bit CS (0x08)
    jmp CODE_SEG_32:protected_mode_entry_32

; -----------------------------------------------------------------------------
; 32-bit Protected Mode Code Segment
; -----------------------------------------------------------------------------
[bits 32]
protected_mode_entry_32:
    ; 1. Reload data segment registers with 32-bit Data Selector (0x10)
    mov ax, DATA_SEG_32
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x90000            ; Set 32-bit stack pointer safely at 0x90000

    ; 2. Output 32-bit status string directly to VGA text buffer at 0xB8000
    mov esi, msg_pm32_active
    mov edi, 0xB8000 + (10 * 80 * 2) ; Row 10, Col 0
    call print_string_32

    ; 3. Verify CPUID support
    call check_cpuid_32
    test eax, eax
    jz .no_cpuid

    ; 4. Verify 64-bit Long Mode capability via Extended CPUID
    call check_long_mode_32
    test eax, eax
    jz .no_long_mode

    mov esi, msg_lm_supported
    mov edi, 0xB8000 + (11 * 80 * 2) ; Row 11, Col 0
    call print_string_32

    ; 5. Initialize 4-Level Paging (PML4) & Enable Long Mode in MSR
    call setup_paging_32

    ; 6. Far jump into 64-bit Long Mode Code Segment (0x18)
    jmp CODE_SEG_64:long_mode_entry_64

.no_cpuid:
    mov esi, msg_no_cpuid
    mov edi, 0xB8000 + (12 * 80 * 2)
    call print_string_32
    cli
    hlt
    jmp $

.no_long_mode:
    mov esi, msg_no_lm
    mov edi, 0xB8000 + (12 * 80 * 2)
    call print_string_32
    cli
    hlt
    jmp $

; -----------------------------------------------------------------------------
; check_cpuid_32: Checks if CPUID instruction is supported via EFLAGS ID bit (21).
; Returns: EAX = 1 if supported, EAX = 0 if not
; -----------------------------------------------------------------------------
check_cpuid_32:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21            ; Flip ID bit
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd                       ; Restore original EFLAGS
    xor eax, ecx
    jz .not_supported
    mov eax, 1
    ret
.not_supported:
    xor eax, eax
    ret

; -----------------------------------------------------------------------------
; check_long_mode_32: Checks CPUID extended function 0x80000001 for LM bit (29).
; Returns: EAX = 1 if Long Mode supported, EAX = 0 if not
; -----------------------------------------------------------------------------
check_long_mode_32:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_lm

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           ; Long Mode bit in EDX
    jz .no_lm
    mov eax, 1
    ret
.no_lm:
    xor eax, eax
    ret

msg_pm32_active:   db 'Heaplit OS: 32-bit Protected Mode Active.', 0
msg_lm_supported:  db 'Hardware CPUID: 64-bit Long Mode Verified Supported.', 0
msg_no_cpuid:      db 'FATAL: CPUID not supported by CPU!', 0
msg_no_lm:         db 'FATAL: 64-bit Long Mode not supported by CPU!', 0
