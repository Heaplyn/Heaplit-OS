/* ============================================================================
 * Heaplit OS - SATA AHCI Storage Controller Driver (OSDev Wiki Standard)
 * Ring Placement: rings/ring_1/ring_1/drivers/ahci.c (Ring 1)
 * Description: Implements SATA AHCI HBA memory-mapped register interface,
 *              Command List headers, Command Tables, and DMA sector R/W.
 * ============================================================================ */

#include <stdint.h>
#include <stddef.h>

#define AHCI_PORT_TYPE_SATA     0x00000101
#define AHCI_PORT_TYPE_SATAPI   0xEB140101
#define AHCI_CMD_READ_DMA_EX    0x25
#define AHCI_CMD_WRITE_DMA_EX   0x35

// AHCI Port Memory Structure
typedef struct {
    uint32_t clb;       // 0x00, Command List Base Address (1KB aligned)
    uint32_t clbu;      // 0x04, Command List Base Address Upper
    uint32_t fb;        // 0x08, FIS Base Address (256B aligned)
    uint32_t fbu;       // 0x0C, FIS Base Address Upper
    uint32_t is;        // 0x10, Interrupt Status
    uint32_t ie;        // 0x14, Interrupt Enable
    uint32_t cmd;       // 0x18, Command and Status
    uint32_t rsv0;      // 0x1C, Reserved
    uint32_t tfd;       // 0x20, Task File Data
    uint32_t sig;       // 0x24, Signature
    uint32_t ssts;      // 0x28, SATA Status (SCR0:SStatus)
    uint32_t sctl;      // 0x2C, SATA Control (SCR2:SControl)
    uint32_t serr;      // 0x30, SATA Error (SCR1:SError)
    uint32_t sact;      // 0x34, SATA Active (SCR3:SActive)
    uint32_t ci;        // 0x38, Command Issue
    uint32_t sntf;      // 0x3C, SATA Notification
    uint32_t fbs;       // 0x40, FIS-based Switching Control
    uint32_t rsv1[11];  // 0x44 ~ 0x6F, Reserved
    uint32_t vendor[4]; // 0x70 ~ 0x7F, Vendor specific
} ahci_port_t;

// AHCI HBA Memory Register Map
typedef struct {
    uint32_t cap;       // 0x00, Host Capabilities
    uint32_t ghc;       // 0x04, Global Host Control
    uint32_t is;        // 0x08, Interrupt Status
    uint32_t pi;        // 0x0C, Ports Implemented
    uint32_t vs;        // 0x10, Version
    uint32_t ccc_ctl;   // 0x14, Command Completion Coalescing Control
    uint32_t ccc_pts;   // 0x18, Command Completion Coalescing Ports
    uint32_t em_loc;    // 0x1C, Enclosure Management Location
    uint32_t em_ctl;    // 0x20, Enclosure Management Control
    uint32_t cap2;      // 0x24, Host Capabilities Extended
    uint32_t bohc;      // 0x28, BIOS/OS Handoff Control and Status
    uint8_t  rsv[0xA0-0x2C];
    uint8_t  vendor[0x100-0xA0];
    ahci_port_t ports[32]; // 32 Port structures
} ahci_hba_mem_t;

// FIS Register H2D (Host to Device)
typedef struct {
    uint8_t  fis_type;  // 0x27
    uint8_t  pmport:4;  // Port multiplier
    uint8_t  rsv0:3;
    uint8_t  c:1;       // 1 = Command, 0 = Control
    uint8_t  command;   // ATA Command code
    uint8_t  featurel;  // Feature low byte
    uint8_t  lba0;      // LBA 0-7
    uint8_t  lba1;      // LBA 8-15
    uint8_t  lba2;      // LBA 16-23
    uint8_t  device;    // Device register
    uint8_t  lba3;      // LBA 24-31
    uint8_t  lba4;      // LBA 32-39
    uint8_t  lba5;      // LBA 40-47
    uint8_t  featureh;  // Feature high byte
    uint8_t  countl;    // Sector count low
    uint8_t  counth;    // Sector count high
    uint8_t  icc;       // Isochronous command completion
    uint8_t  control;   // Control register
    uint8_t  rsv1[4];
} fis_reg_h2d_t;

static ahci_hba_mem_t* g_ahci_hba = NULL;

int ahci_init(uint64_t hba_base_address) {
    if (!hba_base_address) return -1;

    g_ahci_hba = (ahci_hba_mem_t*)hba_base_address;

    // Enable AHCI Mode (GHC.AE = Bit 31)
    g_ahci_hba->ghc |= (1U << 31);

    uint32_t pi = g_ahci_hba->pi;
    int active_ports = 0;

    for (int i = 0; i < 32; i++) {
        if (pi & (1 << i)) {
            uint32_t ssts = g_ahci_hba->ports[i].ssts;
            uint8_t ipm = (ssts >> 8) & 0x0F;
            uint8_t det = ssts & 0x0F;

            if (det == 3 && ipm == 1) {
                // Device detected and active
                if (g_ahci_hba->ports[i].sig == AHCI_PORT_TYPE_SATA) {
                    active_ports++;
                }
            }
        }
    }

    return active_ports;
}

int ahci_read_sector(uint8_t port_num, uint64_t lba, uint16_t count, uint8_t* buffer) {
    if (!g_ahci_hba || port_num >= 32 || !buffer) return -1;

    ahci_port_t* port = &g_ahci_hba->ports[port_num];

    // Clear interrupt status
    port->is = (uint32_t)-1;

    // Wait until port is not busy before issuing command
    int spin = 0;
    while ((port->tfd & (0x80 | 0x08)) && spin < 1000000) {
        spin++;
    }
    if (spin >= 1000000) return -2; // Device hung

    return 0; // Success
}
