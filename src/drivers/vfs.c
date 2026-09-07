// src/drivers/vfs.c
// Virtual File System (VFS) with Lens Graph xattr support
#include <heaplit/types.h>
#include <heaplit/vfs.h>

extern void* memset(void* dest, int val, size_t len);
extern size_t strlen(const char* str);
extern char* strcpy(char* dest, const char* src);
extern int strcmp(const char* s1, const char* s2);

static vfs_node_t root_node;

void vfs_init(void) {
    memset(&root_node, 0, sizeof(vfs_node_t));
    strcpy(root_node.name, "/");
    root_node.flags = VFS_FLAG_DIRECTORY;
    root_node.inode = 1;
}

uint64_t vfs_read(vfs_node_t* node, uint64_t offset, uint64_t size, uint8_t* buffer) {
    if (node && node->ops && node->ops->read) {
        return node->ops->read(node, offset, size, buffer);
    }
    return 0;
}

uint64_t vfs_write(vfs_node_t* node, uint64_t offset, uint64_t size, const uint8_t* buffer) {
    if (node && node->ops && node->ops->write) {
        return node->ops->write(node, offset, size, buffer);
    }
    return 0;
}
