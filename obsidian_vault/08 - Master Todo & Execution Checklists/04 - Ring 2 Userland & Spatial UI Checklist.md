> **Status:** #status/future-implementation

# 🖥️ Ring 2 Userland & Spatial UI Checklist

> **Target Components:** `rings/ring_2/ring_2/` (`console`, `input`, `spatial_ui`, `applications`)

---

## 1. Userland Services & Console Subsystem
- [x] **Heaplit Userland Agent Daemon (`heaplit_daemon`)**: Architecture for VFS watcher & background perception loop #status/implemented
- [x] **Console Output Subsystem (`console.asm`)**: VGA text mode `0xB8000` & ANSI escape code parser #status/implemented
- [x] **Keyboard Input Subsystem (`keyboard.asm`)**: PS/2 scancode decoder & line buffer editor with backspace handling #status/implemented

## 2. Spatial UI & Retained Graphics Core
- [ ] **The Lens 3D Graph File Explorer**: Vulkan compute shader spring-embedder force layout engine #status/future-implementation
- [ ] **Spatial Window Compositor**: Window surface Z-ordering, inertia physics, velocity, friction calculations #status/future-implementation
- [ ] **GPU Retained SDF Font Engine**: Multi-channel Signed Distance Field glyph font rasterizer #status/future-implementation
- [ ] **Zero-Latency Hardware Cursor**: Hardware DRM plane overlay & Vulkan swapchain double buffering #status/future-implementation
- [ ] **Live TOML Theming Engine**: Hot-reloading interface parameters from `/sys/theme.toml` #status/future-implementation

## 3. Native Application Suite
- [ ] **The Forge Tool Installer GUI (`forge.axf`)**: One-click fetcher & provisioner for VS, MinGW, Node, Rust, Browsers #status/future-implementation
- [ ] **Multi-Language Compiler Studio (`studio.axf`)**: Native IDE interfacing directly with in-kernel LLVM service #status/future-implementation
- [ ] **Custom Calendar & Time Service (`calendar.axf`)**: RTC IRQ 8 clock & event-to-file temporal cross-referencing #status/future-implementation
- [ ] **Kernel-Level Antivirus & Integrity Guard (`integrity_guard.c`)**: `.axf` LLVM IR bitcode validator & W^X page protection #status/future-implementation
