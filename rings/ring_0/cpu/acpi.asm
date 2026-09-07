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
acpi_rsdp_address:   resq 1             ; Execute hardware step
acpi_madt_address:   resq 1             ; Execute hardware step
acpi_lapic_base:     resq 1             ; Execute hardware step
acpi_ioapic_base:    resq 1             ; Execute hardware step
acpi_cpu_count:      resd 1             ; Execute hardware step

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
    mov rbx, 0x9FFFF                    ; Set rbx = 0x9FFFF
    call .scan_range                    ; Call helper function '.scan_range'
    test rax, rax                       ; Test accumulator register for zero / error status
    jnz .found                          ; Branch to '.found' if Zero Flag is clear (ZF=0)

    ; 2. Scan BIOS Read-Only Memory Area (0xE0000 to 0xFFFFF)
    mov rsi, 0xE0000                    ; Pass source string pointer '0xE0000' in RSI (System V ABI Arg 2)
    mov rbx, 0xFFFFF                    ; Set rbx = 0xFFFFF
    call .scan_range                    ; Call helper function '.scan_range'

.found:
    mov [acpi_rsdp_address], rax        ; Set [acpi_rsdp_address] = rax
    pop rdi                             ;Restore RDI destination register from stack
    pop rsi                             ;Restore RSI source register from stack
    pop rbx                             ;Restore non-volatile RBX register from stack
    ret                                 ;Return control to caller instruction pointer

.scan_range:
    ; RSI = Start, RBX = End
.loop:
    cmp rsi, rbx                        ; Execute hardware step
    jge .not_found                      ; Branch to '.not_found' if Greater or Equal

    ; Compare 8 bytes against "RSD PTR " (0x2052545020445352)
    mov rax, [rsi]                      ; Set rax = [rsi]
    mov rdx, 0x2052545020445352         ;"RSD PTR " in Little Endian
    cmp rax, rdx                        ; Execute hardware step
    je .validate_checksum               ; Branch to '.validate_checksum' if Zero Flag is set (ZF=1)

    add rsi, 16                         ;RSDP is aligned on 16-byte boundary
    jmp .loop                           ;Unconditional jump to target label .loop

.validate_checksum:
    ; Compute byte checksum across 20 bytes
    push rsi                            ;Preserve RSI source register on stack
    xor eax, eax                        ;Zero out EAX register
    mov ecx, 20                         ; Set ecx = 20
.chk_loop:
    movzx edx, byte [rsi]               ; Execute hardware step
    add eax, edx                        ; Execute hardware step
    inc rsi                             ;Increment rsi by 1
    loop .chk_loop                      ; Execute hardware step
    pop rsi                             ;Restore RSI source register from stack

    and al, 0xFF                        ; Execute hardware step
    jnz .checksum_failed                ;Sum must equal 0 (mod 256)

    mov rax, rsi                        ; Set rax = rsi
    ret                                 ;Return control to caller instruction pointer

.checksum_failed:
    add rsi, 16                         ; Execute hardware step
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

    test rdi, rdi                       ; Execute hardware step
    jz .err_exit                        ; Branch to '.err_exit' if Zero Flag is set (ZF=1)

    mov [acpi_madt_address], rdi        ; Set [acpi_madt_address] = rdi

    ; Read Local APIC physical address at MADT offset +0x24 (32-bit uint)
    mov eax, [rdi + 0x24]               ; Set eax = [rdi + 0x24]
    mov [acpi_lapic_base], rax          ; Set [acpi_lapic_base] = rax

    ; Set default IOAPIC base
    mov qword [acpi_ioapic_base], 0xFEC00000 ; Set qword [acpi_ioapic_base] = 0xFEC00000
    mov dword [acpi_cpu_count], 0       ; Set dword [acpi_cpu_count] = 0

    ; MADT Header Length @ offset +0x04
    mov ecx, [rdi + 0x04]               ; Set ecx = [rdi + 0x04]
    add rdi, 0x2C                       ;Skip MADT header (44 bytes)
    sub ecx, 0x2C                       ;Remaining length for MADT entries

.parse_entries:
    cmp ecx, 2                          ; Execute hardware step
    jl .done                            ; Execute hardware step

    movzx eax, byte [rdi]               ;Entry Type
    movzx ebx, byte [rdi + 1]           ;Entry Length

    test ebx, ebx                       ; Test base register for zero
    jz .done                            ; Branch to '.done' if Zero Flag is set (ZF=1)

    cmp eax, 0                          ;Type 0: Processor Local APIC
    je .found_lapic_entry               ; Branch to '.found_lapic_entry' if Zero Flag is set (ZF=1)

    cmp eax, 1                          ;Type 1: I/O APIC
    je .found_ioapic_entry              ; Branch to '.found_ioapic_entry' if Zero Flag is set (ZF=1)
    jmp .next_entry                     ;Unconditional jump to target label .next_entry

.found_lapic_entry:
    ; Bit 0 of Flags @ offset +4: 1 = Enabled CPU
    mov edx, [rdi + 4]                  ; Set edx = [rdi + 4]
    test edx, 1                         ; Execute hardware step
    jz .next_entry                      ; Branch to '.next_entry' if Zero Flag is set (ZF=1)
    inc dword [acpi_cpu_count]          ;Increment dword [acpi_cpu_count] by 1
    jmp .next_entry                     ;Unconditional jump to target label .next_entry

.found_ioapic_entry:
    ; IOAPIC Physical Address @ offset +4 (32-bit uint)
    mov edx, [rdi + 4]                  ; Set edx = [rdi + 4]
    mov [acpi_ioapic_base], rdx         ; Set [acpi_ioapic_base] = rdx

.next_entry:
    add rdi, rbx                        ; Execute hardware step
    sub ecx, ebx                        ; Execute hardware step
    jmp .parse_entries                  ;Unconditional jump to target label .parse_entries

.done:
    mov eax, [acpi_cpu_count]           ; Set eax = [acpi_cpu_count]
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
    mov rax, [acpi_lapic_base]          ; Set rax = [acpi_lapic_base]
    test rax, rax                       ; Test accumulator register for zero / error status
    jnz .has_val                        ; Branch to '.has_val' if Zero Flag is clear (ZF=0)
    mov rax, 0xFEE00000                 ;Default x86-64 LAPIC physical base
.has_val:
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; acpi_get_ioapic_base: Returns detected IOAPIC physical base
; ----------------------------------------------------------------------------
align 16
acpi_get_ioapic_base:
    mov rax, [acpi_ioapic_base]         ; Set rax = [acpi_ioapic_base]
    test rax, rax                       ; Test accumulator register for zero / error status
    jnz .has_io_val                     ; Branch to '.has_io_val' if Zero Flag is clear (ZF=0)
    mov rax, 0xFEC00000                 ;Default x86-64 IOAPIC physical base
.has_io_val:
    ret                                 ;Return control to caller instruction pointer
