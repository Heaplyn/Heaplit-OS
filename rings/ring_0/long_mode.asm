; rings/ring_0/long_mode.asm
; 64-bit Long Mode Entry Point & Hardware Ring 3 Transition

[bits 64]
long_mode_entry_64:
    ; 1. Reload 64-bit kernel data segment registers (0x20)
    mov ax, DATA_SEG_64
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000            ; Set 64-bit kernel stack pointer

    ; 2. Output 64-bit confirmation message to VGA text buffer
    mov rsi, msg_lm64_active
    mov rdi, 0xB8000 + (13 * 80 * 2) ; Row 13, Col 0
    call print_string_64

    ; 3. Output Ring 0 Supervisor message
    mov rsi, msg_kernel_supervisor
    mov rdi, 0xB8000 + (14 * 80 * 2) ; Row 14, Col 0
    call print_string_64

    ; 4. Transition CPU privilege level to Ring 3 (Userland Mode)
    jmp enter_ring_3

; -----------------------------------------------------------------------------
; enter_ring_3: Transitions CPU privilege level from Ring 0 to Ring 3 (Userland).
; Uses iretq with User Code (0x33) and User Data (0x2B) selectors.
; -----------------------------------------------------------------------------
enter_ring_3:
    ; 1. Load user data segment selectors (0x28 | 3 = 0x2B)
    mov ax, USER_DATA_64
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; 2. Construct 64-bit iretq stack frame
    push USER_DATA_64           ; SS: User Data Segment
    push 0x80000                ; RSP: Userland Stack Pointer
    push 0x202                  ; RFLAGS: Interrupts enabled (IF=1)
    push USER_CODE_64           ; CS: User Code Segment (0x30 | 3 = 0x33)
    push ring_3_userland_entry  ; RIP: Target Userland Entry Point
    iretq

; -----------------------------------------------------------------------------
; ring_3_userland_entry: First code executing with CPL = 3 (Ring 3 Userland)
; -----------------------------------------------------------------------------
ring_3_userland_entry:
    ; Display confirmation that Ring 3 Userland is active
    mov rsi, msg_ring3_active
    mov rdi, 0xB8000 + (15 * 80 * 2) ; Row 15, Col 0
    call print_string_64

.userland_loop:
    pause
    jmp .userland_loop

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
msg_kernel_supervisor:   db 'Supervisor: Ring 0 Metal Core Online. Preparing Ring 3...', 0
msg_ring3_active:        db 'Heaplit OS: Hardware Ring 3 (Userland CPL=3) Active!', 0
