; ============================================================================
; Heaplit OS - Physical Memory Allocator (PMM)
; Ring Placement: rings/ring_0/ring_0/memory/pmm.asm (Ring 0)
; Description: 4KB page frame bitmap allocator supporting up to 512 GB RAM
;              using Bit Scan Forward (bsf) and atomic Bit Test and Set (lock bts).
; ============================================================================

global pmm_init
global pmm_alloc_page
global pmm_free_page
global pmm_get_free_count

section .bss
align 64
pmm_bitmap:         resb 16384 * 1024   ; 16MB bitmap managing 512GB (134,217,728 pages)
pmm_total_pages:    resq 1
pmm_free_pages:     resq 1
pmm_last_searched:  resq 1

section .text
bits 64

; ----------------------------------------------------------------------------
; pmm_init: Initializes the PMM bitmap
; Inputs: RDI = Total Physical Memory Size in Bytes
; Returns: RAX = 0 on Success, -1 on Error
; ----------------------------------------------------------------------------
align 16
pmm_init:
    push rbp
    mov rbp, rsp

    ; Calculate total 4KB pages: (Size / 4096)
    shr rdi, 12
    mov [pmm_total_pages], rdi
    mov [pmm_free_pages], rdi
    mov qword [pmm_last_searched], 0

    ; Zero out the bitmap (all pages free initially)
    mov rdi, pmm_bitmap
    mov rcx, 16384 * 1024 / 8
    xor rax, rax
    rep stosq

    xor rax, rax
    pop rbp
    ret

; ----------------------------------------------------------------------------
; pmm_alloc_page: Allocates a single 4KB physical page frame
; Inputs: None
; Returns: RAX = Physical Address of page, or 0 if Out of Memory
; ----------------------------------------------------------------------------
align 16
pmm_alloc_page:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, [pmm_last_searched]
    mov rcx, [pmm_total_pages]

.search_loop:
    cmp rbx, rcx
    jge .wrap_around

    ; Check bit in bitmap
    lock bts [pmm_bitmap], rbx
    jnc .found_free                     ; Carry flag = 0 means bit was 0 (free)

    inc rbx
    jmp .search_loop

.wrap_around:
    cmp qword [pmm_last_searched], 0
    je .out_of_memory                   ; Already searched full range
    mov qword [pmm_last_searched], 0
    xor rbx, rbx
    jmp .search_loop

.found_free:
    mov [pmm_last_searched], rbx
    dec qword [pmm_free_pages]

    ; Physical Address = rbx * 4096 (rbx << 12)
    mov rax, rbx
    shl rax, 12

    pop rbx
    pop rbp
    ret

.out_of_memory:
    xor rax, rax                        ; Return NULL (0)
    pop rbx
    pop rbp
    ret

; ----------------------------------------------------------------------------
; pmm_free_page: Frees a previously allocated 4KB physical page
; Inputs: RDI = Physical Base Address of page to free
; Returns: None
; ----------------------------------------------------------------------------
align 16
pmm_free_page:
    push rbp
    mov rbp, rsp

    ; Page Index = Physical Address / 4096
    shr rdi, 12

    ; Clear bit atomically
    lock btr [pmm_bitmap], rdi
    inc qword [pmm_free_pages]

    pop rbp
    ret

; ----------------------------------------------------------------------------
; pmm_get_free_count: Returns number of free 4KB physical pages
; Inputs: None
; Returns: RAX = Free Page Count
; ----------------------------------------------------------------------------
align 16
pmm_get_free_count:
    mov rax, [pmm_free_pages]
    ret
