; ============================================================================
; Heaplit OS - Local APIC Timer Calibrator & Tickless Scheduler Setup
; Ring Placement: rings/ring_0/cpu/apic_timer.asm (Ring 0)
; Description: OSDev Wiki standard Local APIC timer driver supporting periodic
;              and one-shot tickless timer interrupts via MMIO offset 0x320.
; ============================================================================

global apic_timer_init
global apic_timer_oneshot
global apic_timer_stop

section .text
bits 64

%define APIC_DEFAULT_BASE    0xFEE00000 ; Execute instruction
%define APIC_TIMER_LVT       0x0320     ; Execute instruction
%define APIC_TIMER_INITCNT   0x0380     ; Execute instruction
%define APIC_TIMER_CURRCNT   0x0390     ; Execute instruction
%define APIC_TIMER_DIVCONF   0x03E0     ; Execute instruction

; LVT Timer Modes
%define APIC_LVT_INT_VECTOR  0x40       ; IRQ vector 0x40 for APIC timer interrupts
%define APIC_LVT_PERIODIC    0x00020000 ; Periodic mode bit 17
%define APIC_LVT_MASKED      0x00010000 ; Masked bit 16

; ----------------------------------------------------------------------------
; apic_timer_init: Configures LAPIC timer divide ratio and vector
; Inputs: RDI = APIC MMIO Base Address (or 0 for default 0xFEE00000)
;         RSI = Initial Count Value
; Returns: RAX = 0 on Success
; ----------------------------------------------------------------------------
align 16
apic_timer_init:
    test rdi, rdi                       ; Execute instruction
    jnz .has_base                       ; Jump to .has_base if condition 'nz' is met
    mov rdi, APIC_DEFAULT_BASE          ; Copy value from APIC_DEFAULT_BASE to rdi
.has_base:

    ; 1. Set Divide Configuration Register (Divide by 16: Bit 3 = 1, Bit 1:0 = 3)
    mov dword [rdi + APIC_TIMER_DIVCONF], 0x03 ; Copy value from 0x03 to dword [rdi + APIC_TIMER_DIVCONF]

    ; 2. Configure LVT Timer Register (Vector 0x40, Unmasked, Periodic)
    mov eax, APIC_LVT_INT_VECTOR | APIC_LVT_PERIODIC ; Execute instruction
    mov [rdi + APIC_TIMER_LVT], eax     ; Copy value from eax to [rdi + APIC_TIMER_LVT]

    ; 3. Set Initial Counter Value to start timer ticking
    mov eax, esid                       ; RSI = Initial Count
    mov eax, esi                        ; Copy value from esi to eax
    mov [rdi + APIC_TIMER_INITCNT], eax ; Copy value from eax to [rdi + APIC_TIMER_INITCNT]

    xor rax, rax                        ; Zero out RAX register
    ret                                 ; Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; apic_timer_oneshot: Sets up a tickless one-shot deadline timer
; Inputs: RDI = APIC MMIO Base Address (or 0 for default)
;         RSI = Deadline Ticks Count
; Returns: None
; ----------------------------------------------------------------------------
align 16
apic_timer_oneshot:
    test rdi, rdi                       ; Execute instruction
    jnz .has_base_oneshot               ; Jump to .has_base_oneshot if condition 'nz' is met
    mov rdi, APIC_DEFAULT_BASE          ; Copy value from APIC_DEFAULT_BASE to rdi
.has_base_oneshot:

    ; Configure LVT for One-Shot Mode (Periodic bit cleared)
    mov eax, APIC_LVT_INT_VECTOR        ; Copy value from APIC_LVT_INT_VECTOR to eax
    mov [rdi + APIC_TIMER_LVT], eax     ; Copy value from eax to [rdi + APIC_TIMER_LVT]

    ; Load deadline count
    mov [rdi + APIC_TIMER_INITCNT], esi ; Copy value from esi to [rdi + APIC_TIMER_INITCNT]
    ret                                 ; Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; apic_timer_stop: Disables LAPIC timer interrupts
; Inputs: RDI = APIC MMIO Base Address
; ----------------------------------------------------------------------------
align 16
apic_timer_stop:
    test rdi, rdi                       ; Execute instruction
    jnz .has_base_stop                  ; Jump to .has_base_stop if condition 'nz' is met
    mov rdi, APIC_DEFAULT_BASE          ; Copy value from APIC_DEFAULT_BASE to rdi
.has_base_stop:

    mov dword [rdi + APIC_TIMER_LVT], APIC_LVT_MASKED ; Copy value from APIC_LVT_MASKED to dword [rdi + APIC_TIMER_LVT]
    mov dword [rdi + APIC_TIMER_INITCNT], 0 ; Copy value from 0 to dword [rdi + APIC_TIMER_INITCNT]
    ret                                 ; Return control to caller instruction pointer
