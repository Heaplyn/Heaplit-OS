; ============================================================================
; Heaplit OS - Local APIC Timer Calibrator & Tickless Scheduler Setup
; Ring Placement: rings/ring_0/ring_0/cpu/apic_timer.asm (Ring 0)
; Description: OSDev Wiki standard Local APIC timer driver supporting periodic
;              and one-shot tickless timer interrupts via MMIO offset 0x320.
; ============================================================================

global apic_timer_init
global apic_timer_oneshot
global apic_timer_stop

section .text
bits 64

%define APIC_DEFAULT_BASE    0xFEE00000
%define APIC_TIMER_LVT       0x0320
%define APIC_TIMER_INITCNT   0x0380
%define APIC_TIMER_CURRCNT   0x0390
%define APIC_TIMER_DIVCONF   0x03E0

; LVT Timer Modes
%define APIC_LVT_INT_VECTOR  0x40        ; IRQ vector 0x40 for APIC timer interrupts
%define APIC_LVT_PERIODIC    0x00020000  ; Periodic mode bit 17
%define APIC_LVT_MASKED      0x00010000  ; Masked bit 16

; ----------------------------------------------------------------------------
; apic_timer_init: Configures LAPIC timer divide ratio and vector
; Inputs: RDI = APIC MMIO Base Address (or 0 for default 0xFEE00000)
;         RSI = Initial Count Value
; Returns: RAX = 0 on Success
; ----------------------------------------------------------------------------
align 16
apic_timer_init:
    test rdi, rdi
    jnz .has_base
    mov rdi, APIC_DEFAULT_BASE
.has_base:

    ; 1. Set Divide Configuration Register (Divide by 16: Bit 3 = 1, Bit 1:0 = 3)
    mov dword [rdi + APIC_TIMER_DIVCONF], 0x03

    ; 2. Configure LVT Timer Register (Vector 0x40, Unmasked, Periodic)
    mov eax, APIC_LVT_INT_VECTOR | APIC_LVT_PERIODIC
    mov [rdi + APIC_TIMER_LVT], eax

    ; 3. Set Initial Counter Value to start timer ticking
    mov eax, esid                      ; RSI = Initial Count
    mov eax, esi
    mov [rdi + APIC_TIMER_INITCNT], eax

    xor rax, rax
    ret

; ----------------------------------------------------------------------------
; apic_timer_oneshot: Sets up a tickless one-shot deadline timer
; Inputs: RDI = APIC MMIO Base Address (or 0 for default)
;         RSI = Deadline Ticks Count
; Returns: None
; ----------------------------------------------------------------------------
align 16
apic_timer_oneshot:
    test rdi, rdi
    jnz .has_base_oneshot
    mov rdi, APIC_DEFAULT_BASE
.has_base_oneshot:

    ; Configure LVT for One-Shot Mode (Periodic bit cleared)
    mov eax, APIC_LVT_INT_VECTOR
    mov [rdi + APIC_TIMER_LVT], eax

    ; Load deadline count
    mov [rdi + APIC_TIMER_INITCNT], esi
    ret

; ----------------------------------------------------------------------------
; apic_timer_stop: Disables LAPIC timer interrupts
; Inputs: RDI = APIC MMIO Base Address
; ----------------------------------------------------------------------------
align 16
apic_timer_stop:
    test rdi, rdi
    jnz .has_base_stop
    mov rdi, APIC_DEFAULT_BASE
.has_base_stop:

    mov dword [rdi + APIC_TIMER_LVT], APIC_LVT_MASKED
    mov dword [rdi + APIC_TIMER_INITCNT], 0
    ret
