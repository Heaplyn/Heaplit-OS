# 📚 Ring 1 Freestanding C Runtime (`rings/ring_1/ring_1/liba/`)

`liba` is Heaplit OS's standalone C standard library. It executes without OS dependencies, libc, or runtime startup code, compiled strictly with `-ffreestanding -mno-red-zone -fno-stack-protector`.

$$\text{Privilege Level: Ring 1 } (M \le 1) \quad | \quad \text{Dependencies: Ring 0, Ring 1}$$

---

## 📂 File Breakdown & Responsibilities

### 1. `string.c` — C Memory & String Utilities
- **Functions**:
  - `void* memset(void* dest, int val, size_t count)`
  - `void* memcpy(void* dest, const void* src, size_t count)`
  - `size_t strlen(const char* str)`
  - `int strcmp(const char* s1, const char* s2)`
  - `char* strcpy(char* dest, const char* src)`
  - `char* strcat(char* dest, const char* src)`

### 2. `kprintf.c` — Formatted Kernel Logger
- **Purpose**: Low-overhead formatted logging across hardware serial and screen channels.
- **Format Specifiers**: `%s` (String), `%d` (Signed integer), `%u` (Unsigned integer), `%x` / `%p` (Hexadecimal / Pointer), `%c` (Character).
- **Output Targets**:
  - COM1 Serial Port (`0x3F8`) for headless debugging and QEMU logs.
  - Memory-mapped VGA Text Buffer (`0xB8000`) for visual screen output.
