> **Status:** #status/implemented

# 🌐 4-Level Paging & Virtual Memory

> **Ring Placement:** `rings/ring_0/ring_0/cpu/`  
> **Source File:** `paging.asm`  
> **Privilege Level:** Ring 0 ($M = 0$)

---

## 1. 4-Level Paging Architecture (x86-64)

```mermaid
graph LR
    CR3["CR3 Register (0x1000)"] --> PML4["PML4 Table (0x1000)"]
    PML4 -->|Index bits 47..39| PDPT["PDPT Table (0x2000)"]
    PDPT -->|Index bits 38..30| PD["Page Directory (0x3000)"]
    PD -->|Index bits 29..21 (2MB Huge Page)| Phys["Physical 2MB RAM Frame"]
```

### Fixed Page Table Placement in Low Memory
- **`0x1000`**: Page Map Level 4 (PML4). Root table pointer placed into `CR3`.
- **`0x2000`**: Page Directory Pointer Table (PDPT).
- **`0x3000`**: Page Directory (PD). Contains 512 entries mapping 2MB per entry = 1GB identity map.

---

## 2. Paging Implementation (`paging.asm`)

```nasm
[bits 32]
setup_paging:
    ; Clear page tables (0x1000 - 0x3FFF)
    mov edi, 0x1000
    mov cr3, edi
    xor eax, eax
    mov ecx, 3072              ; 3 tables * 4096 bytes / 4
    rep stosd

    ; Link PML4 entry 0 -> PDPT @ 0x2000 (Present | Writable = 0x03)
    mov dword [0x1000], 0x2003
    ; Link PML4 entry 511 -> PDPT @ 0x2000 (Higher-half kernel mapping)
    mov dword [0x1000 + 511 * 8], 0x2003

    ; Link PDPT entry 0 -> PD @ 0x3000 (Present | Writable = 0x03)
    mov dword [0x2000], 0x3003

    ; Map 512 Page Directory entries to 2MB huge pages (Present | Writable | Huge = 0x83)
    mov edi, 0x3000
    mov ebx, 0x00000083        ; Base physical 0x00000000 | 0x83
    mov ecx, 512
.map_pd_entry:
    mov [edi], ebx
    add ebx, 0x200000          ; Increment physical address by 2MB
    add edi, 8
    loop .map_pd_entry

    ret
```
