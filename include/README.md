# 📦 Shared Include Headers (`include/`)

This directory contains shared NASM macro libraries and freestanding C header files used across all kernel rings and userland applications.

---

## 📂 File Breakdown & Responsibilities

### 1. `macros.inc` — NASM Macro Library
- `ALIGN_16`: Aligns code or data on a 16-byte boundary.
- `ALIGN_4K`: Aligns code or data on a 4,096-byte (4KB) page boundary.
- `PUSH_ALL_64`: Pushes all 16 64-bit general-purpose registers onto the stack.
- `POP_ALL_64`: Restores all 16 64-bit general-purpose registers from the stack.
- `DEBUG_HALT`: Emits `cli`, `hlt`, and infinite loop for bare-metal breakpointing.

### 2. `heaplit/types.h` — Standard Integer & Data Types
- Standard freestanding types: `uint8_t`, `uint16_t`, `uint32_t`, `uint64_t`, `int8_t`, `int16_t`, `int32_t`, `int64_t`, `size_t`, `bool`.

### 3. `heaplit/syscalls.h` — Master System Call Definitions
- Enumerates standard POSIX syscall numbers (`SYS_EXIT 0x001` through `SYS_EXEC 0x03B`) and Heaplit AI extensions (`SYS_AI_LOAD_MODEL 0x600`, `SYS_AI_INFER 0x601`, `SYS_AI_UNLOAD 0x602`).

### 4. `heaplit/vfs.h` — Virtual File System & Graph Types
- Defines `vfs_node_t`, `vfs_ops_t` interface function pointers, and `xattr_t` extended attribute relational graph metadata structures.
