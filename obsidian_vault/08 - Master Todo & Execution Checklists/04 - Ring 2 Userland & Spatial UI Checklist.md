> **Status:** #status/future-implementation

# 🖥️ Ring 2 Userland & Spatial UI Checklist (Exhaustive Implementation Protocol)

> **Target Components:** `rings/ring_2/` (`console`, `input`, `spatial_ui`, `applications`)

---

## 1. Userland Services & Console Subsystem

- [x] **Heaplit Userland Agent Daemon (`heaplit_daemon`)**: Architecture for VFS watcher & background perception loop #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **VFS File Watcher**: Registers event listener on VFS `/system/config/` and workspace directories via `sys_fs_watch` (syscall `0x30`).
  > 2. **Perception Loop**: Reads modified file paths, formats context prompt, and submits prompt to Ring 1 GGML AI engine via `sys_ai_infer` (`0xA1`).

- [x] **Console Output Subsystem (`console.asm`)**: VGA text mode `0xB8000` & ANSI escape code parser #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **VGA Direct Write**: Writes ASCII character byte + color attribute byte to physical memory `0xB8000` (80x25 characters).
  > 2. **ANSI Parsing**: Intercepts `[` escape sequences; parses foreground/background SGR color codes (`[31m` Red) and cursor movements (`[2J` Clear).

- [x] **Keyboard Input Subsystem (`keyboard.asm`)**: PS/2 scancode decoder & line buffer editor with backspace handling #status/implemented
  > 🛠️ **Implementation Protocol**:
  > 1. **IRQ 1 Handler**: Reads raw scancode from Port `0x60` on keyboard interrupt.
  > 2. **Scancode Translation**: Maps Set 1 scancodes to ASCII characters, handling Shift (`0x2A`/`0x36`) and Ctrl keys.
  > 3. **Line Buffer Editor**: Appends characters to prompt buffer, handles Backspace (`0x0E`) by erasing character and shifting caret.

---

## 2. Spatial UI & Retained Graphics Core

- [ ] **The Lens 3D Graph File Explorer**: Vulkan compute shader spring-embedder force layout engine #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Node Construction**: Instantiates 3D sphere node per VFS inode. Edges represent parent-child and `xattr` tag relationships.
  > 2. **Coulomb Repulsion**: Compute shader computes pairwise node repulsion $F_{rep} = rac{k_r}{d^2}$.
  > 3. **Hooke Attraction**: Compute shader computes edge attraction $F_{att} = k_a \cdot (d - d_0)$.
  > 4. **Euler Integration**: Updates node 3D coordinates via velocity vector integration ($v = v + a \cdot dt$, $p = p + v \cdot dt$).

- [ ] **Spatial Window Compositor**: Window surface Z-ordering, inertia physics, velocity, friction calculations #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Retained Window Queue**: Maintains sorted array of window surface pointers ordered by Z-depth.
  > 2. **Inertia Physics**: On mouse drag release, applies initial velocity vector $(v_x, v_y)$; applies frictional deceleration ($v = v \cdot 0.92$) each frame until velocity < 0.1.

- [ ] **GPU Retained SDF Font Engine**: Multi-channel Signed Distance Field glyph font rasterizer #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Texture Atlas**: Generates 512x512 multi-channel SDF (MSDF) font atlas texture.
  > 2. **Fragment Shader Thresholding**: Vulkan fragment shader evaluates median distance field value (`median(r, g, b)`) to render sharp vector text at any zoom level.

- [ ] **Zero-Latency Hardware Cursor**: Hardware DRM plane overlay & Vulkan swapchain double buffering #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Hardware Cursor Plane**: Maps cursor sprite to dedicated DRM hardware cursor plane (`DRM_PLANE_TYPE_CURSOR`).
  > 2. **Register Movement**: Updates cursor position via direct GPU register write without re-compositing background window buffers.

- [ ] **Live TOML Theming Engine**: Hot-reloading interface parameters from `/sys/theme.toml` #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **TOML Parser**: Parses key-value color hex codes, font sizes, and window corner radii from `/sys/theme.toml`.
  > 2. **Uniform Buffer Update**: Flushes updated theme parameters to GPU constant uniform buffers on file modification events.

---

## 3. Native Application Suite (Mid-Term)

- [ ] **The Forge Tool Installer GUI (`forge.axf`)**: One-click fetcher & provisioner for VS, MinGW, Node, Rust, Browsers #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Package Fetching**: Issues HTTP GET request to package repository via network stack.
  > 2. **SHA-256 Integrity Verification**: Computes SHA-256 digest of downloaded `.hpkg` archive and checks against signed manifest.
  > 3. **Atomic Extraction**: Unpacks binaries into `/sys/toolchains/<name>/` and registers VFS PATH variables.

- [ ] **Multi-Language Compiler Studio (`studio.axf`)**: Native IDE interfacing directly with in-kernel LLVM service #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Editor Buffer**: Multi-tab text editor with syntax highlighting for C, C++, Assembly, C#, Rust.
  > 2. **In-Kernel Compilation**: Passes source text buffer to Ring 1 LLVM service (`sys_compile_code` 0xC1); receives JIT compiled `.axf` handle.
  > 3. **Hot-Patching**: Swaps active process machine code instructions in RAM without destroying process heap state.

- [ ] **Custom Calendar & Time Service (`calendar.axf`)**: RTC IRQ 8 clock & event-to-file temporal cross-referencing #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **RTC Timekeeper**: Reads RTC CMOS ports (`0x70`/`0x71`) on IRQ 8 to maintain nanosecond UTC timestamp.
  > 2. **Temporal Linkage**: Automatically attaches event metadata tags to any file created or modified during a scheduled calendar event window.

- [ ] **Kernel-Level Antivirus & Integrity Guard (`integrity_guard.c`)**: `.axf` LLVM IR bitcode validator & W^X page protection #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **IR Static Analysis**: Scans LLVM IR instructions prior to JIT compilation; blocks unauthorized raw assembly injection or ring escalation.
  > 2. **W^X Page Protection**: Enforces Write XOR Execute page table bits; revokes write privileges before JIT memory pages are executed.

---

## 4. Far-Future Spatial UI & Input Innovations

- [ ] **3D Spatial Audio Engine**: Position application sounds in 3D space corresponding to window positions #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **HRTF Audio Panning**: Applies Head-Related Transfer Function (HRTF) filtering to 3D audio streams based on window $(x, y, z)$ coordinates relative to user camera.

- [ ] **Gaze & Gesture Tracking Driver**: Sub-millisecond webcam/VR spatial input tracking #status/future-implementation
  > 🛠️ **Implementation Protocol**:
  > 1. **Pupil & Hand Tracking**: Processes camera video frame tensor to detect pupil gaze point and hand pinch gestures for hands-free UI control.
