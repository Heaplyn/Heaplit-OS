// src/drivers/pci.c
// PCIe Configuration Space Enumeration & Driver Matching
#include <heaplit/types.h>

static inline void outd(uint16_t port, uint32_t val) {
    __asm__ volatile ("outl %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint32_t ind(uint16_t port) {
    uint32_t ret;
    __asm__ volatile ("inl %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

uint32_t pci_read_config(uint8_t bus, uint8_t slot, uint8_t func, uint8_t offset) {
    uint32_t address = (uint32_t)((1U << 31) | ((uint32_t)bus << 16) | 
                                 ((uint32_t)slot << 11) | ((uint32_t)func << 8) | 
                                 (offset & 0xFC));
    outd(0xCF8, address);
    return ind(0xCFC);
}

void pci_scan_bus(void) {
    for (uint16_t bus = 0; bus < 256; bus++) {
        for (uint8_t slot = 0; slot < 32; slot++) {
            uint32_t vendor_device = pci_read_config((uint8_t)bus, slot, 0, 0);
            uint16_t vendor_id = (uint16_t)(vendor_device & 0xFFFF);
            if (vendor_id != 0xFFFF) {
                // Device Present on PCIe Bus
            }
        }
    }
}
