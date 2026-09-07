[org 0x7c00]
bits 16

jmp start

; -----------------------------
; Sector 1 - Main Bootloader
; -----------------------------

start:
    ; Immediately disable interrupts and save BIOS boot drive number
    cli
    mov [BOOT_DRIVE], dl    ; DL contains the boot drive ID passed by BIOS

    ; Set up segments cleanly
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    call ClearScreen

    ; Read Sector 2 from Disk
    mov ah, 0x02            ; BIOS read sector function
    mov al, 1               ; Number of sectors to read
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Sector 2 (1-based index)
    mov dh, 0               ; Head 0
    mov dl, [BOOT_DRIVE]    ; Restore the boot drive ID
    
    ; Target buffer: ES:BX = 0x0000:0x7E00 (Immediately after bootloader)
    xor bx, bx
    mov es, bx
    mov bx, 0x7e00

    int 0x13
    jc DiskError

    ; Print success message from Sector 1
    mov si, msg_welcome
    call PrintString16

    ; Jump to the loaded code in Sector 2
    jmp Sector2_Start

DiskError:
    mov si, msg_error
    call PrintString16
    cli
    hlt
    jmp $

; -----------------------------
; Data & Variables
; -----------------------------
BOOT_DRIVE:  db 0
msg_welcome: db 'Heaplit OS Sector 1 Loaded!', 0x0D, 0x0A, 0
msg_error:   db 'Disk Read Failed!', 0x0D, 0x0A, 0
MyVar:       times 6 db 0    ; Reserved space for variable (Variable struc size)

; Include routines at the end of Sector 1
%include "Ring1/Memory.asm"
%include "Ring2/Console.asm"
%include "Ring0/Variable.asm"

; Pad to 510 bytes and add boot signature
times 510 - ($ - $$) db 0
dw 0xaa55

; -----------------------------
; Sector 2 - Extended Bootloader
; -----------------------------
Sector2_Start:
    ; Initialize a variable using the imported library
    mov di, MyVar
    mov al, type_bool
    mov dx, 1
    call CreateVariable

    ; Print message from Sector 2
    mov si, msg_sector2
    call PrintString16

    ; Indicate success and halt
    mov si, msg_ready
    call PrintString16

    cli
    hlt
    jmp $

msg_sector2: db 'Sector 2 Executing!', 0x0D, 0x0A, 0
msg_ready:   db 'Heaplit OS Kernel Ready.', 0x0D, 0x0A, 0

; Pad Sector 2 to 512 bytes
times 1024 - ($ - $$) db 0

Sector3_Start:
    
