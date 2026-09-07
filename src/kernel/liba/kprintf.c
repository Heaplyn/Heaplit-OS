// src/kernel/liba/kprintf.c
// Kernel Console and Serial Port Formatted Logger for Heaplit OS
#include <heaplit/types.h>

extern void print_string_64(const char* str, uint64_t offset);

static uint64_t console_cursor_offset = 0xB8000 + (16 * 80 * 2);

void kputc(char c) {
    volatile uint8_t* vga = (volatile uint8_t*)0xB8000;
    if (c == '\n') {
        uint64_t current_row = (console_cursor_offset - 0xB8000) / 160;
        console_cursor_offset = 0xB8000 + ((current_row + 1) * 160);
    } else {
        vga[console_cursor_offset - 0xB8000] = (uint8_t)c;
        vga[console_cursor_offset - 0xB8000 + 1] = 0x0F; // White on black
        console_cursor_offset += 2;
    }
}

void kputs(const char* s) {
    while (*s) {
        kputc(*s++);
    }
}

void kprint_hex(uint64_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    kputs("0x");
    for (int i = 60; i >= 0; i -= 4) {
        kputc(hex_chars[(val >> i) & 0xF]);
    }
}
