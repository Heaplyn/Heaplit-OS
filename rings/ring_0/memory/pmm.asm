; ============================================================================
; Heaplit OS - Physical Memory Allocator (PMM)
; Ring Placement: rings/ring_0/memory/pmm.asm (Ring 0)
; Description: 4KB page frame bitmap allocator supporting up to 512 GB RAM
;              using Bit Scan Forward (bsf) and atomic Bit Test and Set (lock bts).
; ============================================================================

global pmm_init
global pmm_alloc_page
global pmm_free_page
global pmm_get_free_count

section .bss
align 64
pmm_bitmap:         resb 16384 * 1024   ;16MB bitmap managing 512GB (134,217,728 pages)
pmm_total_pages:    resq 1              ; Execute hardware step
pmm_free_pages:     resq 1              ; Execute hardware step
pmm_last_searched:  resq 1              ; Execute hardware step

section .text
bits 64

; ----------------------------------------------------------------------------
; pmm_init: Initializes the PMM bitmap
; Inputs: RDI = Total Physical Memory Size in Bytes
; Returns: RAX = 0 on Success, -1 on Error
; ----------------------------------------------------------------------------
align 16
pmm_init:
    push rbp                            ;Save caller frame pointer to stack
    mov rbp, rsp                        ;Establish new stack frame base address

    ; Calculate total 4KB pages: (Size / 4096)
    shr rdi, 12                         ;Shift RDI right by 12 bits (divide by 4096)
    mov [pmm_total_pages], rdi          ; Set [pmm_total_pages] = rdi
    mov [pmm_free_pages], rdi           ; Set [pmm_free_pages] = rdi
    mov qword [pmm_last_searched], 0    ; Set qword [pmm_last_searched] = 0

    ; Zero out the bitmap (all pages free initially)
    mov rdi, pmm_bitmap                 ; Pass destination memory address 'pmm_bitmap' in RDI (System V ABI Arg 1)
    mov rcx, 16384 * 1024 / 8           ; Move value into target register/memory
    xor rax, rax                        ;Zero out RAX register
    rep stosq                           ;Repeat STOSQ to zero-fill memory quadwords via RCX/RDI

    xor rax, rax                        ;Zero out RAX register
    pop rbp                             ;Restore caller stack frame base address
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; pmm_alloc_page: Allocates a single 4KB physical page frame
; Inputs: None
; Returns: RAX = Physical Address of page, or 0 if Out of Memory
; ----------------------------------------------------------------------------
align 16
pmm_alloc_page:
    push rbp                            ;Save caller frame pointer to stack
    mov rbp, rsp                        ;Establish new stack frame base address
    push rbx                            ;Preserve non-volatile RBX register on stack

    mov rbx, [pmm_last_searched]        ; Set rbx = [pmm_last_searched]
    mov rcx, [pmm_total_pages]          ; Set rcx = [pmm_total_pages]

.search_loop:
    cmp rbx, rcx                        ; Execute hardware step
    jge .wrap_around                    ; Branch to '.wrap_around' if Greater or Equal

    ; Check bit in bitmap
    lock bts [pmm_bitmap], rbx          ;Execute atomic Bit Test and Set with bus lock
    jnc .found_free                     ;Carry flag = 0 means bit was 0 (free)

    inc rbx                             ;Increment rbx by 1
    jmp .search_loop                    ;Unconditional jump to target label .search_loop

.wrap_around:
    cmp qword [pmm_last_searched], 0    ; Execute hardware step
    je .out_of_memory                   ;Already searched full range
    mov qword [pmm_last_searched], 0    ; Set qword [pmm_last_searched] = 0
    xor rbx, rbx                        ;Zero out RBX register
    jmp .search_loop                    ;Unconditional jump to target label .search_loop

.found_free:
    mov [pmm_last_searched], rbx        ; Set [pmm_last_searched] = rbx
    dec qword [pmm_free_pages]          ;Decrement qword [pmm_free_pages] by 1

    ; Physical Address = rbx * 4096 (rbx << 12)
    mov rax, rbx                        ; Set rax = rbx
    shl rax, 12                         ;Shift RAX left by 12 bits (multiply by 4096)

    pop rbx                             ;Restore non-volatile RBX register from stack
    pop rbp                             ;Restore caller stack frame base address
    ret                                 ;Return control to caller instruction pointer

.out_of_memory:
    xor rax, rax                        ;Return NULL (0)
    pop rbx                             ;Restore non-volatile RBX register from stack
    pop rbp                             ;Restore caller stack frame base address
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; pmm_free_page: Frees a previously allocated 4KB physical page
; Inputs: RDI = Physical Base Address of page to free
; Returns: None
; ----------------------------------------------------------------------------
align 16
pmm_free_page:
    push rbp                            ;Save caller frame pointer to stack
    mov rbp, rsp                        ;Establish new stack frame base address

    ; Page Index = Physical Address / 4096
    shr rdi, 12                         ;Shift RDI right by 12 bits (divide by 4096)

    ; Clear bit atomically
    lock btr [pmm_bitmap], rdi          ;Execute atomic Bit Test and Reset with bus lock
    inc qword [pmm_free_pages]          ;Increment qword [pmm_free_pages] by 1

    pop rbp                             ;Restore caller stack frame base address
    ret                                 ;Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; pmm_get_free_count: Returns number of free 4KB physical pages
; Inputs: None
; Returns: RAX = Free Page Count
; ----------------------------------------------------------------------------
align 16
pmm_get_free_count:
    mov rax, [pmm_free_pages]           ; Set rax = [pmm_free_pages]
    ret                                 ;Return control to caller instruction pointer
