; rings/ring_0/cpu/long_mode.asm
; =============================================================================
; 64-bit Long Mode Entry Point & Hardware Ring 3 Transition Dispatcher
; Ring Placement: rings/ring_0/cpu/long_mode.asm (Ring 0)
; =============================================================================
[bits 64]                               ;64-bit Long Mode Execution

extern enter_ring_3_transition

long_mode_entry_64:
    ; 1. Reload 64-bit kernel data segment registers (0x20)
    mov ax, DATA_SEG_64                 ; Copy value from DATA_SEG_64 to ax
    mov ds, ax                          ;Set DS = 0x20 (Kernel Data)
    mov es, ax                          ;Set ES = 0x20 (Kernel Data)
    mov ss, ax                          ;Set SS = 0x20 (Kernel Data)
    mov fs, ax                          ;Set FS = 0x20 (Kernel Data)
    mov gs, ax                          ;Set GS = 0x20 (Kernel Data)
    mov rsp, 0x90000                    ;Set 64-bit kernel stack pointer at 0x90000

    ; 2. Output 64-bit confirmation message to VGA text buffer
    mov rsi, msg_lm64_active            ; Pass source string pointer 'msg_lm64_active' in RSI (System V ABI Arg 2)
    mov rdi, 0xB8000 + (13 * 80 * 2)    ;Row 13, Col 0
    call print_string_64                ; Call subroutine 'print_string_64'

    ; 3. Output Ring 0 Supervisor message
    mov rsi, msg_kernel_supervisor      ; Pass source string pointer 'msg_kernel_supervisor' in RSI (System V ABI Arg 2)
    mov rdi, 0xB8000 + (14 * 80 * 2)    ;Row 14, Col 0
    call print_string_64                ; Call subroutine 'print_string_64'

    ; 4. Transition CPU privilege level to Ring 3 via dedicated Ring 3 transition module
    jmp enter_ring_3_transition         ;Jump to enter_ring_3_transition in ring3_transition.asm

; -----------------------------------------------------------------------------
; print_string_64: Writes null-terminated ASCII string to VGA text buffer.
; Inputs: RSI = String pointer, RDI = Framebuffer offset (e.g. 0xB8000)
; -----------------------------------------------------------------------------
print_string_64:
    push rax                            ;Preserve RAX accumulator register on stack
    push rdx                            ;Preserve RDX data register on stack
    push rsi                            ;Preserve RSI source register on stack
    push rdi                            ;Preserve RDI destination register on stack
    mov rdx, 0x0F                       ;White on black color attribute

.loop:
    mov al, byte [rsi]                  ; Copy value from byte [rsi] to al
    test al, al                         ;Test if AL == 0 (null terminator)
    jz .done                            ;Jump to .done if zero
    mov byte [rdi], al                  ;Write character byte to VGA memory
    mov byte [rdi + 1], dl              ;Write color attribute byte to VGA memory
    inc rsi                             ;Advance string pointer
    add rdi, 2                          ;Advance VGA buffer offset by 2 bytes
    jmp .loop                           ;Loop for next character

.done:
    pop rdi                             ;Restore RDI destination register from stack
    pop rsi                             ;Restore RSI source register from stack
    pop rdx                             ;Restore RDX data register from stack
    pop rax                             ;Restore RAX accumulator register from stack
    ret                                 ;Return control to caller instruction pointer

msg_lm64_active:         db 'Heaplit OS: 64-bit Long Mode Successfully Entered!', 0 ; Execute instruction
msg_kernel_supervisor:   db 'Supervisor: Ring 0 Metal Core Online. Preparing Ring 3...', 0 ; Execute instruction
