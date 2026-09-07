[org 0x7c00]
bits 16

jmp start

; -----------------------------
; Sector 1 - Main Bootloader
; -----------------------------

start:
    ; Immediately disable interrupts and save BIOS boot drive number
    cli
    mov [boot_drive], dl    ; DL contains the boot drive ID passed by BIOS

    ; Set up segments cleanly
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    call clear_screen

    ; Read Sector 2 from Disk
    mov ah, 0x02            ; BIOS read sector function
    mov al, 1               ; Number of sectors to read
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Sector 2 (1-based index)
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Restore the boot drive ID
    
    ; Target buffer: ES:BX = 0x0000:0x7E00 (Immediately after bootloader)
    xor bx, bx
    mov es, bx
    mov bx, 0x7e00

    int 0x13
    jc disk_error

    ; Print success message from Sector 1
    mov si, msg_welcome
    call print_string_16

    ; Jump to the loaded code in Sector 2
    jmp sector_2_start

disk_error:
    mov si, msg_error
    call print_string_16
    cli
    hlt
    jmp $

; -----------------------------
; Data & Variables
; -----------------------------
boot_drive:   db 0
msg_welcome:  db 'Heaplit OS Sector 1 Loaded!', 0x0D, 0x0A, 0
msg_error:    db 'Disk Read Failed!', 0x0D, 0x0A, 0
my_var:       times 6 db 0    ; Reserved space for variable (variable struc size)

; Include routines at the end of Sector 1
%include "ring_1/memory.asm"
%include "ring_2/console.asm"
%include "ring_0/variable.asm"

; Pad to 510 bytes and add boot signature
times 510 - ($ - $$) db 0
dw 0xaa55

; -----------------------------
; Sector 2 - Extended Bootloader
; -----------------------------
sector_2_start:
    ; Initialize a variable using the imported library
    mov di, my_var
    mov al, type_bool
    mov dx, 1
    call create_variable

    ; Print message from Sector 2
    mov si, msg_sector_2
    call print_string_16

    ; Indicate success and halt
    mov si, msg_ready
    call print_string_16

    cli
    hlt
    jmp $

msg_sector_2: db 'Sector 2 Executing!', 0x0D, 0x0A, 0
msg_ready:    db 'Heaplit OS Kernel Ready.', 0x0D, 0x0A, 0

; Pad Sector 2 to 512 bytes
times 1024 - ($ - $$) db 0

sector_3_start:
    mov ah, 0x02        ; Set cursor position
    mov bh, 0           ; Page 0
    mov dh, 5           ; Row 5
    mov dl, 12          ; Column 12
    int 0x10
