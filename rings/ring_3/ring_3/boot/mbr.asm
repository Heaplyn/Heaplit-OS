; rings/ring_3/boot/mbr.asm
; =============================================================================
; Sector 1: Master Boot Record Bootstrap (0x7C00 - 0x7DFF)
; =============================================================================
[bits 16]

mbr_entry:
    cli                         ; Disable interrupts during CPU initialization
    mov [boot_drive], dl        ; Save boot drive ID passed by BIOS in DL

    ; Set up clean segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00              ; Stack safely below bootloader
    sti                         ; Re-enable interrupts

    call clear_screen

    ; Reset disk system (Drive DL)
    xor ax, ax
    mov dl, [boot_drive]
    int 0x13

    ; Read 7 extended sectors (Sectors 2 through 8 = 3584 bytes) to 0x7E00
    mov ah, 0x02                ; BIOS read sector function
    mov al, 7                   ; Read 7 sectors (exactly matching 4KB disk size)
    mov ch, 0                   ; Cylinder 0
    mov cl, 2                   ; Sector 2 (1-based index)
    mov dh, 0                   ; Head 0
    mov dl, [boot_drive]        ; Drive ID
    
    ; Target buffer: ES:BX = 0x0000:0x7E00
    xor bx, bx
    mov es, bx
    mov bx, 0x7e00

    int 0x13
    jc mbr_disk_error

    ; Success message from Sector 1
    mov si, msg_sector_1
    call print_string_16

    ; Jump to extended loader in Sector 2
    jmp stage2_entry

mbr_disk_error:
    mov si, msg_disk_error
    call print_string_16
    cli
    hlt
    jmp $

; Sector 1 Data
boot_drive:      db 0
msg_sector_1:    db 'Heaplit OS Sector 1 Loaded (MBR 0x7C00)', 0x0D, 0x0A, 0
msg_disk_error:  db 'FATAL: Disk Read Failed!', 0x0D, 0x0A, 0
