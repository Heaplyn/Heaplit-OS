; ============================================================================
; Heaplit OS - ACPI Table Scanner & MADT Local APIC Parser (OSDev Wiki Standard)
; Ring Placement: rings/ring_0/cpu/acpi.asm (Ring 0)
; Description: Scans BIOS EBDA (0x80000-0x9FFFF) and ROM (0xE0000-0xFFFFF) for
;              RSDP ("RSD PTR "), parses XSDT/RSDT, and extracts Local APIC
;              base (0xFEE00000) and IOAPIC base (0xFEC00000) from MADT.
; ============================================================================

global acpi_find_rsdp
global acpi_parse_madt
global acpi_get_lapic_base
global acpi_get_ioapic_base

section .bss
align 16
acpi_rsdp_address:   resq 1             ; Execute instruction
acpi_madt_address:   resq 1             ; Execute instruction
acpi_lapic_base:     resq 1             ; Execute instruction
acpi_ioapic_base:    resq 1             ; Execute instruction
acpi_cpu_count:      resd 1             ; Execute instruction

section .text
bits 64

; ----------------------------------------------------------------------------
; acpi_find_rsdp: Scans memory for 8-byte signature "RSD PTR "
; Inputs: None
; Returns: RAX = Physical Address of RSDP structure, or 0 if Not Found
; ----------------------------------------------------------------------------
align 16
acpi_find_rsdp:
    push rbx                            ;Preserve non-volatile RBX register on stack
    push rsi                            ;Preserve RSI source register on stack
    push rdi                            ;Preserve RDI destination register on stack

    ; 1. Scan EBDA (0x80000 to 0x9FFFF)
    mov rsi, 0x80000                    ; Pass source string pointer '0x80000' in RSI (System V ABI Arg 2)
    mov rbx, 0x9FFFF                    ; Copy value from 0x9FFFF to rbx
    call .scan_range                    ; Execute instruction
    test rax, rax                       ; Execute instruction
    jnz .found                          ;Jump to .found if condition 'nz' is met

    ; 2. Scan BIOS Read-Only Memory Area (0xE0000 to 0xFFFFF)
    mov rsi, 0xE0000                    ; Pass source string pointer '0xE0000' in RSI (System V ABI Arg 2)
    mov rbx, 0xFFFFF                    ; Copy value from 0xFFFFF to rbx
    call .scan_range                    ; Execute instruction

.found:
    mov [acpi_rsdp_address], rax        ; Copy value from rax to [acpi_rsdp_address]
    pop rdi                             ;Restore RDI destination register from stack
    pop rsi                             ;Restore RSI source register from stack
    pop rbx                             ;Restore non-volatile RBX register from stack
    ret                                 ;Return control to caller instruction pointer

.scan_range:
    ; RSI = Start, RBX = End
.loop:
    cmp rsi, rbx                        ;Compare rsi with rbx and update CPU EFLAGS
    jge .not_found                      ;Jump to .not_found if condition 'ge' is met

    ; Compare 8 bytes against "RSD PTR " (0x2052545020445352)
    mov rax, [rsi]                      ; Copy value from [rsi] to rax
    mov rdx, 0x2052545020445352         ;"RSD PTR " in Little Endian
    cmp rax, rdx                        ;Compare rax with rdx and update CPU EFLAGS
    je .validate_checksum               ;Jump to .validate_checksum if condition 'e' is met

    add rsi, 16                         ;RSDP is aligned on 16-byte boundary
    jmp .loop                           ;Unconditional jump to target label .loop

.validate_checksum:
    ; Compute byte checksum across 20 bytes
    push rsi                            ;Preserve RSI source register on stack
    xor eax, eax                        ;Zero out EAX register
    mov ecx, 20                         ; Copy value from 20 to ecx
.chk_loop:
    movzx edx, byte [rsi]               ; Execute instruction
    add eax, edx                        ; Execute instruction
    inc rsi                             ;Increment rsi by 1
    loop .chk_loop                      ; Execute instruction
    pop rsi                             ;Restore RSI source register from stack

    and al, 0xFF                        ; Execute instruction
    jnz .checksum_failed                ;Sum must equal 0 (mod 256)

    mov rax, rsi                        ; Copy value from rsi to rax
    ret                                 ;Return control to caller instruction pointer

.checksum_failed:
    add rsi, 16                         ; Execute instruction
    jmp .loop                           ;Unconditional jump to target label .loop

