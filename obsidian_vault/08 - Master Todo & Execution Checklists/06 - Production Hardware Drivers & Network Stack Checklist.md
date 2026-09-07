> **Status:** #status/future-implementation

# 🌐 Production Hardware Drivers & Network Stack Checklist

> **Target Domain:** Bare-Metal Hardware Connectivity & Sockets

---

## 1. Network Interface Drivers & Protocol Stack
- [ ] **VirtIO-Net NIC Driver**: QEMU PCI network ring buffer management #status/future-implementation
- [ ] **Intel e1000 / e1000e Driver**: PCIe registers, DMA receive/transmit descriptors #status/future-implementation
- [ ] **Layer 2 Data Link**: Ethernet frame parser & ARP IP-to-MAC resolution cache #status/future-implementation
- [ ] **Layer 3 Network Layer**: IPv4 packet routing & ICMP ping response handler #status/future-implementation
- [ ] **Layer 4 Transport Layer**: Full TCP state machine (`SYN`, `ESTABLISHED`, `FIN_WAIT`) & UDP sockets #status/future-implementation
- [ ] **Layer 7 Application Layer**: HTTP/1.1 client for `hpkg` fetching & DNS resolver #status/future-implementation

## 2. Bus & Input Controller Drivers
- [ ] **USB 3.0 (xHCI) Host Controller**: Command rings, event rings, doorbells, slot context parsing #status/future-implementation
- [ ] **USB HID Drivers**: USB Keyboard & Mouse event streams replacing legacy PS/2 emulation #status/future-implementation
- [ ] **Intel HD Audio Sound Driver**: DMA PCM audio stream ring buffers & volume mixer API #status/future-implementation
