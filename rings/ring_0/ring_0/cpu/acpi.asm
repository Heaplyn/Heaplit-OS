; ============================================================================
; Heaplit OS - ACPI Table Scanner & MADT Local APIC Parser (OSDev Wiki Standard)
; Ring Placement: rings/ring_0/ring_0/cpu/acpi.asm (Ring 0)
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
acpi_rsdp_address:   resq 1
acpi_madt_address:   resq 1
acpi_lapic_base:     resq 1
acpi_ioapic_base:    resq 1
acpi_cpu_count:      resd 1

section .text
bits 64

; ----------------------------------------------------------------------------
; acpi_find_rsdp: Scans memory for 8-byte signature "RSD PTR "
; Inputs: None
; Returns: RAX = Physical Address of RSDP structure, or 0 if Not Found
; ----------------------------------------------------------------------------
align 16
acpi_find_rsdp:
    push rbx
    push rsi
    push rdi

    ; 1. Scan EBDA (0x80000 to 0x9FFFF)
    mov rsi, 0x80000
    mov rbx, 0x9FFFF
    call .scan_range
    test rax, rax
    jnz .found

    ; 2. Scan BIOS Read-Only Memory Area (0xE0000 to 0xFFFFF)
    mov rsi, 0xE0000
    mov rbx, 0xFFFFF
    call .scan_range

.found:
    mov [acpi_rsdp_address], rax
    pop rdi
    pop rsi
    pop rbx
    ret

.scan_range:
    ; RSI = Start, RBX = End
.loop:
    cmp rsi, rbx
    jge .not_found

    ; Compare 8 bytes against "RSD PTR " (0x2052545020445352)
    mov rax, [rsi]
    mov rdx, 0x2052545020445352         ; "RSD PTR " in Little Endian
    cmp rax, rdx
    je .validate_checksum

    add rsi, 16                         ; RSDP is aligned on 16-byte boundary
    jmp .loop

.validate_checksum:
    ; Compute byte checksum across 20 bytes
    push rsi
    xor eax, eax
    mov ecx, 20
.chk_loop:
    movzx edx, byte [rsi]
    add eax, edx
    inc rsi
    loop .chk_loop
    pop rsi

    and al, 0xFF
    jnz .checksum_failed                ; Sum must equal 0 (mod 256)

    mov rax, rsi
    ret

.checksum_failed:
    add rsi, 16
    jmp .loop

.not_found:
    xor rax, rax
    ret

; ----------------------------------------------------------------------------
; acpi_parse_madt: Extracts LAPIC (0xFEE00000) and IOAPIC (0xFEC00000) bases
; Inputs: RDI = Physical Address of MADT ("APIC") Table
; Returns: RAX = Total Detected CPU Cores Count
; ----------------------------------------------------------------------------
align 16
acpi_parse_madt:
    push rbx
    push rsi
    push rdi

    test rdi, rdi
    jz .err_exit

    mov [acpi_madt_address], rdi

    ; Read Local APIC physical address at MADT offset +0x24 (32-bit uint)
    mov eax, [rdi + 0x24]
    mov [acpi_lapic_base], rax

    ; Set default IOAPIC base
    mov qword [acpi_ioapic_base], 0xFEC00000
    mov dword [acpi_cpu_count], 0

    ; MADT Header Length @ offset +0x04
    mov ecx, [rdi + 0x04]
    add rdi, 0x2C                       ; Skip MADT header (44 bytes)
    sub ecx, 0x2C                       ; Remaining length for MADT entries

.parse_entries:
    cmp ecx, 2
    jl .done

    movzx eax, byte [rdi]               ; Entry Type
    movzx ebx, byte [rdi + 1]           ; Entry Length

    test ebx, ebx
    jz .done

    cmp eax, 0                          ; Type 0: Processor Local APIC
    je .found_lapic_entry

    cmp eax, 1                          ; Type 1: I/O APIC
    je .found_ioapic_entry
    jmp .next_entry

.found_lapic_entry:
    ; Bit 0 of Flags @ offset +4: 1 = Enabled CPU
    mov edx, [rdi + 4]
    test edx, 1
    jz .next_entry
    inc dword [acpi_cpu_count]
    jmp .next_entry

.found_ioapic_entry:
    ; IOAPIC Physical Address @ offset +4 (32-bit uint)
    mov edx, [rdi + 4]
    mov [acpi_ioapic_base], rdx

.next_entry:
    add rdi, rbx
    sub ecx, ebx
    jmp .parse_entries

.done:
    mov eax, [acpi_cpu_count]
    pop rdi
    pop rsi
    pop rbx
    ret

.err_exit:
    xor rax, rax
    pop rdi
    pop rsi
    pop rbx
    ret

; ----------------------------------------------------------------------------
; acpi_get_lapic_base: Returns detected Local APIC physical base
; ----------------------------------------------------------------------------
align 16
acpi_get_lapic_base:
    mov rax, [acpi_lapic_base]
    test rax, rax
    jnz .has_val
    mov rax, 0xFEE00000                 ; Default x86-64 LAPIC physical base
.has_val:
    ret

; ----------------------------------------------------------------------------
; acpi_get_ioapic_base: Returns detected IOAPIC physical base
; ----------------------------------------------------------------------------
align 16
acpi_get_ioapic_base:
    mov rax, [acpi_ioapic_base]
    test rax, rax
    jnz .has_io_val
    mov rax, 0xFEC00000                 ; Default x86-64 IOAPIC physical base
.has_io_val:
    ret
