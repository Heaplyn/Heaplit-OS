; rings/ring_0/paging.asm
; 4-Level Paging Setup (PML4) for 64-bit Long Mode Transition
[bits 32]                               ; Execute instruction

; Fixed physical memory addresses for initial page tables
pml4_table equ 0x1000                   ; Execute instruction
pdpt_table equ 0x2000                   ; Execute instruction
pd_table   equ 0x3000                   ; Execute instruction

; -----------------------------------------------------------------------------
; setup_paging_32: Builds PML4, PDPT, and PD tables with 2MB huge pages.
; -----------------------------------------------------------------------------
setup_paging_32:
    pusha                               ; Execute instruction

    ; 1. Clear 12KB page table memory buffer at 0x1000 - 0x3FFF
    mov edi, pml4_table                 ; Copy value from pml4_table to edi
    mov ecx, 3 * 1024                   ; 3 tables * 1024 dwords (12KB total)
    xor eax, eax                        ; Zero out EAX register
    rep stosd                           ; Execute instruction

    ; 2. Link PML4 entry 0 (Identity Map) and entry 511 (Higher Half) to PDPT
    mov eax, pdpt_table                 ; Copy value from pdpt_table to eax
    or eax, 0x03                        ; Present(1) | Read/Write(1)
    mov [pml4_table], eax               ; PML4[0] -> PDPT
    mov [pml4_table + 511 * 8], eax     ; PML4[511] -> PDPT (Higher-Half 0xFFFFFFFF80000000)

    ; 3. Link PDPT entry 0 and entry 510 to Page Directory (PD)
    mov eax, pd_table                   ; Copy value from pd_table to eax
    or eax, 0x03                        ; Present(1) | Read/Write(1)
    mov [pdpt_table], eax               ; PDPT[0] -> PD
    mov [pdpt_table + 510 * 8], eax     ; PDPT[510] -> PD

    ; 4. Identity map first 1GB of physical RAM using 512 2MB huge pages
    mov ecx, 0                          ; Entry index (0..511)
.map_pd_loop:
    mov eax, 0x200000                   ; 2MB per page
    mul ecx                             ; EAX = ecx * 2MB physical base address
    or eax, 0x83                        ; Present(1) | Read/Write(1) | PageSize_2MB(1)
    mov [pd_table + ecx * 8], eax       ; Copy value from eax to [pd_table + ecx * 8]
    mov dword [pd_table + ecx * 8 + 4], 0 ; Upper 32 bits = 0
    inc ecx                             ; Increment ecx by 1
    cmp ecx, 512                        ; Compare ecx with 512 and update CPU EFLAGS
    jne .map_pd_loop                    ; Jump to .map_pd_loop if condition 'ne' is met

    ; 5. Load CR3 with PML4 Base Address (0x1000)
    mov eax, pml4_table                 ; Copy value from pml4_table to eax
    mov cr3, eax                        ; Copy value from eax to cr3

    ; 6. Enable PAE (Physical Address Extension) in CR4
    mov eax, cr4                        ; Copy value from cr4 to eax
    or eax, 1 << 5                      ; CR4.PAE = 1
    mov cr4, eax                        ; Copy value from eax to cr4

    ; 7. Set Long Mode Enable (LME) in IA32_EFER MSR (0xC0000080)
    mov ecx, 0xC0000080                 ; IA32_EFER
    rdmsr                               ; Read Model Specific Register (ECX -> EDX:EAX)
    or eax, 1 << 8                      ; EFER.LME = 1
    wrmsr                               ; Write Model Specific Register (EDX:EAX -> ECX)

    ; 8. Enable Paging (PG) and Protection (PE) in CR0
    mov eax, cr0                        ; Copy value from cr0 to eax
    or eax, (1 << 31) | (1 << 0)        ; CR0.PG = 1, CR0.PE = 1
    mov cr0, eax                        ; Copy value from eax to cr0

    popa                                ; Execute instruction
    ret                                 ; Return control to caller instruction pointer
