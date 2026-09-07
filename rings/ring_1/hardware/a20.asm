; rings/ring_0/ring_1/a20.asm
; A20 Gate Enable & Verification Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Execute instruction

; -----------------------------------------------------------------------------
; check_a20: Tests if address line 20 is active by testing memory wrap-around.
; Returns:
;   AX = 1 if enabled, AX = 0 if disabled
; Preserved:
;   BX, CX, DX, SI, DI, DS, ES
; -----------------------------------------------------------------------------
check_a20:
    pushf                               ; Execute instruction
    push ds                             ;Push DS register onto memory stack
    push es                             ;Push ES register onto memory stack
    push di                             ;Push DI register onto memory stack
    push si                             ;Push SI register onto memory stack
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)

    xor ax, ax                          ;DS = 0x0000
    mov ds, ax                          ; Set DS segment selector to match AX
    not ax                              ;ES = 0xFFFF
    mov es, ax                          ; Set ES segment selector to match AX

    mov di, 0x7dfe                      ;0x0000:0x7DFE
    mov si, 0x7e0e                      ;0xFFFF:0x7E0E (Physical address 0x107DFE)

    mov al, byte [ds:di]                ; Execute instruction
    push ax                             ;Push AX register onto memory stack
    mov al, byte [es:si]                ; Execute instruction
    push ax                             ;Push AX register onto memory stack

    mov byte [ds:di], 0x00              ; Execute instruction
    mov byte [es:si], 0xFF              ; Execute instruction

    cmp byte [ds:di], 0xFF              ; Execute instruction

    pop ax                              ;Pop top stack value into AX register
    mov byte [es:si], al                ; Execute instruction
    pop ax                              ;Pop top stack value into AX register
    mov byte [ds:di], al                ; Execute instruction

    mov ax, 0                           ; Copy value from 0 to ax
    je .done                            ;If equal, memory wrapped -> A20 disabled
    mov ax, 1                           ;Otherwise A20 is enabled

.done:
    pop si                              ;Pop top stack value into SI register
    pop di                              ;Pop top stack value into DI register
    pop es                              ;Pop top stack value into ES register
    pop ds                              ;Pop top stack value into DS register
    popf                                ; Execute instruction
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; enable_a20: Multi-tier enable (BIOS INT 0x15 -> Fast Port 0x92 -> 8042 Kbd)
; Returns:
;   AX = 1 on success, AX = 0 on failure
; -----------------------------------------------------------------------------
enable_a20:
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Execute instruction
    jnz .success                        ;Jump to .success if condition 'nz' is met

    ; Tier 1: BIOS Fast A20 Service
    mov ax, 0x2401                      ; Copy value from 0x2401 to ax
    int 0x15                            ; Trigger BIOS System Services / Wait interrupt
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Execute instruction
    jnz .success                        ;Jump to .success if condition 'nz' is met

    ; Tier 2: Fast Port 0x92 (System Control Port A)
    in al, 0x92                         ; Execute instruction
    or al, 2                            ; Execute instruction
    and al, 0xFE                        ;Avoid fast CPU reset bit
    out 0x92, al                        ; Execute instruction
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Execute instruction
    jnz .success                        ;Jump to .success if condition 'nz' is met

    ; Tier 3: 8042 PS/2 Keyboard Controller
    call .enable_a20_kbd                ; Execute instruction
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Execute instruction
    jnz .success                        ;Jump to .success if condition 'nz' is met

    ; All methods failed
    xor ax, ax                          ;Zero out AX register
    ret                                 ;Return control to caller instruction pointer

.success:
    mov ax, 1                           ; Copy value from 1 to ax
    ret                                 ;Return control to caller instruction pointer

.enable_a20_kbd:
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)
    call .wait_kbd_input                ; Execute instruction
    mov al, 0xAD                        ;Disable keyboard
    out 0x64, al                        ; Execute instruction

    call .wait_kbd_input                ; Execute instruction
    mov al, 0xD0                        ;Read output port command
    out 0x64, al                        ; Execute instruction

    call .wait_kbd_output               ; Execute instruction
    in al, 0x60                         ;Read current output port state
    push ax                             ;Push AX register onto memory stack

    call .wait_kbd_input                ; Execute instruction
    mov al, 0xD1                        ;Write output port command
    out 0x64, al                        ; Execute instruction

    call .wait_kbd_input                ; Execute instruction
    pop ax                              ;Pop top stack value into AX register
    or al, 2                            ;Set A20 line enable bit
    out 0x60, al                        ; Execute instruction

    call .wait_kbd_input                ; Execute instruction
    mov al, 0xAE                        ;Enable keyboard
    out 0x64, al                        ; Execute instruction
    sti                                 ;Enable hardware interrupts (set IF bit in EFLAGS)
    ret                                 ;Return control to caller instruction pointer

.wait_kbd_input:
    in al, 0x64                         ; Execute instruction
    test al, 2                          ;Check input buffer status (0 = empty)
    jnz .wait_kbd_input                 ;Jump to .wait_kbd_input if condition 'nz' is met
    ret                                 ;Return control to caller instruction pointer

.wait_kbd_output:
    in al, 0x64                         ; Execute instruction
    test al, 1                          ;Check output buffer status (1 = full)
    jz .wait_kbd_output                 ;Jump to .wait_kbd_output if condition 'z' is met
    ret                                 ;Return control to caller instruction pointer
