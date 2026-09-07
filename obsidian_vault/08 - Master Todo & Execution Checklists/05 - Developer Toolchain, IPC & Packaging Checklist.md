> **Status:** #status/future-implementation

# 🛠️ Developer Toolchain, IPC & Packaging Checklist

> **Target Components:** `04 - Developer Toolchain & Packaging/`

---

## 1. Binary Container & Runtime Formats
- [x] **LLVM Bitcode (`.axf`) Application Format**: Architecture-neutral container header specification #status/implemented
- [x] **CoreCLR .NET 8 Runtime Support**: Managed C# assembly loading & NuGet package mapping #status/implemented
- [ ] **Built-in Clang / LLD Target**: Native target triple `x86_64-heaplit-elf` configuration #status/future-implementation

## 2. Inter-Process Communication & Packaging
- [ ] **High-Speed Zero-Copy IPC Message Bus**: Shared PMM physical frames & lock-free ASM ring gates (`lock cmpxchg`) #status/future-implementation
- [ ] **Dynamic Bitcode Linker (`axf_linker.c`)**: Runtime symbol resolution, relocation binding, JIT trampolines #status/future-implementation
- [ ] **`hpkg` Package Manager**: Cryptographic SHA-256 package verification & atomic extraction into VFS `/sys/bin/` #status/future-implementation
