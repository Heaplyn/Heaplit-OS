> **Status:** #status/future-implementation

# 📦 LLVM Bitcode (.axf) Architecture-Neutral Binary Format

> **Binary Specification:** Application eXecutable Format (`.axf`)

---

## 1. Beyond ELF and PE

Legacy OS binary formats (ELF on Linux, PE on Windows) lock compiled code to specific instruction set architectures (x86_64, ARM64, RISC-V).

Heaplit OS introduces **`.axf` (Architecture-Neutral Executable Format)**:
- Binaries contain optimized **LLVM Bitcode** rather than raw machine instructions.
- Upon execution, the resident Ring 2 Clang/LLVM JIT compiler compiles bitcode directly to host-native assembly with zero overhead.

---

## 2. Container Structure

```
+-----------------------------------+ 0x00: Magic Header ("AXF")
| 64-bit Architecture Flags        |
+-----------------------------------+
| Cryptographic Hash Signature      |
+-----------------------------------+
| LLVM Bitcode Stream Payload       |
+-----------------------------------+
| Embedded xattr Metadata Graph     |
+-----------------------------------+
```

## 🔄 LLVM Bitcode Execution & JIT Flowchart

```mermaid
flowchart TD
    A["`.axf` Application Binary Package"] --> B["Validate AXF Magic Bytes & Section Headers"]
    B --> C["Extract LLVM IR Bitcode Payload"]
    C --> D["Ring 1 LLVM JIT Compiler Engine"]
    D --> E["Emit Native x86-64 Machine Code Instructions"]
    E --> F["Launch Ring 3 Sandboxed Application Process"]
```
