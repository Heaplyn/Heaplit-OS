; rings/ring_3/boot/mbr.asm
; =============================================================================
; Sector 1: Master Boot Record Bootstrap (0x7C00 - 0x7DFF)
; =============================================================================
[bits 16]                               ; Execute instruction

mbr_entry:
    cli                                 ;Disable interrupts during CPU initialization
    mov [boot_drive], dl                ;Save boot drive ID passed by BIOS in DL

    ; Set up clean segment registers
    xor ax, ax                          ;Zero out AX register
    mov ds, ax                          ; Set DS segment selector to match AX
    mov es, ax                          ; Set ES segment selector to match AX
    mov ss, ax                          ; Set SS segment selector to match AX
    mov sp, 0x7c00                      ;Stack safely below bootloader
    sti                                 ;Re-enable interrupts

    call clear_screen                   ; Call subroutine 'clear_screen'

    ; Reset disk system (Drive DL)
    xor ax, ax                          ;Zero out AX register
    mov dl, [boot_drive]                ; Copy value from [boot_drive] to dl
    int 0x13                            ; Trigger BIOS Disk I/O interrupt

    ; Read 7 extended sectors (Sectors 2 through 8 = 3584 bytes) to 0x7E00
    mov ah, 0x02                        ;BIOS read sector function
    mov al, 7                           ;Read 7 sectors (exactly matching 4KB disk size)
    mov ch, 0                           ;Cylinder 0
    mov cl, 2                           ;Sector 2 (1-based index)
    mov dh, 0                           ;Head 0
    mov dl, [boot_drive]                ;Drive ID
    
    ; Target buffer: ES:BX = 0x0000:0x7E00
    xor bx, bx                          ;Zero out BX register
    mov es, bx                          ; Set ES segment selector to match BX
    mov bx, 0x7e00                      ; Copy value from 0x7e00 to bx

    int 0x13                            ; Trigger BIOS Disk I/O interrupt
    jc mbr_disk_error                   ;Jump to mbr_disk_error if condition 'c' is met

    ; Success message from Sector 1
    mov si, msg_sector_1                ; Load memory address of string 'msg_sector_1' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'

    ; Jump to extended loader in Sector 2
    jmp stage2_entry                    ;Unconditional jump to target label stage2_entry

mbr_disk_error:
    mov si, msg_disk_error              ; Load memory address of string 'msg_disk_error' into SI argument register
    call print_string_16                ; Call subroutine 'print_string_16'
    cli                                 ;Disable hardware interrupts (clear IF bit in EFLAGS)
    hlt                                 ;Halt CPU execution until next hardware interrupt
    jmp $                               ; Execute instruction

; Sector 1 Data
boot_drive:      db 0                   ; Execute instruction
msg_sector_1:    db 'Heaplit OS Sector 1 Loaded (MBR 0x7C00)', 0x0D, 0x0A, 0 ; Execute instruction
msg_disk_error:  db 'FATAL: Disk Read Failed!', 0x0D, 0x0A, 0 ; Execute instruction
