/* ============================================================================
 * Heaplit OS - VBE / GOP Linear Framebuffer Engine (OSDev Wiki Standard)
 * Ring Placement: rings/ring_1/drivers/vbe_framebuffer.c (Ring 1)
 * Description: 32-bpp ARGB Linear Framebuffer (LFB) graphics driver supporting
 *              double-buffered primitives (pixel, rect, clear, blit) for spatial UI.
 * ============================================================================ */

#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint32_t* front_buffer; // Physical VBE / GOP Linear Framebuffer address
    uint32_t* back_buffer;  // RAM Back Buffer for zero-flicker double buffering
    uint32_t  width;        // Horizontal resolution in pixels (e.g. 1920)
    uint32_t  height;       // Vertical resolution in pixels (e.g. 1080)
    uint32_t  pitch;        // Bytes per scanline (width * 4)
    uint32_t  bpp;          // Bits per pixel (32 bpp)
} vbe_framebuffer_t;

static vbe_framebuffer_t g_fb = {0};

int vbe_init(uint64_t phys_lfb_address, uint32_t width, uint32_t height, uint32_t pitch, uint32_t* back_buffer_ram) {
    if (!phys_lfb_address || width == 0 || height == 0) return -1;

    g_fb.front_buffer = (uint32_t*)phys_lfb_address;
    g_fb.back_buffer = back_buffer_ram ? back_buffer_ram : g_fb.front_buffer;
    g_fb.width = width;
    g_fb.height = height;
    g_fb.pitch = pitch ? pitch : (width * 4);
    g_fb.bpp = 32;

    return 0;
}

void vbe_draw_pixel(uint32_t x, uint32_t y, uint32_t color_argb) {
    if (x >= g_fb.width || y >= g_fb.height || !g_fb.back_buffer) return;

    uint32_t index = (y * (g_fb.pitch / 4)) + x;
    g_fb.back_buffer[index] = color_argb;
}

void vbe_fill_rect(uint32_t x, uint32_t y, uint32_t w, uint32_t h, uint32_t color_argb) {
    if (!g_fb.back_buffer) return;

    uint32_t max_x = (x + w > g_fb.width) ? g_fb.width : x + w;
    uint32_t max_y = (y + h > g_fb.height) ? g_fb.height : y + h;

    for (uint32_t py = y; py < max_y; py++) {
        uint32_t row_offset = py * (g_fb.pitch / 4);
        for (uint32_t px = x; px < max_x; px++) {
            g_fb.back_buffer[row_offset + px] = color_argb;
        }
    }
}

void vbe_clear(uint32_t color_argb) {
    vbe_fill_rect(0, 0, g_fb.width, g_fb.height, color_argb);
}

void vbe_swap_buffers(void) {
    if (!g_fb.front_buffer || !g_fb.back_buffer || g_fb.front_buffer == g_fb.back_buffer) return;

    uint32_t total_pixels = (g_fb.pitch / 4) * g_fb.height;
    for (uint32_t i = 0; i < total_pixels; i++) {
        g_fb.front_buffer[i] = g_fb.back_buffer[i];
    }
}
