> **Status:** #status/implemented

# 🖱️ Hardware Cursor, SDF Fonts & Visual Buffer Compositor

> **Layer:** Ring 2 Presentation Subsystem  
> **Source Files:** `rings/ring_2/ring_2/console/console.asm`, `vbe_compositor.c`

---

## 1. Overview & Architecture

This note outlines the presentation layer's rendering engine, including low-level hardware cursor acceleration, double-buffered frame composition, Signed Distance Field (SDF) font rasterization, and TOML live-theming.

```mermaid
flowchart LR
    subgraph Buffer_Pipeline["Double-Buffered Composition"]
        B1["Back Buffer Surface"] --> B2["Blit Retained Window Glyphs"]
        B2 --> B3["Composite Hardware Cursor Layer"]
        B3 --> B4["Swap Page to VBE Framebuffer (0xFD000000)"]
    end

    subgraph SDF_Typography["SDF Font Engine"]
        F1["Vector Glyph Contour Data"] --> F2["Compute Distance Field Texture"]
        F2 --> F3["Vulkan Fragment Shader Alpha Thresholding"]
    end

    subgraph Live_Theming["TOML Theme Service"]
        T1["Parse /sys/theme.toml"] --> T2["Update Compositor Shader Uniforms"]
    end

    SDF_Typography & Live_Theming --> Buffer_Pipeline
```

---

## 2. Low-Level Graphics Specs
- **Hardware Cursor**: Direct VBE sprite overlay rendering without CPU redrawing.
- **SDF Glyph Fonts**: Scale-invariant typography rendered sharp at any resolution via GPU distance field fragment shaders.
- **TOML Live Theming**: Theme changes in `/sys/theme.toml` apply instantly via VFS file watches.
