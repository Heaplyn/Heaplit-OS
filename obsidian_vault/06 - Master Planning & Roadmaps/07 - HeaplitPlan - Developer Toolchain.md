> **Status:** #status/future-implementation

# 📋 HeaplitPlan: Developer Toolchain & Self-Hosting

Tags: #HeaplitPlan #Phase4 #Ring2 #MVP

> **Target Phase:** Phase 4 (Months 16–24)  
> **Goal:** Native Clang C/C++, CoreCLR C# runtime, `.axf` LLVM Bitcode packaging, and self-compiling kernel.

---

## 1. Actionable Milestones

- [ ] **Resident Clang Port:** Compile Clang + LLD targeting freestanding Heaplit OS environment.
- [ ] **CoreCLR / RyuJIT Port:** Integrate RyuJIT code generator with the microkernel's AVX-512 scheduler.
- [ ] **`.axf` Bitcode Format:** Define container format, digital signatures, and install-time JIT pipeline.
- [ ] **`hpkg` Package Manager:** Implement package download, dependency resolution, and atomic ZFS boot snapshots.
- [ ] **Full Self-Hosting:** The OS builds its own bootloader, kernel, and userland entirely inside Heaplit OS.

---

## 2. Related Links
- [[04 - Developer Toolchain & Packaging/01 - LLVM Bitcode (.axf) Application Format|LLVM Bitcode Format]]
- [[04 - Developer Toolchain & Packaging/03 - CoreCLR (.NET & C#) Runtime|CoreCLR Runtime]]

## 🔄 Toolchain Ecosystem Master Flowchart

```mermaid
flowchart TD
    A["High-Level Code (C++, C#, Rust)"] --> B["LLVM Toolchain / CoreCLR Compiler"]
    B --> C["`.axf` Bitcode Binary Container"]
    C --> D["Atomic Package Distribution via `hpkg`"]
```
