// =============================================================================
// Heaplit OS - Master Syscall Number Definitions (0x000 - 0x6FF)
// =============================================================================
#ifndef HEAPLIT_SYSCALLS_H
#define HEAPLIT_SYSCALLS_H

// --- Process Management (0x000 - 0x01F) ---
#define SYS_EXIT                0x01
#define SYS_FORK                0x02
#define SYS_READ                0x03
#define SYS_WRITE               0x04
#define SYS_OPEN                0x05
#define SYS_CLOSE               0x06
#define SYS_WAITPID             0x07
#define SYS_EXEC                0x3B
#define SYS_FS_WATCH            0x30

// --- Memory Management (0x080 - 0x0FF) ---
#define SYS_MMAP                0x09
#define SYS_MUNMAP              0x0B
#define SYS_BRK                 0x0C
#define SYS_HUGE_ALLOC          0x90

// --- Lens Graph Database (0x100 - 0x1FF) ---
#define SYS_GRAPH_GET_XATTR     0x101
#define SYS_GRAPH_SET_EDGE      0x102
#define SYS_GRAPH_QUERY         0x103

// --- Spatial Compositor & UI (0x200 - 0x2FF) ---
#define SYS_COMPOSITOR_FLIP     0x201
#define SYS_CURSOR_MOVE         0x202
#define SYS_THEME_NOTIFY        0x203

// --- Heaplit AI Engine (0x600 - 0x6FF) ---
#define SYS_AI_LOAD_MODEL       0x600
#define SYS_AI_INFER            0x601
#define SYS_AI_SCHEDULE_TASK    0x602

#endif // HEAPLIT_SYSCALLS_H
