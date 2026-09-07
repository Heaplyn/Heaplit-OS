; rings/ring_0/idt.asm
; 64-bit Interrupt Descriptor Table (IDT) & ISR Templates

struc idt_entry_64                      ; Execute instruction
    .offset_low  resw 1                 ; Offset bits 0..15
    .selector    resw 1                 ; Kernel code segment selector (0x18)
    .ist         resb 1                 ; Interrupt Stack Table offset (0..7)
    .type_attr   resb 1                 ; Type and attributes (0x8E = 64-bit interrupt gate)
    .offset_mid  resw 1                 ; Offset bits 16..31
    .offset_high resd 1                 ; Offset bits 32..63
    .zero        resd 1                 ; Reserved (must be 0)
endstruc                                ; Execute instruction

align 16
idt_start:
    times 256 * idt_entry_64_size db 0  ; Execute instruction
idt_end:

idt_descriptor_64:
    dw idt_end - idt_start - 1          ; Limit
    dq idt_start                        ; Base address
