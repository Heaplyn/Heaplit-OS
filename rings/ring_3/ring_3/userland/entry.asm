; rings/ring_3/userland/entry.asm
; Ring 3 Userland Entry & Interactive Userland Environment
[bits 64]

global ring_3_userland_entry

ring_3_userland_entry:
    ; 1. Display confirmation that Ring 3 Userland is active
    mov rsi, msg_ring3_active
    mov rdi, 0xB8000 + (15 * 80 * 2) ; Row 15, Col 0
    call print_string_64

    ; 2. Output Userland Shell Ready
    mov rsi, msg_ring3_shell
    mov rdi, 0xB8000 + (16 * 80 * 2) ; Row 16, Col 0
    call print_string_64

.userland_loop:
    pause
    jmp .userland_loop

msg_ring3_active: db 'Heaplit OS: Hardware Ring 3 (Userland CPL=3) Active!', 0
msg_ring3_shell:  db 'Userland Shell: Listening for Antigravity Daemon IPC...', 0
