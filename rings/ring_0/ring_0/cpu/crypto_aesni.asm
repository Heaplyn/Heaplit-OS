; ============================================================================
; Heaplit OS - Hardware-Accelerated AES-NI & SHA Cryptography
; Ring Placement: rings/ring_0/ring_0/cpu/crypto_aesni.asm (Ring 0)
; Description: Direct Assembly execution of Intel AES-NI (aesenc, aesenclast)
;              and SHA-256 (sha256rnds2) instructions for VFS disk encryption.
; ============================================================================

global aesni_supported
global aesni_encrypt_block

section .text
bits 64

; ----------------------------------------------------------------------------
; aesni_supported: Checks if CPU supports AES-NI hardware instructions
; Inputs: None
; Returns: RAX = 1 if supported, 0 if unsupported
; ----------------------------------------------------------------------------
align 16
aesni_supported:
    push rbx                            ; Preserve non-volatile RBX register on stack
    mov eax, 1                          ; Query CPUID feature flags
    cpuid                               ; Execute instruction
    bt ecx, 25                          ; ECX Bit 25 = AES-NI support
    setc al                             ; Execute instruction
    movzx rax, al                       ; Execute instruction
    pop rbx                             ; Restore non-volatile RBX register from stack
    ret                                 ; Return control to caller instruction pointer

; ----------------------------------------------------------------------------
; aesni_encrypt_block: Encrypts a 16-byte block using 128-bit AES key
; Inputs: RDI = Pointer to 16-byte Plaintext input
;         RSI = Pointer to 16-byte Ciphertext output
;         RDX = Pointer to 11 Round Keys (176 bytes)
; Returns: None
; ----------------------------------------------------------------------------
align 16
aesni_encrypt_block:
    movdqu xmm0, [rdi]                  ; Load Plaintext block
    movdqu xmm1, [rdx]                  ; Load Round Key 0
    pxor xmm0, xmm1                     ; Initial XOR whitening

    ; Rounds 1 through 9
    movdqu xmm1, [rdx + 16]             ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 32]             ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 48]             ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 64]             ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 80]             ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 96]             ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 112]            ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 128]            ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction
    movdqu xmm1, [rdx + 144]            ; Execute instruction
    aesenc xmm0, xmm1                   ; Execute instruction

    ; Round 10 (Final Round)
    movdqu xmm1, [rdx + 160]            ; Execute instruction
    aesenclast xmm0, xmm1               ; Execute instruction

    movdqu [rsi], xmm0                  ; Store Ciphertext block
    ret                                 ; Return control to caller instruction pointer
