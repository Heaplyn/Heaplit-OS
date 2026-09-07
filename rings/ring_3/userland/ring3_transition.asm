; rings/ring_3/userland/ring3_transition.asm
; =============================================================================
; Heaplit OS - Dedicated Ring 0 -> Ring 3 Hardware Privilege Transition Module
; Ring Placement: rings/ring_3/userland/ring3_transition.asm (Ring 3)
; Description: Safely performs 64-bit iretq hardware switch from Ring 0 (CPL=0)
;              to Ring 3 (CPL=3). Clears segment registers with NULL selectors
;              before iretq to prevent #GP General Protection Triple Faults.
; =============================================================================

[bits 64]                               ;64-bit Long Mode Execution

global enter_ring_3_transition
extern ring_3_userland_entry

; Segment Selector Definitions from GDT (RPL = 3 for User Mode)
%define USER_DATA_64_SEL (0x28 | 3)     ;GDT Index 5: 0x28 | RPL 3 = 0x2B
%define USER_CODE_64_SEL (0x30 | 3)     ;GDT Index 6: 0x30 | RPL 3 = 0x33
%define USER_STACK_TOP   0x80000        ;Userland Stack Top Address

section .text

; -----------------------------------------------------------------------------
; enter_ring_3_transition: Atomically transitions CPU execution to Ring 3
; -----------------------------------------------------------------------------
align 16
enter_ring_3_transition:
    cli                                 ;Disable interrupts during stack frame construction

    ; 1. Clear DS, ES, FS, GS with NULL selectors (0x00) while still in Ring 0
    ; (Prevents #GP fault caused by loading Ring 3 RPL=3 selectors at CPL=0)
    xor ax, ax                          ;Zero out AX register
    mov ds, ax                          ;Set DS = 0 (Null Selector)
    mov es, ax                          ;Set ES = 0 (Null Selector)
    mov fs, ax                          ;Set FS = 0 (Null Selector)
    mov gs, ax                          ;Set GS = 0 (Null Selector)

    ; 2. Construct 64-bit iretq hardware stack frame:
    ; [RSP + 32] = SS     (User Data Selector 0x2B)
    ; [RSP + 24] = RSP    (User Stack Pointer 0x80000)
    ; [RSP + 16] = RFLAGS (0x202: Interrupts Enabled IF=1)
    ; [RSP + 8]  = CS     (User Code Selector 0x33)
    ; [RSP + 0]  = RIP    (Target Userland Entry Address)
    push qword USER_DATA_64_SEL         ;Push SS (User Data Segment 0x2B)
    push qword USER_STACK_TOP           ;Push RSP (User Stack Pointer 0x80000)
    push qword 0x202                    ;Push RFLAGS (IF=1 bit 9 enabled)
    push qword USER_CODE_64_SEL         ;Push CS (User Code Segment 0x33)
    push qword ring_3_userland_entry    ;Push RIP (Userland Target Address)

    ; 3. Execute 64-bit iretq: Hardware pops stack frame and switches CPL to 3
    iretq                               ;Atomically switch CPU to Ring 3!
