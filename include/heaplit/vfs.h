// =============================================================================
// Heaplit OS - Virtual File System (VFS) & Lens Graph Inode Interface
// =============================================================================
#ifndef HEAPLIT_VFS_H
#define HEAPLIT_VFS_H

#include <heaplit/types.h>

#define VFS_FLAG_FILE        0x01
#define VFS_FLAG_DIRECTORY   0x02
#define VFS_FLAG_CHARDEVICE  0x03
#define VFS_FLAG_BLOCKDEVICE 0x04
#define VFS_FLAG_SYMLINK     0x05

struct vfs_node;

typedef struct {
    uint64_t (*read)(struct vfs_node* node, uint64_t offset, uint64_t size, uint8_t* buffer);
    uint64_t (*write)(struct vfs_node* node, uint64_t offset, uint64_t size, const uint8_t* buffer);
    void (*open)(struct vfs_node* node);
    void (*close)(struct vfs_node* node);
    struct vfs_node* (*finddir)(struct vfs_node* node, const char* name);
    // Lens Graph extended attributes
    int (*get_xattr)(struct vfs_node* node, const char* name, void* val, size_t size);
    int (*set_xattr)(struct vfs_node* node, const char* name, const void* val, size_t size);
} vfs_operations_t;

typedef struct vfs_node {
    char name[128];
    uint32_t flags;
    uint64_t size;
    uint32_t inode;
    vfs_operations_t* ops;
    void* internal_ptr;
} vfs_node_t;

#endif // HEAPLIT_VFS_H
