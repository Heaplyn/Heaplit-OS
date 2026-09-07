/**
 * Heaplit OS - Linux ELF POSIX Compatibility Translation Wrapper (posixcall)
 * Ring Placement: rings/ring_1/ring_1/drivers/posixcall.c (Ring 1)
 * Description: Parses Linux ELF64 binary headers and maps POSIX syscalls
 *              (sys_open, sys_read, sys_write, sys_mmap) to Ring 0 Heaplit syscalls.
 */

#include <stdint.h>
#include <stddef.h>

#define ELF_MAGIC 0x464C457F /* "\x7FELF" */

typedef struct {
    uint32_t e_magic;
    uint8_t  e_class;     /* 1 = 32-bit, 2 = 64-bit */
    uint8_t  e_data;      /* 1 = Little-endian, 2 = Big-endian */
    uint8_t  e_version;
    uint8_t  e_osabi;
    uint8_t  e_abiversion;
    uint8_t  e_pad[7];
    uint16_t e_type;
    uint16_t e_machine;
    uint32_t e_version2;
    uint64_t e_entry;     /* Entry point virtual address */
    uint64_t e_phoff;     /* Program header table offset */
    uint64_t e_shoff;     /* Section header table offset */
    uint32_t e_flags;
    uint16_t e_ehsize;
    uint16_t e_phentsize;
    uint16_t e_phnum;
    uint16_t e_shentsize;
    uint16_t e_shnum;
    uint16_t e_shstrndx;
} elf64_header_t;

/**
 * posixcall_validate_elf: Validates a Linux ELF64 binary payload
 */
int posixcall_validate_elf(const uint8_t* buffer, size_t size) {
    if (size < sizeof(elf64_header_t)) {
        return -1;
    }

    const elf64_header_t* elf_hdr = (const elf64_header_t*)buffer;
    if (elf_hdr->e_magic != ELF_MAGIC) {
        return -2; /* Invalid ELF magic bytes */
    }

    if (elf_hdr->e_class != 2) {
        return -3; /* Require 64-bit ELF */
    }

    return 0; /* Valid ELF64 binary */
}

/**
 * posixcall_translate_syscall: Translates x86-64 Linux POSIX syscall numbers to Heaplit syscalls
 */
int64_t posixcall_translate_syscall(uint64_t linux_syscall_nr) {
    switch (linux_syscall_nr) {
        case 0:  /* sys_read */
            return 0x02;
        case 1:  /* sys_write */
            return 0x01;
        case 2:  /* sys_open */
            return 0x05;
        case 3:  /* sys_close */
            return 0x06;
        case 9:  /* sys_mmap */
            return 0x10;
        case 60: /* sys_exit */
            return 0x00;
        default:
            return -1; /* Unsupported Linux POSIX syscall */
    }
}
