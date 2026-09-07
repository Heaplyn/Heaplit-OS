; rings/ring_0/ring_1/a20.asm
; A20 Gate Enable & Verification Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]                               ; Set assembler target mode to 16-bit Real Mode

; -----------------------------------------------------------------------------
; check_a20: Tests if address line 20 is active by testing memory wrap-around.
; Returns:
;   AX = 1 if enabled, AX = 0 if disabled
; Preserved:
;   BX, CX, DX, SI, DI, DS, ES
; -----------------------------------------------------------------------------
check_a20:
    pushf                               ; Save 16-bit FLAGS register onto stack
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

    mov al, byte [ds:di]                ; Read test byte at low memory address 0x0000:0x0500
    push ax                             ;Push AX register onto memory stack
    mov al, byte [es:si]                ; Read test byte at 1MB high memory address 0xFFFF:0x0510
    push ax                             ;Push AX register onto memory stack

    mov byte [ds:di], 0x00              ; Write 0x00 to low memory test location
    mov byte [es:si], 0xFF              ; Write 0xFF to high memory test location to check for wraparound

    cmp byte [ds:di], 0xFF              ; Compare low memory byte against 0xFF to verify if A20 gate is disabled

    pop ax                              ;Pop top stack value into AX register
    mov byte [es:si], al                ; Restore original byte value to high memory location
    pop ax                              ;Pop top stack value into AX register
    mov byte [ds:di], al                ; Restore original byte value to low memory location

    mov ax, 0                           ; Set ax = 0
    je .done                            ;If equal, memory wrapped -> A20 disabled
    mov ax, 1                           ;Otherwise A20 is enabled

.done:
    pop si                              ;Pop top stack value into SI register
    pop di                              ;Pop top stack value into DI register
    pop es                              ;Pop top stack value into ES register
    pop ds                              ;Pop top stack value into DS register
    popf                                ; Restore 16-bit FLAGS register from stack
    ret                                 ;Return control to caller instruction pointer

; -----------------------------------------------------------------------------
; enable_a20: Multi-tier enable (BIOS INT 0x15 -> Fast Port 0x92 -> 8042 Kbd)
; Returns:
;   AX = 1 on success, AX = 0 on failure
; -----------------------------------------------------------------------------
enable_a20:
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Test accumulator register for zero / error status
    jnz .success                        ; Branch to '.success' if Zero Flag is clear (ZF=0)

    ; Tier 1: BIOS Fast A20 Service
    mov ax, 0x2401                      ; Set ax = 0x2401
    int 0x15                            ; Trigger BIOS System Services / Wait interrupt
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Test accumulator register for zero / error status
    jnz .success                        ; Branch to '.success' if Zero Flag is clear (ZF=0)

    ; Tier 2: Fast Port 0x92 (System Control Port A)
    in al, 0x92                         ; Read Fast A20 System Control Port 0x92
    or al, 2                            ; Set Bit 1 to activate Fast A20 gate
    and al, 0xFE                        ;Avoid fast CPU reset bit
    out 0x92, al                        ; Output updated byte to Fast A20 Control Port 0x92
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Test accumulator register for zero / error status
    jnz .success                        ; Branch to '.success' if Zero Flag is clear (ZF=0)

    ; Tier 3: 8042 PS/2 Keyboard Controller
    call .enable_a20_kbd                ; Call helper function '.enable_a20_kbd'
    call check_a20                      ; Call subroutine 'check_a20'
    test ax, ax                         ; Test accumulator register for zero / error status
    jnz .success                        ; Branch to '.success' if Zero Flag is clear (ZF=0)

    ; All methods failed
    xor ax, ax                          ;Zero out AX register
    ret                                 ;Return control to caller instruction pointer

.success:
    mov ax, 1                           ; Set ax = 1
    ret                                 ;Return control to caller instruction pointer

.enable_a20_kbd:
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)
    call .wait_kbd_input                ; Call helper function '.wait_kbd_input'
    mov al, 0xAD                        ;Disable keyboard
    out 0x64, al                        ; Output command byte to 8042 Keyboard Controller Command Port 0x64

    call .wait_kbd_input                ; Call helper function '.wait_kbd_input'
    mov al, 0xD0                        ;Read output port command
    out 0x64, al                        ; Output command byte to 8042 Keyboard Controller Command Port 0x64

    call .wait_kbd_output               ; Call helper function '.wait_kbd_output'
    in al, 0x60                         ;Read current output port state
    push ax                             ;Push AX register onto memory stack

    call .wait_kbd_input                ; Call helper function '.wait_kbd_input'
    mov al, 0xD1                        ;Write output port command
    out 0x64, al                        ; Output command byte to 8042 Keyboard Controller Command Port 0x64

    call .wait_kbd_input                ; Call helper function '.wait_kbd_input'
    pop ax                              ;Pop top stack value into AX register
    or al, 2                            ;Set A20 line enable bit
    out 0x60, al                        ; Execute hardware step

    call .wait_kbd_input                ; Call helper function '.wait_kbd_input'
    mov al, 0xAE                        ;Enable keyboard
    out 0x64, al                        ; Output command byte to 8042 Keyboard Controller Command Port 0x64
    sti                                 ;Enable hardware interrupts (set IF bit in EFLAGS)
    ret                                 ;Return control to caller instruction pointer

.wait_kbd_input:
    in al, 0x64                         ; Execute hardware step
    test al, 2                          ;Check input buffer status (0 = empty)
    jnz .wait_kbd_input                 ; Branch to '.wait_kbd_input' if Zero Flag is clear (ZF=0)
    ret                                 ;Return control to caller instruction pointer

.wait_kbd_output:
    in al, 0x64                         ; Execute hardware step
    test al, 1                          ;Check output buffer status (1 = full)
    jz .wait_kbd_output                 ; Branch to '.wait_kbd_output' if Zero Flag is set (ZF=1)
    ret                                 ;Return control to caller instruction pointer
