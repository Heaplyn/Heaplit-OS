; rings/ring_0/paging.asm
; 4-Level Paging Setup (PML4) for 64-bit Long Mode Transition
[bits 32]

; Fixed physical memory addresses for initial page tables
pml4_table equ 0x1000
pdpt_table equ 0x2000
pd_table   equ 0x3000

; -----------------------------------------------------------------------------
; setup_paging_32: Builds PML4, PDPT, and PD tables with 2MB huge pages.
; -----------------------------------------------------------------------------
setup_paging_32:
    pusha

    ; 1. Clear 12KB page table memory buffer at 0x1000 - 0x3FFF
    mov edi, pml4_table
    mov ecx, 3 * 1024           ; 3 tables * 1024 dwords (12KB total)
    xor eax, eax
    rep stosd

    ; 2. Link PML4 entry 0 (Identity Map) and entry 511 (Higher Half) to PDPT
    mov eax, pdpt_table
    or eax, 0x03                ; Present(1) | Read/Write(1)
    mov [pml4_table], eax       ; PML4[0] -> PDPT
    mov [pml4_table + 511 * 8], eax ; PML4[511] -> PDPT (Higher-Half 0xFFFFFFFF80000000)

    ; 3. Link PDPT entry 0 and entry 510 to Page Directory (PD)
    mov eax, pd_table
    or eax, 0x03                ; Present(1) | Read/Write(1)
    mov [pdpt_table], eax       ; PDPT[0] -> PD
    mov [pdpt_table + 510 * 8], eax ; PDPT[510] -> PD

    ; 4. Identity map first 1GB of physical RAM using 512 2MB huge pages
    mov ecx, 0                  ; Entry index (0..511)
.map_pd_loop:
    mov eax, 0x200000           ; 2MB per page
    mul ecx                     ; EAX = ecx * 2MB physical base address
    or eax, 0x83                ; Present(1) | Read/Write(1) | PageSize_2MB(1)
    mov [pd_table + ecx * 8], eax
    mov dword [pd_table + ecx * 8 + 4], 0 ; Upper 32 bits = 0
    inc ecx
    cmp ecx, 512
    jne .map_pd_loop

    ; 5. Load CR3 with PML4 Base Address (0x1000)
    mov eax, pml4_table
    mov cr3, eax

    ; 6. Enable PAE (Physical Address Extension) in CR4
    mov eax, cr4
    or eax, 1 << 5              ; CR4.PAE = 1
    mov cr4, eax

    ; 7. Set Long Mode Enable (LME) in IA32_EFER MSR (0xC0000080)
    mov ecx, 0xC0000080         ; IA32_EFER
    rdmsr
    or eax, 1 << 8              ; EFER.LME = 1
    wrmsr

    ; 8. Enable Paging (PG) and Protection (PE) in CR0
    mov eax, cr0
    or eax, (1 << 31) | (1 << 0) ; CR0.PG = 1, CR0.PE = 1
    mov cr0, eax

    popa
    ret
