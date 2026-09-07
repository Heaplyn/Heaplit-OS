; rings/ring_0/gdt.asm
; Global Descriptor Table (GDT) for 16-bit, 32-bit Protected Mode & 64-bit Long Mode

align 16
gdt_start:
    ; 0x00: Null Descriptor
    dq 0x0000000000000000               ; Execute instruction

    ; 0x08: Kernel 32-bit Code Segment (Base=0, Limit=4GB, Exec/Read, 32-bit)
    dw 0xFFFF                           ; Limit 0..15
    dw 0x0000                           ; Base 0..15
    db 0x00                             ; Base 16..23
    db 10011010b                        ; Access: Present(1), Ring0(00), Code(1), Exec(1), Read(1), Acc(0)
    db 11001111b                        ; Flags: 4KB Gran(1), 32-bit(1), LongMode(0), Limit 16..19
    db 0x00                             ; Base 24..31

    ; 0x10: Kernel 32-bit Data Segment (Base=0, Limit=4GB, Read/Write, 32-bit)
    dw 0xFFFF                           ; Execute instruction
    dw 0x0000                           ; Execute instruction
    db 0x00                             ; Execute instruction
    db 10010010b                        ; Access: Present(1), Ring0(00), Data(1), Write(1), Acc(0)
    db 11001111b                        ; Flags: 4KB Gran(1), 32-bit(1)
    db 0x00                             ; Execute instruction

    ; 0x18: Kernel 64-bit Code Segment (Base=0, Long Mode L=1)
    dw 0x0000                           ; Execute instruction
    dw 0x0000                           ; Execute instruction
    db 0x00                             ; Execute instruction
    db 10011010b                        ; Access: Present(1), Ring0(00), Code(1), Exec(1), Read(1)
    db 00100000b                        ; Flags: Long Mode bit(1), 32-bit bit(0)
    db 0x00                             ; Execute instruction

    ; 0x20: Kernel 64-bit Data Segment (Base=0, Long Mode)
    dw 0x0000                           ; Execute instruction
    dw 0x0000                           ; Execute instruction
    db 0x00                             ; Execute instruction
    db 10010010b                        ; Access: Present(1), Ring0(00), Data(1), Write(1)
    db 00000000b                        ; Execute instruction
    db 0x00                             ; Execute instruction

    ; 0x28: User 64-bit Data Segment (Ring 3 / Userland)
    dw 0x0000                           ; Execute instruction
    dw 0x0000                           ; Execute instruction
    db 0x00                             ; Execute instruction
    db 11110010b                        ; Access: Present(1), Ring3(11), Data(1), Write(1)
    db 00000000b                        ; Execute instruction
    db 0x00                             ; Execute instruction

    ; 0x30: User 64-bit Code Segment (Ring 3 / Userland)
    dw 0x0000                           ; Execute instruction
    dw 0x0000                           ; Execute instruction
    db 0x00                             ; Execute instruction
    db 11111010b                        ; Access: Present(1), Ring3(11), Code(1), Exec(1), Read(1)
    db 00100000b                        ; Flags: Long Mode bit(1)
    db 0x00                             ; Execute instruction

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1          ; GDT Size (limit)
    dd gdt_start                        ; GDT Base Address (32-bit)

gdt_descriptor_64:
    dw gdt_end - gdt_start - 1          ; Execute instruction
    dq gdt_start                        ; GDT Base Address (64-bit)

; Segment Selector Constants
CODE_SEG_32 equ 0x08                    ; Execute instruction
DATA_SEG_32 equ 0x10                    ; Execute instruction
CODE_SEG_64 equ 0x18                    ; Execute instruction
DATA_SEG_64 equ 0x20                    ; Execute instruction
USER_DATA_64 equ 0x28 | 3               ; Execute instruction
USER_CODE_64 equ 0x30 | 3               ; Execute instruction
