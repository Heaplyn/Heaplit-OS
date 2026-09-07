> **Status:** #status/future-implementation

# 🔄 Self-Hosting, Testing & CI-CD Pipeline Checklist

> **Target Domain:** System Self-Hosting & Quality Assurance

---

## 1. Self-Hosting C Library & Toolchains
- [ ] **`heaplit-libc` Completeness**: POSIX `pthread` threading, `<math.h>` (`libm`), `<sys/socket.h>`, `<stdio.h>` #status/future-implementation
- [ ] **Native Clang / LLVM Port**: Execute Clang compiler natively inside Heaplit OS `.axf` sandbox #status/future-implementation
- [ ] **Native NASM Port**: Execute NASM assembler natively to build kernel assembly files without host OS #status/future-implementation

## 2. Autonomous Testing & Crash Diagnostics
- [ ] **DWARF Kernel Panic Backtrace**: Parse ELF/DWARF symbols to output human-readable function stack traces #status/future-implementation
- [ ] **Headless QEMU Automated Harness**: Automated execution of `.\loader\load_os.ps1` with COM1 serial log assertions #status/future-implementation
- [ ] **GitHub Actions Automated Pipeline**: Continuous Integration workflow triggering automated QEMU builds on git push #status/future-implementation
