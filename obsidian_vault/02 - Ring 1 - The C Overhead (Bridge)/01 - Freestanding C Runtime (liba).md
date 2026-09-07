> **Status:** #status/implemented

# 📚 Freestanding C Runtime (`liba`)

> **Ring Placement:** `rings/ring_1/ring_1/liba/`  
> **Source Files:** `string.c`, `kprintf.c`  
> **Privilege Level:** Ring 1 ($M \le 1$)

---

## 1. Freestanding Compiler Requirements

All C files in `liba` execute directly on bare metal without standard C libraries (`glibc`, `musl`) or runtime startup files (`crt0.o`).

### Mandatory GCC / Clang Flags
```bash
clang -ffreestanding -mno-red-zone -fno-stack-protector -fno-builtin -O2 -c string.c kprintf.c
```
- `-ffreestanding`: Assumes no standard library features exist.
- `-mno-red-zone`: Disables 128-byte System V red zone on stack to prevent interrupt handler corruption.
- `-fno-stack-protector`: Prevents compiler from emitting `__stack_chk_fail` dependencies.

---

## 2. C Standard String & Memory Implementation (`string.c`)

```c
#include <heaplit/types.h>

void* memset(void* dest, int val, size_t count) {
    uint8_t* ptr = (uint8_t*)dest;
    while (count--) {
        *ptr++ = (uint8_t)val;
    }
    return dest;
}

void* memcpy(void* dest, const void* src, size_t count) {
    uint8_t* d = (uint8_t*)dest;
    const uint8_t* s = (const uint8_t*)src;
    while (count--) {
        *d++ = *s++;
    }
    return dest;
}

size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len]) len++;
    return len;
}
```

---

## 3. Formatted Kernel Logger (`kprintf.c`)

`kprintf` provides low-overhead formatted logging across hardware channels:
1. **Serial Port COM1 (`0x3F8`)**: Outputs logs to host terminal / QEMU console.
2. **VGA Text Buffer (`0xB8000`)**: Renders characters on screen.

## 🔄 Freestanding C Runtime Memory Architecture

```mermaid
flowchart TD
    A["`malloc(size)` Request"] --> B["Search Free Block Linked List"]
    B --> C{"Suitable Block Found?"}
    C -->|"Yes"| D["Split Block and Mark Header Allocated"]
    C -->|"No"| E["Invoke `sys_brk` Syscall to Extend Heap Pointer"]
    E --> D
    D --> F["Return User Payload Pointer"]
```
