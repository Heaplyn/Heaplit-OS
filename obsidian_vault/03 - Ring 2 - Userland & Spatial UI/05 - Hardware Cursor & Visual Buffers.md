> **Status:** #status/future-implementation

# 🖱️ Hardware Cursor & Visual Buffers

> **Evolution:** From 16-bit BIOS text mode (`0xB8000`) to VBE Linear Framebuffer to GPU hardware cursor overlay planes.

---

## 1. Visual Buffer Stages Across Boot & Runtime

```mermaid
graph TD
    S1["Stage 1: Real Mode VGA Text Mode (0xB8000, 80x25 characters)"] --> S2["Stage 2: VBE Linear Framebuffer (1024x768x32bpp)"]
    S2 --> S3["Stage 3: DRM/KMS Hardware Plane + Vulkan Triple-Buffering"]
```

---

## 2. Hardware Cursor Plane
To eliminate mouse cursor input lag:
1. The mouse cursor is rendered onto a dedicated hardware overlay plane (DRM plane).
2. Mouse move events update cursor plane coordinates directly via `SYS_CURSOR_MOVE` (`0x202`) without triggering a full screen redraw.

---

## 3. Related Links
- [[02 - Reference/Console & Display API|Console API]]
- [[03 - Ring 2 - Userland & Spatial UI/03 - Spatial Window Compositor|Compositor]]
