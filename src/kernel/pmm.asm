; src/kernel/pmm.asm
; Physical Memory Allocator (PMM) - 4KB Page Frame Bitmap for Heaplit OS
[bits 64]

global pmm_init
global pmm_alloc_page
global pmm_free_page

; -----------------------------------------------------------------------------
; pmm_init: Initializes the physical memory bitmap.
; Inputs: RDI = Pointer to memory map, RSI = Entry count
; -----------------------------------------------------------------------------
pmm_init:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdi

    ; Initialize bitmap to all allocated (1s)
    mov rdi, pmm_bitmap
    mov rcx, PMM_BITMAP_QWORDS
    mov rax, 0xFFFFFFFFFFFFFFFF
    rep stosq

    pop rdi
    pop rcx
    pop rbx
    pop rbp
    ret

; -----------------------------------------------------------------------------
; pmm_alloc_page: Allocates a single 4KB physical page frame.
; Returns: RAX = Physical Base Address of allocated frame (0 on OOM)
; -----------------------------------------------------------------------------
pmm_alloc_page:
    push rbx
    push rcx
    push rdx

    mov rcx, PMM_BITMAP_QWORDS
    mov rdi, pmm_bitmap
    xor rdx, rdx

.search_qword:
    cmp rdx, rcx
    jge .out_of_memory
    mov rax, [rdi + rdx * 8]
    cmp rax, 0xFFFFFFFFFFFFFFFF  ; Full qword?
    jne .found_free_slot
    inc rdx
    jmp .search_qword

.found_free_slot:
    not rax                     ; Invert: 1 becomes 0 (free bit)
    bsf rbx, rax                ; Find lowest set bit index (0..63)
    btr qword [rdi + rdx * 8], rbx ; Mark bit as 1 (allocated)

    ; Calculate physical address: (rdx * 64 + rbx) * 4096
    shl rdx, 6
    add rdx, rbx
    shl rdx, 12                 ; * 4096
    mov rax, rdx

    pop rdx
    pop rcx
    pop rbx
    ret

.out_of_memory:
    xor rax, rax                ; Return 0 (OOM)
    pop rdx
    pop rcx
    pop rbx
    ret

; -----------------------------------------------------------------------------
; pmm_free_page: Releases a previously allocated 4KB physical page frame.
; Inputs: RDI = Physical Address of page frame
; -----------------------------------------------------------------------------
pmm_free_page:
    push rbx
    push rdx

    shr rdi, 12                 ; Frame index (addr / 4096)
    mov rdx, rdi
    shr rdx, 6                  ; QWord index (frame / 64)
    and rdi, 63                 ; Bit index (frame % 64)

    mov rbx, pmm_bitmap
    btr qword [rbx + rdx * 8], rdi ; Clear bit to 0 (free)

    pop rdx
    pop rbx
    ret

PMM_BITMAP_QWORDS equ 4096      ; Tracks 1GB of physical RAM

align 4096
pmm_bitmap:
    times PMM_BITMAP_QWORDS dq 0
