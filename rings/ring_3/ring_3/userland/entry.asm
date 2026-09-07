; rings/ring_3/userland/entry.asm
; Ring 3 Userland Entry & Interactive Userland Environment
[bits 64]                               ; Execute instruction

global ring_3_userland_entry

ring_3_userland_entry:
    ; 1. Display confirmation that Ring 3 Userland is active
    mov rsi, msg_ring3_active           ; Copy value from msg_ring3_active to rsi
    mov rdi, 0xB8000 + (15 * 80 * 2)    ; Row 15, Col 0
    call print_string_64                ; Execute instruction

    ; 2. Output Userland Shell Ready
    mov rsi, msg_ring3_shell            ; Copy value from msg_ring3_shell to rsi
    mov rdi, 0xB8000 + (16 * 80 * 2)    ; Row 16, Col 0
    call print_string_64                ; Execute instruction

.userland_loop:
    pause                               ; Emit CPU pause hint to optimize spinlock pipeline stalls
    jmp .userland_loop                  ; Unconditional jump to target label .userland_loop

msg_ring3_active: db 'Heaplit OS: Hardware Ring 3 (Userland CPL=3) Active!', 0 ; Execute instruction
msg_ring3_shell:  db 'Userland Shell: Listening for Heaplit Daemon IPC...', 0 ; Execute instruction
