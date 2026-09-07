; rings/ring_0/ring_1/a20.asm
; A20 Gate Enable & Verification Utilities for Heaplit OS (16-bit Real Mode)
[bits 16]

; -----------------------------------------------------------------------------
; check_a20: Tests if address line 20 is active by testing memory wrap-around.
; Returns:
;   AX = 1 if enabled, AX = 0 if disabled
; Preserved:
;   BX, CX, DX, SI, DI, DS, ES
; -----------------------------------------------------------------------------
check_a20:
    pushf
    push ds
    push es
    push di
    push si
    cli

    xor ax, ax                  ; DS = 0x0000
    mov ds, ax
    not ax                      ; ES = 0xFFFF
    mov es, ax

    mov di, 0x7dfe              ; 0x0000:0x7DFE
    mov si, 0x7e0e              ; 0xFFFF:0x7E0E (Physical address 0x107DFE)

    mov al, byte [ds:di]
    push ax
    mov al, byte [es:si]
    push ax

    mov byte [ds:di], 0x00
    mov byte [es:si], 0xFF

    cmp byte [ds:di], 0xFF

    pop ax
    mov byte [es:si], al
    pop ax
    mov byte [ds:di], al

    mov ax, 0
    je .done                    ; If equal, memory wrapped -> A20 disabled
    mov ax, 1                   ; Otherwise A20 is enabled

.done:
    pop si
    pop di
    pop es
    pop ds
    popf
    ret

; -----------------------------------------------------------------------------
; enable_a20: Multi-tier enable (BIOS INT 0x15 -> Fast Port 0x92 -> 8042 Kbd)
; Returns:
;   AX = 1 on success, AX = 0 on failure
; -----------------------------------------------------------------------------
enable_a20:
    call check_a20
    test ax, ax
    jnz .success

    ; Tier 1: BIOS Fast A20 Service
    mov ax, 0x2401
    int 0x15
    call check_a20
    test ax, ax
    jnz .success

    ; Tier 2: Fast Port 0x92 (System Control Port A)
    in al, 0x92
    or al, 2
    and al, 0xFE                ; Avoid fast CPU reset bit
    out 0x92, al
    call check_a20
    test ax, ax
    jnz .success

    ; Tier 3: 8042 PS/2 Keyboard Controller
    call .enable_a20_kbd
    call check_a20
    test ax, ax
    jnz .success

    ; All methods failed
    xor ax, ax
    ret

.success:
    mov ax, 1
    ret

.enable_a20_kbd:
    cli
    call .wait_kbd_input
    mov al, 0xAD                ; Disable keyboard
    out 0x64, al

    call .wait_kbd_input
    mov al, 0xD0                ; Read output port command
    out 0x64, al

    call .wait_kbd_output
    in al, 0x60                 ; Read current output port state
    push ax

    call .wait_kbd_input
    mov al, 0xD1                ; Write output port command
    out 0x64, al

    call .wait_kbd_input
    pop ax
    or al, 2                    ; Set A20 line enable bit
    out 0x60, al

    call .wait_kbd_input
    mov al, 0xAE                ; Enable keyboard
    out 0x64, al
    sti
    ret

.wait_kbd_input:
    in al, 0x64
    test al, 2                  ; Check input buffer status (0 = empty)
    jnz .wait_kbd_input
    ret

.wait_kbd_output:
    in al, 0x64
    test al, 1                  ; Check output buffer status (1 = full)
    jz .wait_kbd_output
    ret
