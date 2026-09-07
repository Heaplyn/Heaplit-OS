; rings/ring_0/cpu/long_mode.asm
; 64-bit Long Mode Entry Point & Hardware Ring 3 Transition
[bits 64]                               ; Execute instruction

long_mode_entry_64:
    ; 1. Reload 64-bit kernel data segment registers (0x20)
    mov ax, DATA_SEG_64                 ; Copy value from DATA_SEG_64 to ax
    mov ds, ax                          ; Copy value from ax to ds
    mov es, ax                          ; Copy value from ax to es
    mov ss, ax                          ; Copy value from ax to ss
    mov fs, ax                          ; Copy value from ax to fs
    mov gs, ax                          ; Copy value from ax to gs
    mov rsp, 0x90000                    ; Set 64-bit kernel stack pointer

    ; 2. Output 64-bit confirmation message to VGA text buffer
    mov rsi, msg_lm64_active            ; Copy value from msg_lm64_active to rsi
    mov rdi, 0xB8000 + (13 * 80 * 2)    ; Row 13, Col 0
    call print_string_64                ; Execute instruction

    ; 3. Output Ring 0 Supervisor message
    mov rsi, msg_kernel_supervisor      ; Copy value from msg_kernel_supervisor to rsi
    mov rdi, 0xB8000 + (14 * 80 * 2)    ; Row 14, Col 0
    call print_string_64                ; Execute instruction

    ; 4. Transition CPU privilege level to Ring 3 (Userland Mode)
    jmp enter_ring_3                    ; Unconditional jump to target label enter_ring_3

; -----------------------------------------------------------------------------
; enter_ring_3: Transitions CPU privilege level from Ring 0 to Ring 3 (Userland).
; Uses iretq with User Code (0x33) and User Data (0x2B) selectors.
; -----------------------------------------------------------------------------
enter_ring_3:
    ; 1. Load user data segment selectors (0x28 | 3 = 0x2B)
    mov ax, USER_DATA_64                ; Copy value from USER_DATA_64 to ax
    mov ds, ax                          ; Copy value from ax to ds
    mov es, ax                          ; Copy value from ax to es
    mov fs, ax                          ; Copy value from ax to fs
    mov gs, ax                          ; Copy value from ax to gs

    ; 2. Construct 64-bit iretq stack frame
    push USER_DATA_64                   ; SS: User Data Segment
    push 0x80000                        ; RSP: Userland Stack Pointer
    push 0x202                          ; RFLAGS: Interrupts enabled (IF=1)
    push USER_CODE_64                   ; CS: User Code Segment (0x30 | 3 = 0x33)
    push ring_3_userland_entry          ; RIP: Target Userland Entry Point
    iretq                               ; Execute instruction

; -----------------------------------------------------------------------------
; print_string_64: Writes null-terminated ASCII string to VGA text buffer.
; Inputs: RSI = String pointer, RDI = Framebuffer offset (e.g. 0xB8000)
; -----------------------------------------------------------------------------
print_string_64:
    push rax                            ; Preserve RAX accumulator register on stack
    push rdx                            ; Preserve RDX data register on stack
    push rsi                            ; Preserve RSI source register on stack
    push rdi                            ; Preserve RDI destination register on stack
    mov rdx, 0x0F                       ; White on black color attribute

.loop:
    mov al, byte [rsi]                  ; Copy value from byte [rsi] to al
    test al, al                         ; Execute instruction
    jz .done                            ; Jump to .done if condition 'z' is met
    mov byte [rdi], al                  ; Copy value from al to byte [rdi]
    mov byte [rdi + 1], dl              ; Copy value from dl to byte [rdi + 1]
    inc rsi                             ; Increment rsi by 1
    add rdi, 2                          ; Execute instruction
    jmp .loop                           ; Unconditional jump to target label .loop

.done:
    pop rdi                             ; Restore RDI destination register from stack
    pop rsi                             ; Restore RSI source register from stack
    pop rdx                             ; Restore RDX data register from stack
    pop rax                             ; Restore RAX accumulator register from stack
    ret                                 ; Return control to caller instruction pointer

msg_lm64_active:         db 'Heaplit OS: 64-bit Long Mode Successfully Entered!', 0 ; Execute instruction
msg_kernel_supervisor:   db 'Supervisor: Ring 0 Metal Core Online. Preparing Ring 3...', 0 ; Execute instruction

; Include Ring 3 Userland Entrypoint Module
%include "../../ring_3/userland/entry.asm" ; Execute instruction