.not_found:
    xor rax, rax                        ;Zero out RAX register
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; acpi_parse_madt: Extracts LAPIC (0xFEE00000) and IOAPIC (0xFEC00000) bases
; Inputs: RDI = Physical Address of MADT ("APIC") Table
; Returns: RAX = Total Detected CPU Cores Count
; ----------------------------------------------------------------------------
align 16
acpi_parse_madt:
    push rbx                            ;Preserve non-volatile RBX register on stack
    push rsi                            ;Preserve RSI source register on stack
    push rdi                            ;Preserve RDI destination register on stack

    test rdi, rdi                       ; Execute instruction
    jz .err_exit                        ;Jump to .err_exit if condition 'z' is met

    mov [acpi_madt_address], rdi        ; Copy value from rdi to [acpi_madt_address]

    ; Read Local APIC physical address at MADT offset +0x24 (32-bit uint)
    mov eax, [rdi + 0x24]               ; Copy value from [rdi + 0x24] to eax
    mov [acpi_lapic_base], rax          ; Copy value from rax to [acpi_lapic_base]

    ; Set default IOAPIC base
    mov qword [acpi_ioapic_base], 0xFEC00000 ; Copy value from 0xFEC00000 to qword [acpi_ioapic_base]
    mov dword [acpi_cpu_count], 0       ; Copy value from 0 to dword [acpi_cpu_count]

    ; MADT Header Length @ offset +0x04
    mov ecx, [rdi + 0x04]               ; Copy value from [rdi + 0x04] to ecx
    add rdi, 0x2C                       ;Skip MADT header (44 bytes)
    sub ecx, 0x2C                       ;Remaining length for MADT entries

.parse_entries:
    cmp ecx, 2                          ;Compare ecx with 2 and update CPU EFLAGS
    jl .done                            ;Jump to .done if condition 'l' is met

    movzx eax, byte [rdi]               ;Entry Type
    movzx ebx, byte [rdi + 1]           ;Entry Length

    test ebx, ebx                       ; Execute instruction
    jz .done                            ;Jump to .done if condition 'z' is met

    cmp eax, 0                          ;Type 0: Processor Local APIC
    je .found_lapic_entry               ;Jump to .found_lapic_entry if condition 'e' is met

    cmp eax, 1                          ;Type 1: I/O APIC
    je .found_ioapic_entry              ;Jump to .found_ioapic_entry if condition 'e' is met
    jmp .next_entry                     ;Unconditional jump to target label .next_entry

.found_lapic_entry:
    ; Bit 0 of Flags @ offset +4: 1 = Enabled CPU
    mov edx, [rdi + 4]                  ; Copy value from [rdi + 4] to edx
    test edx, 1                         ; Execute instruction
    jz .next_entry                      ;Jump to .next_entry if condition 'z' is met
    inc dword [acpi_cpu_count]          ;Increment dword [acpi_cpu_count] by 1
    jmp .next_entry                     ;Unconditional jump to target label .next_entry

.found_ioapic_entry:
    ; IOAPIC Physical Address @ offset +4 (32-bit uint)
    mov edx, [rdi + 4]                  ; Copy value from [rdi + 4] to edx
    mov [acpi_ioapic_base], rdx         ; Copy value from rdx to [acpi_ioapic_base]

.next_entry:
    add rdi, rbx                        ; Execute instruction
    sub ecx, ebx                        ; Execute instruction
    jmp .parse_entries                  ;Unconditional jump to target label .parse_entries

.done:
    mov eax, [acpi_cpu_count]           ; Copy value from [acpi_cpu_count] to eax
    pop rdi                             ;Restore RDI destination register from stack
    pop rsi                             ;Restore RSI source register from stack
    pop rbx                             ;Restore non-volatile RBX register from stack
    ret                                 ;Return control to caller instruction pointer

.err_exit:
    xor rax, rax                        ;Zero out RAX register
    pop rdi                             ;Restore RDI destination register from stack
    pop rsi                             ;Restore RSI source register from stack
    pop rbx                             ;Restore non-volatile RBX register from stack
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; acpi_get_lapic_base: Returns detected Local APIC physical base
; ----------------------------------------------------------------------------
align 16
acpi_get_lapic_base:
    mov rax, [acpi_lapic_base]          ; Copy value from [acpi_lapic_base] to rax
    test rax, rax                       ; Execute instruction
    jnz .has_val                        ;Jump to .has_val if condition 'nz' is met
    mov rax, 0xFEE00000                 ;Default x86-64 LAPIC physical base
.has_val:
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; acpi_get_ioapic_base: Returns detected IOAPIC physical base
; ----------------------------------------------------------------------------
align 16
acpi_get_ioapic_base:
    mov rax, [acpi_ioapic_base]         ; Copy value from [acpi_ioapic_base] to rax
    test rax, rax                       ; Execute instruction
    jnz .has_io_val                     ;Jump to .has_io_val if condition 'nz' is met
    mov rax, 0xFEC00000                 ;Default x86-64 IOAPIC physical base
.has_io_val:
    ret                                 ;Return control to caller instruction pointer
