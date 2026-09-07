; rings/ring_0/long_mode.asm
; 64-bit Long Mode Entry Point & Kernel Initialization

[bits 64]
long_mode_entry_64:
    ; 1. Reload 64-bit data segment registers (0x20)
    mov ax, DATA_SEG_64
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000            ; Set 64-bit stack pointer

    ; 2. Output 64-bit confirmation message to VGA text buffer
    mov rsi, msg_lm64_active
    mov rdi, 0xB8000 + (13 * 80 * 2) ; Row 13, Col 0
    call print_string_64

    ; 3. Jump to 64-bit higher-half kernel supervisor
    mov rsi, msg_kernel_supervisor
    mov rdi, 0xB8000 + (14 * 80 * 2) ; Row 14, Col 0
    call print_string_64

    ; 4. Idle loop in 64-bit mode (Tickless sleep)
.kernel_idle_loop:
    hlt
    jmp .kernel_idle_loop

; -----------------------------------------------------------------------------
; print_string_64: Writes null-terminated ASCII string to VGA text buffer.
; Inputs: RSI = String pointer, RDI = Framebuffer offset (e.g. 0xB8000)
; -----------------------------------------------------------------------------
print_string_64:
    push rax
    push rdx
    push rsi
    push rdi
    mov rdx, 0x0F               ; White on black color attribute

.loop:
    mov al, byte [rsi]
    test al, al
    jz .done
    mov byte [rdi], al
    mov byte [rdi + 1], dl
    inc rsi
    add rdi, 2
    jmp .loop

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rax
    ret

msg_lm64_active:         db 'Heaplit OS: 64-bit Long Mode Successfully Entered!', 0
msg_kernel_supervisor:   db 'Supervisor: Ring 0 Metal Core Online. Entering Tickless Idle...', 0
