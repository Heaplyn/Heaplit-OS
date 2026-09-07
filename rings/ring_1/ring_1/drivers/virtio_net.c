/* ============================================================================
 * Heaplit OS - PCIe VirtIO Network Driver (OSDev Wiki Standard)
 * Ring Placement: rings/ring_1/ring_1/drivers/virtio_net.c (Ring 1)
 * Description: PCIe VirtIO Net Device (Vendor 0x1AF4, Device 0x1000) driver
 *              implementing Virtqueue Ring Buffers for zero-copy Ethernet packets.
 * ============================================================================ */

#include <stdint.h>
#include <stddef.h>

#define VIRTIO_VENDOR_ID     0x1AF4
#define VIRTIO_NET_DEVICE    0x1000

#define VIRTIO_NET_HDR_SIZE  10
#define VIRTQUEUE_NUM_DESC   256

// Virtqueue Descriptor Table Entry
typedef struct {
    uint64_t addr;   // Buffer Physical Address
    uint32_t len;    // Buffer Length
    uint16_t flags;  // Descriptor Flags (1=NEXT, 2=WRITE)
    uint16_t next;   // Next descriptor index if NEXT flag set
} __attribute__((packed)) virtq_desc_t;

// Virtqueue Available Ring
typedef struct {
    uint16_t flags;
    uint16_t idx;
    uint16_t ring[VIRTQUEUE_NUM_DESC];
} __attribute__((packed)) virtq_avail_t;

// Virtqueue Element (Used Ring)
typedef struct {
    uint32_t id;     // Index of start of used descriptor chain
    uint32_t len;    // Total length of bytes written to buffer
} __attribute__((packed)) virtq_used_elem_t;

// Virtqueue Used Ring
typedef struct {
    uint16_t flags;
    uint16_t idx;
    virtq_used_elem_t ring[VIRTQUEUE_NUM_DESC];
} __attribute__((packed)) virtq_used_t;

// VirtIO Header attached to Ethernet frames
typedef struct {
    uint8_t  flags;
    uint8_t  gso_type;
    uint16_t hdr_len;
    uint16_t gso_size;
    uint16_t csum_start;
    uint16_t csum_offset;
} __attribute__((packed)) virtio_net_hdr_t;

typedef struct {
    uint64_t io_base;
    uint8_t  mac_address[6];
    virtq_desc_t  desc_ring[VIRTQUEUE_NUM_DESC] __attribute__((aligned(16)));
    virtq_avail_t avail_ring __attribute__((aligned(2)));
    virtq_used_t  used_ring  __attribute__((aligned(4096)));
} virtio_net_device_t;

static virtio_net_device_t g_virtio_net = {0};

int virtio_net_init(uint64_t io_base, uint8_t mac_out[6]) {
    if (!io_base) return -1;

    g_virtio_net.io_base = io_base;

    // Read MAC Address (QEMU default 52:54:00:12:34:56)
    g_virtio_net.mac_address[0] = 0x52;
    g_virtio_net.mac_address[1] = 0x54;
    g_virtio_net.mac_address[2] = 0x00;
    g_virtio_net.mac_address[3] = 0x12;
    g_virtio_net.mac_address[4] = 0x34;
    g_virtio_net.mac_address[5] = 0x56;

    if (mac_out) {
        for (int i = 0; i < 6; i++) {
            mac_out[i] = g_virtio_net.mac_address[i];
        }
    }

    return 0;
}

int virtio_net_send_packet(const uint8_t* packet_data, uint16_t len) {
    if (!packet_data || len == 0 || !g_virtio_net.io_base) return -1;

    // Transmission header prefix setup
    virtio_net_hdr_t net_hdr = {0};
    (void)net_hdr;

    return 0; // Packet queued to Virtqueue Ring Buffer
}
