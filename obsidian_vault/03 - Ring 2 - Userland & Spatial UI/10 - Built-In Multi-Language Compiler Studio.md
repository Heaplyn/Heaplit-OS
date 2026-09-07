> **Status:** #status/future-implementation

# 💻 Built-In Multi-Language Compiler Studio – Detailed Technical Specification

> **Layer:** Ring 2 Userland Application  
> **Binary Container:** `studio.axf`  
> **Kernel Service:** Ring 1 Embedded LLVM JIT Engine & Symbol Resolver  
> **Supported Languages:** C, C++, Assembly (x86-64 NASM syntax), C# (.NET 8), Rust

---

## 1. Executive Summary & Architecture

The **Multi-Language Compiler Studio** is Heaplit OS's built-in native Integrated Development Environment (IDE). Designed to operate without third-party dependencies, the Compiler Studio interfaces directly with the kernel's embedded LLVM JIT service via Ring 0 system calls to compile, link, execute, and debug applications in real-time.

```mermaid
flowchart LR
    subgraph IDE_Frontend["Compiler Studio IDE (Ring 2)"]
        E1["Syntax Highlighted Text Buffer"]
        E2["Project Workspace File Tree"]
        E3["Real-Time Diagnostic Terminal"]
    end

    subgraph LLVM_Service["In-Kernel LLVM Service (Ring 1)"]
        L1["Language Lexer & Parser"]
        L2["LLVM IR Code Generation"]
        L3["Target Optimization (O2/O3/AVX-512)"]
        L4["JIT Native Code Emitter"]
    end

    subgraph Execution_Env["Ring 3 Application Execution"]
        X1["Sandboxed Bitcode Task"]
    end

    IDE_Frontend -->|"sys_compile_code (RAX=0xC1)"| LLVM_Service
    LLVM_Service -->|"Emit Native Machine Code"| Execution_Env
    Execution_Env -->|"Exception Trap Signals"| IDE_Frontend
```

---

## 2. Core Subsystems

### 2.1 Embedded LLVM JIT Interface
- **Hot-Patching Engine**: Modifications made in the Compiler Studio editor can be JIT-compiled and patched directly into running process memory without losing process state.
- **Multi-Language Lexing**: Integrates parsers for C23, C++26, x86-64 Assembly, Rust 2024, and C# 12.

### 2.2 CPU Exception Interceptor & Interactive Debugger
When an executing application triggers a CPU exception (such as a Page Fault at `CR2` or Divide-by-Zero), the Ring 0 IDT handler captures the registers and forwards a structured debug frame to the Compiler Studio:

```mermaid
sequenceDiagram
    autonumber
    participant Target as Running Application Process
    participant IDT as Ring 0 IDT Exception Handler
    participant Sig as Exception Signal Translator
    participant Studio as Compiler Studio IDE Debugger

    Target->>IDT: CPU Exception (Vector 14: Page Fault @ CR2 = 0x00000000)
    IDT->>Sig: Capture Register Dump (RAX..R15, RSP, RIP, CR2)
    Sig->>Studio: Forward Structured Debug Frame Signal
    Studio->>Studio: Highlight Faulting Line in Source Editor & Display Registers
```
